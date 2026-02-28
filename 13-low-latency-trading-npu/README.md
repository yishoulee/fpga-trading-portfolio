# Project 13: FPGA-Accelerated UDP Market Data Parser & NPU

## 1. Project Overview
This project implements a **Hardware-Accelerated Market Data Processing Pipeline** on the Alinx AX7015B (Zynq-7015). It features a cut-through architecture that processes Gigabit Ethernet UDP packets, parses financial protocols in real-time, and executes a trading strategy using a custom **Systolic Neural Processing Unit (NPU)**. This design moves the critical path of trading logic entirely into the FPGA fabric, eliminating OS jitter and achieving deterministic latency.

### Hardware Bring-Up & Debugging Spotlight
This debugging journey is the crown jewel of the project. It perfectly illustrates the gap between "it works in ModelSim" and "it works on physical silicon."

#### 1. The OS Bottleneck & Layer 2 Bypass (The `scapy` Fix)
*   **The Symptom:** Standard Python `socket` scripts sending UDP broadcast packets worked perfectly in simulation but failed to reach the physical FPGA.
*   **The Root Cause:** The host PC’s Linux/Windows kernel network stack was hijacking the packets. Because the FPGA is a passive, RX-only receiver, it does not respond to ARP (Address Resolution Protocol) requests. Without an ARP reply, the host OS's routing table refused to forward the packets to the physical copper interface.
*   **The Fix:** Transitioned from application-layer sockets to **raw sockets using `scapy`**. By dropping down to Layer 2 (Data Link Layer), we bypassed the OS kernel, IP routing tables, and ARP cache entirely, injecting raw Ethernet frames directly into the NIC driver.
*   **The Takeaway:** This mirrors real-world High-Frequency Trading (HFT) "kernel bypass" techniques (like Solarflare/Onload) to guarantee transmission and shave off latency.

#### 2. Hunting the True Offset with the ILA (Simulation vs. Reality)
*   **The Symptom:** The NPU output remained zero despite the `scapy` script successfully flooding the physical network link.
*   **The Root Cause:** The testbench simulation became "bug-compatible" with the RTL, creating a false positive. The RTL was looking for the stock symbol at an arbitrary offset, and the simulation was modified to feed data at that exact offset. However, real-world Ethernet + IPv4 + UDP headers consume exactly 42 bytes.
*   **The Fix:** Armed a hardware trap using the **Vivado Integrated Logic Analyzer (ILA)**. By triggering strictly on `gmii_rx_dv == 1` and flooding the direct link, we captured the physical wire data. This proved the payload started exactly at byte 42, allowing us to realign the `udp_parser` state machine perfectly to the physical network stack.

#### 3. The "Ghost Weights" (Hardware Initialization)
*   **The Symptom:** The hardware pipeline was correctly extracting the price, but the NPU result was always 0, meaning the LED trigger threshold was never crossed.
*   **The Root Cause:** In simulation, the testbench explicitly wrote the AXI weights before sending packets. On physical silicon, the registers inside `axi_weight_regs` initialized to zero on power-up.
*   **The Fix:** Utilized a **Virtual Input/Output (VIO)** core to simulate the control plane. Since the full Zynq PS (Processing System) adds significant build complexity, we instantiated a VIO core to drive the AXI-Lite interface. This allows us to manually "inject" weights and thresholds via the Vivado Hardware Manager console, verifying the datapath without needing a full embedded Linux stack.

#### 4. Parameterizing Time (The 1-Second Pulse Stretcher)
*   **The Symptom:** The RTL simulation appeared to completely "hang" or freeze immediately after successfully calculating a valid trade and triggering the module.
*   **The Root Cause:** The hardware trigger mechanism included a pulse-stretcher to keep the active-low LED on for 1 second so it was visible to the human eye. At 125MHz, this required a counter of `125,000,000`. The behavioral simulator was trying to blindly simulate 125 million empty clock cycles.
*   **The Fix:** Parameterized the `LED_PULSE_TICKS` in `top.sv`. For physical synthesis, it defaults to 125 million. When instantiated in `tb_system.sv`, the parameter is overridden to just 100 cycles, allowing the simulation to execute instantly while preserving real-world hardware functionality.

## 2. Theory & Implementation
### The Race to Zero (Latency)
In High-Frequency Trading (HFT), speed is the differentiator. This project implements a **Cut-Through Architecture**:
1.  **Decode** headers as they stream across the wire (byte-by-byte).
2.  **Trigger** the NPU immediately upon the capture of the final byte of the relevant field (Price).
3.  **Execute** arithmetic logic in parallel using an unrolled hardware pipeline.

### System Diagram
```text
       [ Ethernet Cable ]
              |
              v
    +-----------------------+
    |    RGMII Interface    |  <-- PHY Interface (125 MHz)
    |  (top_wrapper + PLL)  |
    +---------+-------------+
              | (GMII Internal)
              v
    +-----------------------+
    |   RGMII / GMII MAC    |  <-- MAC Layer
    +---------+-------------+
              | (AXI-Stream 8-bit)
              v
    +-----------------------+
    |    UDP / IP Parser    |  <-- "The Gatekeeper"
    |  (FSM: Idle->IP->UDP) |      Filters for Symbol "0050"
    +---------+-------------+      Extracts Price @ Byte 46
              | (Price, Valid)
              v
    +-----------------------+      +--------------------+
    |     Systolic NPU      | <--- |  AXI-Lite Config   |
    |   (8 PE Stages)       |      | (VIO / Debug Core) |
    +---------+-------------+      +--------------------+
              | (Dot Product Score)
              v
    +-----------------------+
    |    Decision Logic     |  <-- "The Trader"
    +---------+-------------+      Compare Score vs Threshold
              |
     +--------+--------+
     |        |        |
   [BUY]    [SELL]   [LEDs]
 (Low Price) (High Price)
```

## 3. RTL Modules: Detailed Architecture

### 1. Physical Layer & Wrapper (`rtl/top_wrapper.sv`, `rtl/rgmii_rx.sv`)
-   **Wrapper:** The true top-level entity. It instantiates the PLL for clock generation (200MHz Ref, 100MHz AXI, 50MHz User) and the VIO core for simulating the control plane.
-   **RGMII RX:** Uses Xilinx `IDELAY` and `IDDR` primitives to capture Double Data Rate (DDR) signals from the Ethernet PHY and convert them to a single-data-rate, 8-bit wide GMII bus at 125 MHz.

### 2. MAC & Parser (`rtl/mac_rx.sv`, `rtl/udp_parser.sv`)
-   **MAC:** Operates in the 125 MHz clock domain. Checks frame delimiters and signals valid data to the parser.
-   **Parser:** A Finite State Machine (FSM) tailored to a fixed packet structure. It monitors byte offsets to identify the Symbol (Bytes 42-45) and Price (Bytes 46-49).
-   **Zero-Copy:** No buffering of the full packet. Processing happens *byte-by-byte*.

### 3. Neural Processing Unit (`rtl/npu_core.sv`)
-   **Architecture:** 8-stage 1D Systolic Array.
-   **Operation:** $Result = \sum_{i=0}^{7} (Weight_i \times Price)$.
-   **Latency:** The Array has a fixed latency of **16 clock cycles** (2 cycles per PE).
-   **Correction:** The `result_valid` signal is perfectly delay-matched to ensure we only sample the final accumulated value. This alignment is critical; reading one cycle early results in invalid partial sums.

### 4. Configuration Interface (`rtl/axi_weight_regs.sv`)
-   **Role:** Implements a memory-mapped AXI4-Lite Slave interface.
-   **Storage:** Maintains the 8 NPU weights (`slv_reg0`-`slv_reg7`) and the Buy/Sell Threshold (`slv_reg8`).
-   **Dynamic Updates:** Allows an external controller (VIO or ARM Processor) to update trading parameters in real-time without re-synthesizing the FPGA bitstream.

### 5. Top-Level Integration (`rtl/top.sv`)
This module is the "Motherboard" of the design, handling:
-   **Clock Domain Crossing (CDC):** Safely moving data between 125 MHz (Ethernet), 100 MHz (System), and 50 MHz (AXI-Lite).
-   **LED Logic:** Pulse stretchers ensure microsecond-long triggers are visible.
    *   **LED A5 (Buy):** Active when `NPU Score < Threshold` (Buy Low / Value Strategy).
    *   **LED A7 (Sell):** Active when `NPU Score > Threshold` (Sell High / Momentum Strategy).
    *   **LED A6 (Activity):** Flashes on valid packet.
    *   **LED B8 (Idle):** 1Hz Heartbeat to confirm FPGA is alive.

## 4. Hardware Verification & Results

### Validation Matrix
| Verification Stage | Tool / Method | Status | Notes |
| :--- | :--- | :--- | :--- |
| **RTL Simulation** | Vivado XSim | **Passed** | Verified bit-accurate NPU math and Parser FSM state transitions. |
| **Synthesis** | Vivado 2025.1 | **Passed** | OOC Synthesis complete. |
| **Place & Route** | Vivado Implementation | **Passed** | 8 DSP48E1 slices used (5% utilization). |
| **Static Timing** | Report Timing Summary | **Mixed** | Core logic (125MHz) met setup (WNS +0.645ns). CDC paths flagged (need explicit false_path constraints). |
| **Loopback Test** | Python + Scapy | **Passed** | Validated packet reception and LED triggers on physical hardware. |

### Visual Indicators
| LED | Pin | Logic | Interpretation |
| :--- | :--- | :--- | :--- |
| **LED 1** | A5 | Result < Threshold | **BUY Signal** (Undervalued Asset) |
| **LED 2** | A7 | Result > Threshold | **SELL Signal** (Overvalued Asset) |
| **LED 3** | A6 | Valid Pulse | **Market Activity** (Parsing Success) |
| **LED 4** | B8 | 1Hz Toggle | **System Idle** (Heartbeat) |

### Test Procedure
We use `sudo` to bypass the OS network stack and inject raw packets.

1.  **Buy Signal Test (Low Price):** PC sends price `90-99` $\rightarrow$ LED A5 lights up.
2.  **Sell Signal Test (High Price):** PC sends price `101-110` $\rightarrow$ LED A7 lights up.

## 5. Quick Start (Replication)

| Command | Description |
| :--- | :--- |
| `make build` | Synthesize and implement the RTL to generate `top.bit`. |
| `make program` | Program the AX7015B FPGA via JTAG. |
| `make sim` | Run the SystemVerilog testbench validating the Buy/Sell logic. |
| `make packet_test` | Floods the network with a single UDP market packet (Symbol: 0050, Price: 100) at 1000 packets/sec to stress-test the parser. (Requires `sudo`). |
| `make market_sim` | Sends a sequence of changing market prices (Buy -> Sell -> Buy) with 1.5s delay to demonstrate the trading logic and LED triggers. (Requires `sudo`). |

**Step-by-Step Demo:**
1.  **Hardware Setup:** Connect the AX7015B Ethernet port to your Linux PC (e.g., `eno1`).
2.  **Program FPGA:** Run `make program`. Verify the "Idle" LED (B8) starts blinking.
3.  **Prepare Test Script:** Edit `scripts/send_packet.py` or `scripts/test_market_signals.py` to match your PC's interface name (`INTERFACE = "eno1"`).
4.  **Run Traffic:**
    ```bash
    make market_sim
    ```
5.  **Observe:** Watch the LEDs toggle between Buy and Sell actions as the "market" moves.

## 6. Key Concepts Learned

1.  **Systolic Dataflow:** Design pipelines where data moves through processing units (Data-in-Motion) rather than units fetching from memory.
2.  **Network Stack Bypass:** Standard sockets fail in bare-metal FPGA comms; Raw Sockets (Scapy) are essential for Layer 2 verification.
3.  **Pipeline Synchronization:** The importance of matching pipeline depth (latency) with control signals (`valid`) to avoid sampling invalid transient data.
4.  **Hardware Debugging:** Using LEDs as "slow" logic analyzers for "fast" events when an ILA isn't available or practical.
5.  **CDC Discipline:** Managing multiple clock domains (125MHz Ethernet Rx, 100MHz Global, 50MHz AXI) requires careful handshake or FIFO boundaries.
