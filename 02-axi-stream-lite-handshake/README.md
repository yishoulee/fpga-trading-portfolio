# AXI-Stream Lite Handshake (Valid/Ready Flow Control)

This project implements a robust AXI-Stream Interface handshake mechanism, a fundamental building block for high-speed digital design. It demonstrates **Backpressure Handling** and **Pipeline Registration** without sacrificing throughput.

## Overview

*   **Goal:** Move 32-bit data reliably between two modules using `valid` and `ready` signals.
*   **Key Feature:** "Forward Registered Slice" ensuring timing closure on long paths while maintaining 100% throughput.
*   **Target:** Generic RTL (Simulated on Xilinx Zynq-7000 context).

## Technical Deep Dive: Concepts Learned

### 1. The AXI-Stream Handshake
The AXI-Stream protocol uses a simple but powerful flow control mechanism based on two signals:
*   **VALID (`s_axis_tvalid`):** Driven by the SOURCE. Indicates "I have valid data for you on the bus".
*   **READY (`m_axis_tready`):** Driven by the DESTINATION. Indicates "I am ready to accept new data".

**The Golden Rule:** A transfer *only* occurs on the rising clock edge where **BOTH** `VALID` and `READY` are HIGH.
*   If `VALID=1` and `READY=0`, the source must **hold** the data stable until `READY` comes up (Backpressure).
*   If `VALID=0` and `READY=1`, no transfer occurs (Idle/Bubble).

**Code Location:**
*   **RTL (`rtl/axis_register.sv`):** The logic `if (m_axis_tready || !m_axis_tvalid)` determines if the register can accept new data.
*   **Testbench (`tb/tb_axis_handshake.sv`):** The driver explicitly waits for `do ... while (!s_axis_tready); @(posedge clk);` to confirm the handshake occurred.

### 2. What is Backpressure?
Backpressure is the mechanism by which a slow consumer tells a fast producer to slow down. In AXI-Stream, this is done by deasserting `TREADY`.
*   Without backpressure handling, a fast producer would overwrite data that the consumer hasn't processed yet, leading to data loss.
*   In this project, we handle backpressure combinatorially. If the downstream `m_axis_tready` goes low, our locally registered `s_axis_tready` goes low immediately (after filling the internal register).

**Code Location:**
*   **Testbench:** `task monitor_control()` randomly toggles `m_axis_tready` low 30% of the time to simulate a busy CPU or full FIFO downstream.

### 3. Forward Registered Slice (Timing Isolation)
In large FPGA designs, routing valid/data signals across the chip can cause timing violations (setup time failures). To fix this, we add pipeline registers.
*   **Naive Approach:** If you just add a flip-flop to `valid` and `data`, you delay the handshake signal loop. This often halves bandwidth (1 transfer every 2 cycles) because `ready` cannot propagate backward fast enough.
*   **Our Solution (Forward Slice):** We use a special structure that allows 100% throughput (1 transfer every cycle) while still registering the forward path.
    *   **Logic:** `s_axis_tready = m_axis_tready || !m_axis_tvalid;`
    *   **Meaning:** We are ready if the downstream is ready OR if our internal register is currently empty.

### 4. Latency vs. Timing Trade-off
*   **Latency:** This module adds **1 clock cycle** of latency. Data entering on cycle `N` exits on cycle `N+1`.
*   **Timing:** By registering the outputs, we cut the "Comb Logic Delay" path. This allows the design to run at higher clock frequencies (e.g., 300MHz+ on UltraScale+).
*   **Trade-off:** We pay 1 cycle of latency to gain higher frequency capabilities.

## Modules

*   `rtl/axis_register.sv`: The DUT. A pipeline stage that registers `tdata` and `tvalid` (forward path) but passes `tready` combinatorially (backward path).
*   `tb/tb_axis_handshake.sv`: A constrained-random verification testbench.

## Usage

This project focuses on **verification**. Since this is an internal logic component, we do not generate a bitstream for the board.

### Simulation
Run the verified testbench. This compiles the design and runs 1000 randomized transactions.
```bash
make sim
```

**Expected Output:**
```text
Test Passed: 1000 transactions completed successfully.
```

## Implementation Metrics

| Metric | Value | Target | Pass? |
| :--- | :--- | :--- | :--- |
| **Throughput Efficiency** | 100% (1 word/clk) | 100% | Pass |
| **Latency** | 1 Cycle | 1 Cycle | Pass |
| **Backpressure Handling** | Zero Data Loss | Zero Data Loss | Pass |
| **Logic Depth (Forward)** | 1 Register | 1 Register | Pass |

## Simulation Verification Methodology

The testbench (`tb/tb_axis_handshake.sv`) implements an **ASIC-style verification environment**:

1.  **Randomized Backpressure (Stress Test):**
    *   The monitor randomly drives `m_axis_tready` LOW.
    *   **Verification:** We ensured the driver correctly samples `s_axis_tready` *after* the clock edge to prevent deadlocks.
2.  **Randomized Bubbles:**
    *   The driver inserts random gaps (`tvalid=0`) to ensure the pipeline doesn't rely on continuous data.
3.  **Self-Checking Scoreboard:**
    *   A SystemVerilog queue (`[$]`) records every sent transaction.
    *   The monitor compares received data against this queue to detect any dropped or corrupted bits.
