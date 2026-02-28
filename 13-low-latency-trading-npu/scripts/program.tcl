# Program the FPGA
# Usage: vivado -mode batch -source scripts/program.tcl

set bitstream_file "top.bit"
set probes_file "probes.ltx"

puts "Connecting to Hardware Server..."
open_hw_manager
connect_hw_server
open_hw_target

puts "Identifying Device..."
# AX7015B uses XC7Z015
set dev [current_hw_device [get_hw_devices xc7z015*]]

puts "Programming FPGA with $bitstream_file..."
set_property PROGRAM.FILE $bitstream_file $dev

if {[file exists $probes_file]} {
    puts "Loading probes from $probes_file..."
    set_property PROBES.FILE $probes_file $dev
} else {
    puts "Warning: Probes file $probes_file not found."
}

program_hw_devices $dev

refresh_hw_device $dev
puts "FPGA Programmed Successfully."
exit
