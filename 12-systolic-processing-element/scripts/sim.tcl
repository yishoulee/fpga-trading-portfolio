# Simulation Script for Project 12: Systolic PE

file mkdir sim_build
cd sim_build

puts "Compiling Sources..."
exec xvlog -sv ../rtl/mac_pe.sv ../tb/tb_mac_pe.sv -L unifast_ver -L unisims_ver -L unimacro_ver -L secureip >@ stdout
exec xvlog /tools/Xilinx/2025.1/data/verilog/src/glbl.v >@ stdout

puts "Elaborating..."
exec xelab -debug typical -top tb_mac_pe -top glbl -snapshot tb_mac_pe_snap -L unifast_ver -L unisims_ver -L unimacro_ver -L secureip >@ stdout

puts "Running Simulation..."
exec xsim tb_mac_pe_snap -R >@ stdout
