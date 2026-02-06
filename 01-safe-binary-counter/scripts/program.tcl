open_hw_manager
connect_hw_server
# Open the first available target
open_hw_target

# Find the specific Zynq 7015 device (avoiding arm_dap)
set dev_list [get_hw_devices xc7z015*]

if { [llength $dev_list] == 0 } {
    puts "ERROR: Could not find any xc7z015 device."
    puts "Available devices: [get_hw_devices]"
    exit 1
}

# Pick the first matching device (likely xc7z015_1)
set dev [lindex $dev_list 0]
puts "Found Target Device: $dev"

current_hw_device $dev
set_property PROGRAM.FILE {./counter.bit} $dev
program_hw_devices $dev

close_hw_target
close_hw_manager
puts "Programming Complete."
