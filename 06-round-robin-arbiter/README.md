# Project 6: Round-Robin Arbiter

This project implements a **Round-Robin Arbiter** IP core that manages access to a shared resource among multiple requestors. It serves as a foundational component for memory controllers, network switches, and bus interconnects.

## What is a Round-Robin Arbiter?

An arbiter is a digital circuit that decides "who goes next" when multiple independent modules request access to a single shared resource at the same time.

### The Problem: Starvation
Imagine a system with three masters: a **CPU** (Master 0), a **Display Controller** (Master 1), and a **Wi-Fi Module** (Master 2), all sharing one DDR memory.
If we used a **Fixed Priority** scheme where Master 0 always wins:
1.  The CPU requests memory access constantly.
2.  The Wi-Fi module tries to save a packet but is blocked because the CPU is hogging the bus.
3.  The Wi-Fi buffer overflows and packets are dropped.
This is called **Starvation**. The lower-priority agents never get served.

### The Solution: Round-Robin Fairness
A **Round-Robin Arbiter** solves this by rotating priority in a circle (like a circle of people passing a ball).
*   If Master 0 wins in Cycle 1, it moves to the back of the line.
*   In Cycle 2, Master 1 has the highest priority.
*   In Cycle 3, Master 2 has the highest priority.

This guarantees that **every requestor eventually gets a turn**, ensuring Quality of Service (QoS) for all modules.

## Overview
*   **Goal:** Ensure multiple hardware modules (Masters) can access a single shared resource (Slave) fairly, without any single master starving the others.
*   **Key Feature:** Parameterized Round-Robin logic using a Mask/Pointer approach for single-cycle decision making.
*   **Target:** Generic SystemVerilog IP (Simulation verification).

## Architecture

```text
       REQUESTORS (Masters)                  ARBITER LOGIC                   SHARED RESOURCE
      (CPU, DMA, Network)                   (The "Traffic Cop")              (DDR, Bus, PCIe)
   _______________________               _______________________          _____________________
  |                       |             |                       |        |                     |
  |  [Master 0] --(req0)--> ===========>|  [Priority Pointer]   |=======>|                     |
  |                       |             |          |            |        |                     |
  |  [Master 1] --(req1)--> ===========>|  [Mask Generation]    |=======>|   [ACCESS GRANTED]  |
  |                       |             |          |            |        |                     |
  |  [Master 2] --(req2)--> ===========>|  [Grant Logic]        |=======>|                     |
  |_______________________|             |_______________________|        |_____________________|
                                                    |
                                                    v
                                             (Grant Vector)
                                          [001] -> Master 0 Wins
                                          [010] -> Master 1 Wins
                                          [100] -> Master 2 Wins
```

The core challenge in digital design is **Resource Contention**. Unlike "Fixed Priority" (where Master 0 always wins), a Round-Robin Arbiter rotates the priority. If Master 0 wins in Cycle 1, it becomes the lowest priority in Cycle 2.

## RTL Modules: Detailed Architecture

### 1. The Arbiter (`rtl/arbiter.sv`)
**Concept:**
A "Pointer" register tracks who has the highest priority. We use a **Masked Priority Encoder** approach, which is more efficient in hardware than a massive state machine.

**Key Logic:**
1.  **Pointer Register:** A one-hot vector indicating the *current* start of the priority line.
2.  **Mask Generation:** Creates a mask to block out requests lower than the current pointer.
    *   `mask = ~(pointer - 1) | pointer`
3.  **Double Arbitration:**
    *   **Arbiter 1 (Masked):** Checks requests that are equal to or higher than the pointer.
    *   **Arbiter 2 (Raw):** Checks requests that wrapped around (lower than the pointer).
    *   *Result:* If Arbiter 1 finds a winner, pick it. Otherwise, pick Arbiter 2.
4.  **Rotation:** On a grant, the pointer left-rotates to the bit *after* the winner.

**Interface:**
| Signal | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | Unit Clock |
| `rst_n` | Input | 1 | Active-low Asynchronous Reset |
| `req` | Input | N | Request Vector. Bit `i` corresponds to Master `i`. |
| `grant` | Output | N | One-Hot Grant Vector. Only one bit is high at a time. |

## Usage

This project uses a `Makefile` to run the simulation workflow. Since this is a pure logic block, we focus on functional verification.

### 1. Simulation (Verify Fairness)
Runs the SystemVerilog testbench (`tb/tb_arbiter.sv`) to verify the rotation logic and starvation freedom.
```bash
make sim
```
*Expected Output:*
```text
Project 06: Round-Robin Arbiter Testbench
-----------------------------------------
[T=0] Asserting Req[0]
Test 1: Agent 0 Single Grant: PASSED. Grant=001

[T=3] Asserting Req[0] and Req[1]
Test 3: Fairness (0 won last, so 1 should win): PASSED. Grant=010

[T=4] Asserting ALL Requests (req=111) for 10 cycles
Test 4.1: Grant 2: PASSED. Grant=100
Test 4.2: Grant 0: PASSED. Grant=001
Test 4.3: Grant 1: PASSED. Grant=010
...
```

## Key Concepts Learned

1.  **Arbitration Policies:**
    *   **Fixed Priority:** Simple, but dangerous. High-priority agents can starve others (e.g., if the CPU always wins, the network buffer might overflow).
    *   **Round Robin:** Fair. Guarantees every requestor eventually gets a turn. Critical for Quality of Service (QoS).

2.  **Hardware Efficiency (The "Double Arbiter" Trick):**
    *   Instead of using modulo arithmetic (`% N`) or complex `case` statements which synthesize poorly for large N, we used a **Masked Priority** approach.
    *   By arbitrating on `{req & mask}` and `{req}` in parallel, we solve the wrap-around problem purely with combinational logic.

3.  **One-Hot Encoding:**
    *   We used One-Hot encoding for the Grant signal and the Pointer.
    *   *Benefit:* No decoding latency. We don't need to convert binary `3` (11) to a select line. bit `3` is just there.

4.  **Parameterized Design:**
    *   The module works for `N=3`, `N=4`, or `N=16` simply by changing the parameter. Writing readable, scalable SystemVerilog is a professional skill.
