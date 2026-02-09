## Physical Constraints (Alinx AX7015B)
set_property PACKAGE_PIN Y14 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
create_clock -add -name sys_clk_pin -period 20.00 -waveform {0 10} [get_ports sys_clk]

set_property PACKAGE_PIN A5 [get_ports {leds[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[0]}]

set_property PACKAGE_PIN A7 [get_ports {leds[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[1]}]

set_property PACKAGE_PIN A6 [get_ports {leds[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[2]}]

set_property PACKAGE_PIN B8 [get_ports {leds[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[3]}]

set_property PACKAGE_PIN AB12 [get_ports btn_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports btn_rst_n]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## Timing Constraints (CDC)
# Ignore timing between the 100MHz (CLKOUT0) and 33MHz (CLKOUT1) domains
set_false_path -from [get_clocks -of_objects [get_pins mmcm_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins mmcm_inst/CLKOUT1]]
set_false_path -from [get_clocks -of_objects [get_pins mmcm_inst/CLKOUT1]] -to [get_clocks -of_objects [get_pins mmcm_inst/CLKOUT0]]
