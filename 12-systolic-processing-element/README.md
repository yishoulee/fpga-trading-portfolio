# Project 12: Systolic Processing Element (AI/ML)

## 1. Project Overview
This project designs the **atomic unit of AI hardware**: a Systolic Processing Element (PE). It implements a high-performance **Multiply-Accumulate (MAC)** engine, the core operation behind Matrix Multiplication and Convolutional Neural Networks (CNNs).

Instead of relying on behavioral synthesis (`y <= w * x + acc`), this design **manually instantiates the Xilinx DSP48E1 primitive**. This low-level approach grants full control over the internal pipeline registers, enabling the design to close timing at **250 MHz+**, a critical requirement for High-Frequency Trading (HFT) and high-throughput AI inference.

**Key Features:**
-   **Manual Primitive Instantiation:** Direct control of the `DSP48E1` silicon tile for maximum performance.
-   **Weight Stationary Dataflow:** Designed for efficient systolic array integration where weights are loaded once and features stream through.
-   **Deep Pipelining:** Utilizes internal `AREG`, `BREG`, `MREG`, and `PREG` registers to break critical paths.
-   **3-Cycle Latency:** Achieving high throughput (1 result per clock) at the cost of a fixed initial latency.
-   **Validated Fmax:** Simulation confirms correct operation at 250 MHz (4ns clock period).

## 2. Theory & Background
### The "Black Box" of Synthesis
In standard FPGA design, writing `a * b + c` allows the synthesizer to infer a DSP block. However, the tool makes conservative guesses about pipelining. If the tool fails to infer the internal registers (`MREG`, `PREG`), the path from the multiplier input to the adder output becomes a long combinatorial chain, capping maximum frequency at ~100-150 MHz.

### The DSP48E1 Primitive
The Zynq-7015 contains 160 **DSP48E1** slices. Each slice is a hardened ASIC-like block containing:
1.  **25x18 Multiplier:** Two's complement multiplication.
2.  **48-bit Accumulator:** Adder/Subtractor with feedback.
3.  **Pipeline Registers:** `A/B` (Input), `M` (Multiplier out), `P` (Accumulator out).

By manually instantiating the primitive and enabling these registers, we isolate the mathematical operations into small, fast discrete steps.
-   **Cycle 1:** Load Inputs (A, B)
-   **Cycle 2:** Multiply (M = A * B)
-   **Cycle 3:** Accumulate (P = P + M)

This pipelining allows the clock to run extremely fast because significantly less work is done per clock cycle.

## 3. System Architecture
The PE is designed as a **Weight Stationary** node, optimized for vertical data flow in the DSP slice.

```text
       [ System Inputs ]
              |
              v
      +-------+-------+
      |  Clock Enable |
      |   (valid_in)  |
      +-------+-------+
              |
              v
    +-------------------------------------------------------+
    |                    mac_pe.sv                          |
    |         (Wraps Xilinx DSP48E1 Primitive)              |
    |                                                       |
    |        +=================+                            |
    |        |   Weight (8b)   |                            |
    |        +========+========+                            |
    |                 |                                     |
    |                 v                                     |
    |          +-------------+                              |
    |          |    AREG     | (Pipeline Stage 1)           |
    |          |    (A2)     |                              |
    |          +------+------+                              |
    |                 |                                     |
    |                 v                                     |
    |          +-------------+                              |
    |          | Multiplier  |                              |
    |          |   (25x18)   |                              |
    |          +------+------+                              |
    |                 |                                     |
    |                 v                                     |
    |          +-------------+                              |
    |          |    MREG     | (Pipeline Stage 2)           |
    |          +------+------+                              |
    |                 |                                     |
    |                 v                                     |
    |          +-------------+            +---------+       |
    |          | Adder / Acc |<-----------|  P_REG  |--+    |
    |          | (48-bit)    |            | (Stage3)|  |    |
    |          +------+------+            +----+----+  |    |
    |                 |                        ^       |    |
    |                 v                        |       |    |
    |          +-------------+                 |       |    |
    |          |    PREG     |-----------------+       |    |
    |          +------+------+                         |    |
    |                 |                                |    |
    |                 v                                |    |
    |         ( Output: P[31:0] )                      |    |
    |                 |                                |    |
    +-----------------+--------------------------------+----+
                      |                                |
                      v                                v
                [ Accum Out ]                    [ Feature Out ]
```

### Signal Flow
1.  **Setup:** `weight` is presented on the input.
2.  **Streaming:** `valid_in` asserts, and `feature_in` streams new data every clock cycle.
3.  **Pipeline:**
    *   **T+0:** Inputs latched into `AREG`/`BREG`.
    *   **T+1:** Product latched into `MREG`.
    *   **T+2:** Sum latched into `PREG` (Output).
4.  **Result:** The `accum_out` presents the running sum of products.

## 4. RTL Modules: Detailed Architecture

### The MAC PE (`rtl/mac_pe.sv`)
A thin wrapper around the `DSP48E1` primitive.

*   **Inputs:**
    *   `weight` (8-bit): Sign-extended to 30-bit `A` port.
    *   `feature_in` (8-bit): Sign-extended to 18-bit `B` port.
    *   `valid_in`: Drives the Clock Enable (CE) pins of all internal registers.
*   **Outputs:**
    *   `accum_out` (32-bit): Derived from the lower 32 bits of the 48-bit `P` port.
    *   `feature_out` (8-bit): A registered copy of the input feature, creating a systolic delay chain for the next PE.

### The Testbench (`tb/tb_mac_pe.sv`)
Validates the timing and arithmetic correctness.
*   **Clock:** 250 MHz (4ns period).
*   **Sequence:**
    1.  Reset (Wait 100ns for GSR).
    2.  Load Weight (5).
    3.  Stream Features (1, 2, 3).
    4.  Flush Pipeline (3 cycles).
    5.  Check Accumulator:
        *   Cycle 1: `1 * 5 = 5`
        *   Cycle 2: `2 * 5 + 5 = 15`
        *   Cycle 3: `3 * 5 + 15 = 30`

## 5. Challenges & Solutions

| Challenge | Root Cause | Solution |
| :--- | :--- | :--- |
| **Simulation "X" / Zero Output** | The "GSR Trap". Xilinx primitives hold internal registers in reset for the first 100ns of simulation via the `glbl` module. | The testbench waits `#100` (100ns) before releasing reset or applying stimuli. |
| **Pipeline Freezing** | Dropping `valid_in` immediately after the last data input freezes the internal pipeline registers, trapping the final calculation. | The testbench extends `valid_in` for 3 extra cycles (feeding zeros) to "flush" the pipeline and push the final result to the output. |
| **DSP Mode Selection** | Configuring the DSP48 dynamic `OPMODE` to perform `P = P + (A*B)` properly. | Manually derived `OPMODE` `7'b0100101` (Z=P, Y=0, X=M) based on UG479 to enable the accumulator feedback loop. |

## 6. Hardware Verification & Performance Metrics

The design was fully implemented and validated on a Zynq-7015 (AX7015B) FPGA.

| Metric | Result | Notes |
| :--- | :--- | :--- |
| **Target Device** | XC7Z015-CLG485-2 | AX7015B SOM |
| **Max Frequency (Fmax)** | **250 MHz** | Clock Period: 4.0ns |
| **Worst Negative Slack (WNS)** | 0.356 ns | Timing Met |
| **DSP Utilization** | 1 / 160 (0.63%) | Single PE Instantiated |
| **Power (Est)** | < 100 mW | Single PE Dynamic Power |

### Hardware Test Results (`make test_hw`)
Using Vivado VIO (Virtual Input/Output), we injected stimuli into the running FPGA fabric.

1.  **Reset Validation:** Confirmed accumulator clears to `0`.
2.  **1-Second Accumulation (1x1):**
    *   **Input:** Weight=1, Feature=1, Duration=1s @ 250MHz.
    *   **Expected:** 250,000,000.
    *   **Measured:** `250,692,835` (0x0EF144E3).
    *   **Conclusion:** The pipeline is stable and counting every clock cycle without dropping beats.
3.  **High-Speed Burst (10x10):**
    *   **Input:** Weight=10, Feature=10, Duration=~10ms @ 250MHz.
    *   **Multiplier Operation:** 10 * 10 = 100 added per cycle.
    *   **Measured:** `280,266,900`.
    *   **Conclusion:** Multiplier and adder logic within the DSP slice function correctly at full speed.

## 7. Quick Start / Make Commands

| Command | Description |
| :--- | :--- |
| `make sim` | Runs behavioral simulation in Vivado XSIM. |
| `make build` | Synthesizes and Implements the design to generate `top.bit`. |
| `make program` | Programs the FPGA via JTAG. |
| `make test_hw` | Runs the Tcl hardware verification suite (requires connected FPGA). |
| `make clean` | Removes all build artifacts, logs, and temporary files. |

**To replicate the results:**
1.  Connect AX7015B Board via JTAG.
2.  Run `make build` (approx 3-5 mins).
3.  Run `make program`.
4.  Run `make test_hw` and observe terminal output.

## 8. Key Concepts & Application

This project bridged theoretical FPGA concepts with practical implementation strategies, demonstrating how to achieve high performance through low-level control.

### Core Concepts
1.  **Manual Primitive Instantiation (The "Metal" Layer)**
    *   **Concept**: Modern synthesis tools are powerful but conservative. Writing `y <= w * x + acc` relies on the tool to guess how to map logic to hardware.
    *   **Application**: We bypassed the tool's heuristics and manually instantiated the `DSP48E1` slice. By directly connecting the `A`, `B`, `M`, and `P` ports, we forced the silicon to behave exactly as we needed, ensuring no logic was wasted and performance was maximized.

2.  **Deep Pipelining & Retiming**
    *   **Concept**: The maximum frequency (`Fmax`) of a digital circuit is determined by the longest path between two registers.
    *   **Application**: We used the DSP48E1's internal pipeline registers (`AREG` for inputs, `MREG` for multiplier, `PREG` for accumulator) to break the 48-bit math operation into three distinct <4ns stages. This allowed the clock to run at **250 MHz** because the critical path was confined to the internal routing of a single hard block.

3.  **Hardware-in-the-Loop (HIL) Verification**
    *   **Concept**: Simulation is only a model. Real hardware has noise, thermal effects, and initialization quirks (like GSR).
    *   **Application**: Instead of just trusting the testbench, we used the **Vivado VIO (Virtual Input/Output)** core to allow a standard Tcl script to "reach inside" the FPGA. This gave us a scripted, automated way to feed 250 MHz logic from a slow JTAG interface and verify the results mathematically.

4.  **Weight Stationary Dataflow**
    *   **Concept**: In AI/ML, moving data costs more energy than computing on it. "Weight Stationary" keeps the model parameters (Weights) fixed in registers while input data (Features) flows past them.
    *   **Application**: Our PE architecture creates a register-based "memory" for the weight. In a larger systolic array, this reduces memory bandwidth requirements, as weights are loaded once and reused across thousands of feature inputs.

5.  **The "GSR Trap" (Global Set/Reset)**
    *   **Concept**: Xilinx FPGAs assert a global reset (GSR) for ~100ns after startup to initialize all flip-flops.
    *   **Application**: We modified our simulation testbench to wait `#100` before starting. Without this, our simulation showed `X` (undefined) values because we were trying to drive logic that the chip was actively holding in reset. This taught us to respect the device's power-on sequence.
