# CDC Blinky (Clock Domain Crossing)

This project demonstrates a safe Mechanism for Clock Domain Crossing (CDC) using an Asynchronous FIFO on the Alinx AX7015B FPGA board.

## Overview
*   **Goal:** Transfer data safely from a 100MHz (Fast) domain to a 33MHz (Slow) domain.
*   **Key Feature:** Asynchronous FIFO with Gray Code Pointers and 2-FF Synchronizers to prevent metastability.
*   **Target:** Xilinx Zynq-7000 (xc7z015clg485-2).

## Architecture

```text
       100MHz DOMAIN                         CDC BARRIER                        33MHz DOMAIN
    (Producer / Write)                                                        (Consumer / Read)
   ___________________                                                       ___________________
  |                   |                                                     |                   |
  |  [Count Data]     |  ==================>  [ MEMORY ]  ================> |    [LEDs]         |
  |                   |        (Data is safe in Dual-Port RAM)              |                   |
  |___________________|                                                     |___________________|
            |                                                                         |
            |                                                                         |
            v                                                                         v
      [Write Pointer]  ------------------- (Gray Code) -------------------->     [Empty Check]
                                           Passing Pointers                           ^
                                         via 2-FF Synchronizers                       |
                                                                                      |
       [Full Check]    <------------------ (Gray Code) ---------------------     [Read Pointer]
```

The core of this project is a **Data Bridge**. Think of it as a funnel: you are pouring water in very fast (100MHz) and trying to drink it at a slower pace (33MHz). Without this specific code, the "water" would splash everywhere and get corrupted.

## RTL Modules: Detailed Architecture

### 1. Dual-Port Gray Counter (`rtl/gray_counter.sv`)
**Concept:**
Normally, passing a multi-bit binary counter (e.g., `0111` -> `1000`) across clock domains is fatal because the bits do not change instantly. A fast clock might sample in the middle of the transition, reading `1111` or `0000` (Metastability/Skew).
**Gray Code Property:**
In Gray code, consecutive numbers differ by exactly **one bit** (e.g., `0100` -> `1100`).
*   **Safety:** If a skew occurs, the destination clock sees either the *old* value or the *new* value. Both are valid states, so the FIFO pointer remains consistent.
*   **Implementation:** `gray_next = (bin_next >> 1) ^ bin_next;`
*   **Role:** Maintains `w_ptr_gray` and `r_ptr_gray` for safe transmission to the other domain.

### 2. 2-Flip-Flop Synchronizer (`rtl/sync_2ff.sv`)
**Concept:**
When a signal crosses from one clock domain to another, it violates setup/hold times. The destination flip-flop can enter a metastable state (oscillating between 0 and 1).
**Mechanism:**
*   **Stage 1:** Captures the asynchronous signal. Might go metastable.
*   **Stage 2:** Samples Stage 1 one cycle later. By this time, Stage 1 has likely settled to a stable logic level (0 or 1).
*   **Role:** Used in `async_fifo.sv` to synchronize the Gray pointers (`sync_r2w`, `sync_w2r`).

### 3. Asynchronous FIFO (`rtl/async_fifo.sv`)
**Concept:**
The heart of the design. It allows two independent clock domains to read and write data without data corruption.
**Key Logic:**
*   **Pointers:** Uses two pairs of pointers.
    *   `w_ptr`: Maintained in write domain, passed to read domain.
    *   `r_ptr`: Maintained in read domain, passed to write domain.
*   **Synchronization:** The pointers are converted to Gray code, synchronized via 2-FF, and then compared.
*   **Empty Condition:** `r_ptr_gray == w_ptr_gray_synced` (Read domain).
*   **Full Condition:** `w_ptr_gray == {~r_ptr_gray_synced[MSB:MSB-1], r_ptr_gray_synced[MSB-2:0]}` (Write domain).
    *   *Note:* The sophisticated Full check handles the pointer wraparound.

### 4. Clock Generation & Top (`rtl/top.sv`)
**Concept:**
FPGAs require precise clock management. We cannot simply use logic dividers (e.g., `cnt[1]`) for clocks because they introduce skew and jitter.
**Implementation:**
*   **MMCM (Mixed-Mode Clock Manager):** A hard IP primitive in the Xilinx Zynq-7000 (which uses 7-Series fabric).
    *   Input: `sys_clk` (50MHz)
    *   Calculates VCO: 50MHz * 20 = 1000MHz.
    *   Output 0: 1000 / 10 = **100 MHz (Fast / Write Side)**
    *   Output 1: 1000 / 30 = **33.33 MHz (Slow / Read Side)**
*   **Data Path:**
    1.  `clk_100` increments a 32-bit counter.
    2.  Pushes counter value into FIFO.
    3.  `clk_33` reads from FIFO if not empty.
    4.  Upper bits are displayed on LEDs (`leds[3:0]`).

## Pinout (Alinx AX7015B)

| Signal | FPGA Pin | Description |
| :--- | :--- | :--- |
| `sys_clk` | **Y14** | 50MHz System Clock |
| `btn_rst_n` | **AB12** | Active-Low Reset Button |
| `leds[3:0]` | **A5, A7, A6, B8** | User LEDs (Display FIFO Data) |

## Usage

This project uses a `Makefile` to automate the Vivado simulation workflow.

### Simulation
Run the batch verification testbench:
```bash
make sim
```

### Waveform GUI
Open the Vivado Simulator GUI to inspect signals:
```bash
make gui
```

### Clean
Remove build artifacts:
```bash
make clean
```

## Implementation Metrics
After running `make build`, the following timing and utilization results were achieved (based on `timing_summary.rpt`, `cdc_report.rpt`, and `utilization.rpt`):

| Metric | Target | Actual | Description |
| :--- | :--- | :--- | :--- |
| **WNS (100MHz)** | > 0ns | **+7.008 ns** | Worst Negative Slack (Fast Domain) |
| **WNS (33MHz)** | > 0ns | **+27.035 ns** | Worst Negative Slack (Slow Domain) |
| **CDC Violations** | 0 | **0** | Unsafe crossings (0 Unsafe, 0 Unknown) |
| **LUT Utilization** | < 1% | **27 (0.06%)** | Logic usage (Slice LUTs) |
| **Register Utilization** | < 1% | **68 (0.07%)** | Flip-Flop usage |

## How to Verify It Worked

### 1. The Result
Since the simulation was run via the `Makefile`, you only need to look for one specific pattern in your terminal output:

* **The "Success" Message:** In `tb_async_fifo.sv`, the code is designed to print **"Simulation Passed!"** if the data coming out of the slow side matches exactly what went in the fast side.
* **The Waveform:** If you open the GUI, you should see `w_full` occasionally flickering high (telling the fast side to wait) and `r_empty` staying low (meaning the slow side always has data to read).

### 2. The 3 Concepts to Master

Instead of reading the code line-by-line, look at these three "patterns" that make the bridge safe:

1. **The Bucket (Dual-Port RAM):** This is the middle ground. The 100MHz domain drops data into a memory slot, and the 33MHz domain picks it up later. They never touch the same data at the exact same time.
2. **The Single-Bit "Handshake" (Gray Code):** To tell the other side "I've added data," we pass a counter. We use **Gray Code** because only one bit changes at a time (e.g., `011` -> `010`). If the slow clock catches the change halfway, it still sees a valid number, not total gibberish.
3. **The Waiting Room (2-FF Synchronizer):** We pass that counter through two "waiting" flip-flops. This gives the signal time to stop "vibrating" (metastability) before the other clock actually uses it.

## Concepts: MTBF & Gray Codes

### Why Gray Codes?
When crossing clock domains, multi-bit buses (like pointers) are dangerous. If `0111` (7) transitions to `1000` (8), all 4 bits flip. Due to skew, the receiver might sample `1111`, `0000`, etc. Gray codes ensure only **one bit changes** at a time (e.g., `0100` -> `1100`), guaranteeing that sampled values are always valid (either the old or new state).

### MTBF (Mean Time Between Failures)
We use a **2-FF Synchronizer** to maximize the Mean Time Between Failures.
$$ MTBF = \frac{e^{t_{slack}/\tau}}{f_{clk} \cdot f_{data} \cdot T_w} $$
By allowing a full clock cycle ($t_{slack}$) for the signal to resolve, the probability of a metastable event propagating is exponentially reduced.

## Key Takeaways

1.  **Metastability is Inevitable, but Manageable**
    *   We cannot prevent the "coin landing on its edge" (metastability), but we can wait until it falls over. The 2-FF synchronizer buys us the necessary time ($t_{slack}$).

2.  **The "Bus" Problem**
    *   Synchronizing single bits is easy (2-FF). Synchronizing a bus (like a counter) is impossible with just FFs because bits arrive at different times (skew).
    *   **Solution:** Convert the bus to Gray Code so it effectively behaves like a single-bit signal behaviorally (only 1 bit changes per clock), then sync it.

3.  **Decoupling Domains**
    *   The Async FIFO is the universal "Adapter" for digital logic. It allows a 100MHz CPU to talk to a 33MHz peripheral without forcing them to lock-step, absorbing small bursts of data speed mismatches.

4.  **Constraints are Code**
    *   Writing RTL isn't enough; we must tell the tool via XDC constraints (`set_false_path`) that these two clocks are unrelated, otherwise the tool wastes hours trying to fix timing violations that don't matter.