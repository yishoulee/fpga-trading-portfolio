
# ----------------------------------------------------------------------------------
# Build Script for Project 12: Systolic Processing Element
# Target: Alinx AX7015B (xc7z015clg485-2)
# ----------------------------------------------------------------------------------

file mkdir build
cd build

set project_name "systolic_pe"
set part_name "xc7z015clg485-2"
set output_dir "."

# Create project
create_project -force $project_name $output_dir -part $part_name

# Add source files
add_files ../rtl/mac_pe.sv
add_files ../rtl/top.sv
add_files ../constraints/AX7015B.xdc

# Create IP: Clock Wizard (50MHz -> 250MHz)
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_wiz_0
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {50.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {250.000} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_RESET {false} \
] [get_ips clk_wiz_0]

# Create IP: VIO (Virtual Input/Output)
create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name vio_0
set_property -dict [list \
    CONFIG.C_NUM_PROBE_OUT {4} \
    CONFIG.C_NUM_PROBE_IN {1} \
] [get_ips vio_0]

set_property -dict [list \
    CONFIG.C_PROBE_OUT0_WIDTH {1} \
    CONFIG.C_PROBE_OUT1_WIDTH {8} \
    CONFIG.C_PROBE_OUT2_WIDTH {8} \
    CONFIG.C_PROBE_OUT3_WIDTH {1} \
    CONFIG.C_PROBE_IN0_WIDTH {32} \
] [get_ips vio_0]

# Generate IP targets
generate_target all [get_ips clk_wiz_0]
generate_target all [get_ips vio_0]

# Set Top Module
set_property top top [current_fileset]

# Run Synthesis
puts "Starting Synthesis..."
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check Timing (Synthesis)
open_run synth_1 -name synth_1
report_timing_summary -file $output_dir/post_synth_timing.rpt

# Run Implementation
puts "Starting Implementation..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# Check Timing (Implementation)
open_run impl_1 -name impl_1
report_timing_summary -file $output_dir/post_impl_timing.rpt
report_utilization -file $output_dir/post_impl_utilization.rpt

# Copy Bitstream and Reports
if {[file exists $output_dir/$project_name.runs/impl_1/top.bit]} {
    # Copy Bitstream
    file copy -force $output_dir/$project_name.runs/impl_1/top.bit ../top.bit
    puts "Bitstream generated: top.bit"

    # Copy Probes (LTX)
    file copy -force $output_dir/$project_name.runs/impl_1/top.ltx ../top.ltx
    puts "Probes file generated: top.ltx"

    # Copy Reports
    file copy -force $output_dir/post_impl_timing.rpt ../timing_summary.rpt
    puts "Timing report generated: timing_summary.rpt"

    file copy -force $output_dir/post_impl_utilization.rpt ../utilization.rpt
    puts "Utilization report generated: utilization.rpt"
    
    puts "--------------------------------------------------------"
    puts "Build Complete Successfully."
    puts "--------------------------------------------------------"
} else {
    puts "ERROR: Bitstream not found."
    exit 1
}

# Close project
close_project
