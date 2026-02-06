# Safe Binary Counter with Reset Bridge (Ax7015B)

This project implements a 32-bit binary counter on the Alinx AX7015B FPGA board, featuring a robust "Reset Bridge" to ensure timing-safe recovery from asynchronous resets.

## Overview
*   **Goal:** Blink LEDs using the high-order bits of a 32-bit counter.
*   **Key Feature:** Asynchronous Assert, Synchronous De-assert Reset Bridge.
*   **Target:** Xilinx Zynq-7000 (xc7z015clg485-2).

## Modules
*   `reset_bridge.v`: Synchronizes the external reset button to the clock domain.
*   `counter.v`: 32-bit up-counter.
*   `top.v`: Wraps the design and maps ports to pins.

## Pinout (Alinx AX7015B)

| Signal | FPGA Pin | Description |
| :--- | :--- | :--- |
| `clk` | **Y14** | 50MHz System Clock |
| `btn_rst_n` | **AB12** | Active-Low Reset Button |
| `leds[0]` | **A5** | User LED 1 |
| `leds[1]` | **A7** | User LED 2 |
| `leds[2]` | **A6** | User LED 3 |
| `leds[3]` | **B8** | User LED 4 |

## Usage

This project uses a `Makefile` to automate the Vivado workflow.

### Build
Run synthesis and implementation to generate the bitstream:
```bash
make build
```

### Simulation
Run the testbench to verify the Reset Bridge logic:
```bash
make sim
```

### Program
Program the Alinx board via JTAG:
```bash
make program
```

## Implementation Metrics (Vivado 2025.1)

| Metric | Value | Target | Pass? |
| :--- | :--- | :--- | :--- |
| **Worst Negative Slack (WNS)** | `+17.5 ns` | `> 0 ns` | Pass |
| **Reset Recovery Slack** | `+18.1 ns` | `> 0 ns` | Pass |
| **LUT Utilization** | `7` / `46,200` | `< 1%` | Pass |
| **FF Utilization** | `29` / `92,400` | `< 1%` | Pass |

## Simulation Verification

The simulation (`make sim`) verifies the correct operation of the **Reset Bridge** (Asynchronous Assertion, Synchronous De-assertion).

**Results:**
```text
Time: 100000 | Releasing reset asynchronously (offset from clock edge)...
Time: 103000 | Reset Pin: 1 | Internal Reset: 0 (Should still be LOW due to sync)
PASS: Reset Bridge held internal reset low asynchronously.
Time: 131000 | Reset Pin: 1 | Internal Reset: 1 (Should be HIGH now)
PASS: Internal reset synchronized and released.
Fast-forwarding counter to test LED toggle...
Time: 2131000 | LEDs: 1110 (Should have changed)
```

## Design Requirements Met

| Requirement | Implementation Details | Status |
| :--- | :--- | :--- |
| **Reset Logic** | Created `reset_bridge.v` to convert noisy `arst_n` to clean `rst_n`. |  Done |
| **ASIC Twist** | Implemented classic "Reset Bridge" topology (2-stage synchronizer) with explicit timing constraints in `constraints/AX7015B.xdc`. | Done |
| **Metastability/Startup** | Testbench (`top_tb.v`) explicitly verifies the delay between external release and internal execution, ensuring clean startup. | Verified |
| **KPI: Timing Slack** | WNS: `+17.5 ns`, Reset Recovery: `+18.1 ns`. All timing constraints met with positive slack. | Achieved |

## Detailed Concepts & Learnings

### 1. The "Reset Bridge"
*   **Global Definition:** A circuit pattern used to safely interface an asynchronous reset source (like a physical button) with a synchronous system. It guarantees that the entire system enters reset immediately (Asynchronous Assertion) but exits reset perfectly synchronized with the system clock (Synchronous De-assertion).
*   **Implementation (`rtl/reset_bridge.v`):**
    ```verilog
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            // Asynchronous Assert: Reset happens immediately, ignoring clock
            rst_n_meta <= 1'b0;
            rst_n      <= 1'b0;
        end else begin
            // Synchronous De-assert: Release waits for the clock
            rst_n_meta <= 1'b1;
            rst_n      <= rst_n_meta;
        end
    end
    ```
*   **Result:** Verified in simulation (`top_tb.v`). The design handles asynchronous assert (immediate) and synchronous de-assert (aligned to clock) correctly.

### 2. Metastability
*   **Global Definition:** A hazardous state in digital electronics where a flip-flop's output gets stuck halfway between logic '0' and logic '1' (or oscillates) because the input changed exactly when the clock edge arrived (violating setup/hold setup times). This state can persist for an unpredictable time, potentially propagating invalid data downstream.
*   **Implementation:** We mitigated this using a **2-stage synchronizer** in `reset_bridge.v`. The first flip-flop (`rst_n_meta`) "takes the hit" from the asynchronous button press. Even if it goes metastable, the second flip-flop (`rst_n`) waits one full clock cycle (20ns), by which time the first one has statistically settled, providing a clean signal to the `counter.v`.
*   **Result:** The simulation proved that even when the external reset was released asynchronously at 103ns (dangerous timing), the internal reset waited until 131ns (safe timing) to release.

### 3. Recovery Time
*   **Global Definition:** The minimum amount of time a reset signal must be released (go inactive) *before* the active clock edge occurs. It is effectively the "Setup Time" requirement for reset signals.
    *   *Violation Consequence:* Different parts of the chip might exit reset on different clock cycles, crashing state machines.
*   **Implementation:** Enforced by the `ax7015b.xdc` constraint: `create_clock -period 20.00 ...`. Vivado analyzes the path from the `rst_n` register to every flip-flop in `counter.v` to ensure the signal arrives at least slightly before the clock edge.
*   **Result:** **PASSED** with **+18.106 ns** of slack. This means the reset signal arrives comfortably before the clock edge (requirements were met with large margin).

### 4. Removal Time
*   **Global Definition:** The minimum amount of time a reset signal must remain active *after* the active clock edge. It is effectively the "Hold Time" requirement for reset signals.
    *   *Violation Consequence:* The reset might be perceived as inactive too early, leading to unpredictable register values.
*   **Implementation:** Also enforced by the `create_clock` constraint. Vivado ensures that the path delays are sufficient so that the reset signal doesn't disappear faster than the flip-flops can latch it.
*   **Result:** **PASSED** with **+0.169 ns** of slack. This confirms the reset signal remains stable long enough for the registers to capture it reliably.




