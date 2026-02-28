## Physical Constraints (Alinx AX7015B)

# System Clock (50MHz)
set_property PACKAGE_PIN Y14 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
create_clock -period 20.000 -name sys_clk -waveform {0.000 10.000} [get_ports sys_clk]

# Reset Button (Active Low)
set_property PACKAGE_PIN AB12 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]

# LEDs (Active Low)
# LED1 (A5) - Buy Signal (High Price)
set_property PACKAGE_PIN A5 [get_ports led_buy]
set_property IOSTANDARD LVCMOS33 [get_ports led_buy]

# LED2 (A7) - Sell Signal (Low Price)
set_property PACKAGE_PIN A7 [get_ports led_sell]
set_property IOSTANDARD LVCMOS33 [get_ports led_sell]

# LED3 (A6) - Market Activity (Packet Processed)
set_property PACKAGE_PIN A6 [get_ports led_activity]
set_property IOSTANDARD LVCMOS33 [get_ports led_activity]

# LED4 (B8) - System Idle/Heartbeat
set_property PACKAGE_PIN B8 [get_ports led_idle]
set_property IOSTANDARD LVCMOS33 [get_ports led_idle]


# ----------------------------------------------------------------------------------
# Ethernet RGMII Interface
# ----------------------------------------------------------------------------------

# PHY Reset (Active Low) - B7
set_property PACKAGE_PIN B7 [get_ports phy_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports phy_rst_n]

# ETH RX Clock (RGMII_RXC) - PHY2_RXCK -> B4
set_property PACKAGE_PIN B4 [get_ports eth_rxc]
set_property IOSTANDARD LVCMOS33 [get_ports eth_rxc]
create_clock -period 8.000 -name rgmii_rx_clk -waveform {0.000 4.000} [get_ports eth_rxc]

# ETH RX Control (RGMII_RX_CTL) - PHY2_RXCTL -> B3
set_property PACKAGE_PIN B3 [get_ports eth_rx_ctl]
set_property IOSTANDARD LVCMOS33 [get_ports eth_rx_ctl]

# ETH RX Data (RGMII_RXD[3:0])
# PHY2_RXD0 -> A2
set_property PACKAGE_PIN A2 [get_ports {eth_rxd[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {eth_rxd[0]}]
# PHY2_RXD1 -> A1
set_property PACKAGE_PIN A1 [get_ports {eth_rxd[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {eth_rxd[1]}]
# PHY2_RXD2 -> B2
set_property PACKAGE_PIN B2 [get_ports {eth_rxd[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {eth_rxd[2]}]
# PHY2_RXD3 -> B1
set_property PACKAGE_PIN B1 [get_ports {eth_rxd[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {eth_rxd[3]}]

# Input Timing Constraints (Relaxed for now, assuming PHY adds delay or trace length match)
# Usually RGMII needs ~2ns setup/hold window.

# Internal generated clocks
# We treat the RGMII RX Clock as asynchronous to Sys Clk
set_clock_groups -asynchronous -group [get_clocks sys_clk] -group [get_clocks rgmii_rx_clk]

# Configuration Voltage
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# ----------------------------------------------------------------------------------
# CDC Constraints (Cross Domain Crossing)
# ----------------------------------------------------------------------------------

# The AXI-Lite registers (Weights/Thresholds) are configuration signals.
# They are stable during packet processing. We ignore timing from the AXI 
# clock domain (100MHz) to the Ethernet RX clock domain (125MHz).
set_false_path -from [get_cells -hierarchical -filter {NAME =~ *u_axi_regs/slv_reg*}] -to [get_clocks rgmii_rx_clk]

# Ensure the generated clocks from the PLL are also treated as async to the RGMII RX clock
# (Updating the previous group to be more inclusive of generated clocks)
set_clock_groups -asynchronous     -group [get_clocks -include_generated_clocks sys_clk]     -group [get_clocks -include_generated_clocks rgmii_rx_clk]


# Fix IDELAY timing path 
# The timing violations are on paths FROM the input pad TO the FF.
# The violation is Hold time (-6.8ns).
# This means the data is changing too fast after the clock edge.
# We delayed the clock by ~1.2ns (IDELAY_VALUE=15). 
# If we have a massive hold violation, it means the clock is arriving WAY after the data has already become invalid.
# Or, the analysis is assuming edge-aligned launch and capture.

# Let's relax the hold requirement explicitly for RGMII inputs if we trust the IDELAY.


# RGMII Input Constraints - Adjusted for Internal Delay and Direct Capture
# We are using IDELAY on the CLOCK path (or data path?) to center the window.
# Previous attempt: IDELAY on DATA, Clock Inverted -> Massive Hold Violation (Clock too late).
# Current Strategy: IDELAY on DATA (15 taps ~ 1.2ns), Clock NON-Inverted.
# This should align the capture edge closer to the data eye.
# If Clock is 0ns, Data is delayed 1.2ns. Capturing at 0ns (Rise) -> Setup Check.
# Data Valid Window at Pin: -2ns to +2ns (relative to clock edge).
# Delayed Data Window at FF: -0.8ns to +3.2ns.
# Capture at 0ns: Setup met (Valid > 0). Hold met (Valid > 0).
# Let's clean constraints and try strict RGMII-ID style constraints first.
# Assuming PHY outputs Edge Aligned (Data valid 0ns-4ns? No, usually center aligned or edge aligned).
# Realtek PHY usually requires IDELAY in MAC (FPGA).
# If PHY provides Edge Aligned (Transmitter): Data changes at Clock Edge.
# We hold Data 1.2ns. Data changes at 1.2ns internal.
# We capture at 0ns. This is safe (Old Data).
# Wait, capture at 0ns would capturing the Previous data (valid until 1.2ns).
# So we need set_input_delay reflecting the previous cycle?

set_input_delay -clock [get_clocks rgmii_rx_clk] -max 2.0 [get_ports {eth_rxd[*] eth_rx_ctl}]
set_input_delay -clock [get_clocks rgmii_rx_clk] -min -1.0 [get_ports {eth_rxd[*] eth_rx_ctl}]

