
# Program the FPGA
# Usage: vivado -mode batch -source scripts/program.tcl

set bitstream_file "top.bit"
set probes_file "top.ltx"

puts "Connecting to Hardware Server..."
open_hw_manager
connect_hw_server
open_hw_target

puts "Identifying Device..."
set dev [current_hw_device [get_hw_devices xc7z015*]]
refresh_hw_device -update_hw_probes false $dev

puts "Programming FPGA with $bitstream_file..."
set_property PROBES.FILE $probes_file $dev
set_property PROGRAM.FILE $bitstream_file $dev
program_hw_devices $dev

refresh_hw_device $dev
puts "FPGA Programmed Successfully."
exit
