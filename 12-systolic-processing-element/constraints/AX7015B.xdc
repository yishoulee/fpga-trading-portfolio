## Physical Constraints (Alinx AX7015B)
set_property PACKAGE_PIN Y14 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
create_clock -add -name sys_clk_pin -period 20.00 -waveform {0 10} [get_ports sys_clk]

## Reset Button (Optional, usually we use VIO reset)
## set_property PACKAGE_PIN AB12 [get_ports btn_rst_n]
## set_property IOSTANDARD LVCMOS33 [get_ports btn_rst_n]
