# ----------------------------------------------------------------------------------
# Build Script for Project 13: Low Latency Trading NPU
# Target: Alinx AX7015B (xc7z015clg485-2)
# ----------------------------------------------------------------------------------

file mkdir build
cd build

set project_name "low_latency_npu"
# Correct part for AX7015B
set part_name "xc7z015clg485-2"
set output_dir "."

# Create project
create_project -force $project_name $output_dir -part $part_name

# Add source files with absolute paths to avoid confusion in subdir
# Adding RTL
add_files [glob ../rtl/*.sv]
# Adding Constraints
add_files -fileset constrs_1 -norecurse ../constraints/AX7015B.xdc

# Create IP: Clock Wizard (50MHz -> 200, 100, 50)
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_wiz_0
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {50.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200.000} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {50.000} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_RESET {true} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT3_USED {true} \
] [get_ips clk_wiz_0]

# Create IP: VIO (Virtual Input/Output)
create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name vio_0
set_property -dict [list \
    CONFIG.C_NUM_PROBE_OUT {9} \
    CONFIG.C_NUM_PROBE_IN {2} \
    CONFIG.C_PROBE_IN0_WIDTH {32} \
    CONFIG.C_PROBE_IN1_WIDTH {5} \
    CONFIG.C_PROBE_OUT0_WIDTH {6} \
    CONFIG.C_PROBE_OUT1_WIDTH {1} \
    CONFIG.C_PROBE_OUT2_WIDTH {32} \
    CONFIG.C_PROBE_OUT3_WIDTH {4} \
    CONFIG.C_PROBE_OUT4_WIDTH {1} \
    CONFIG.C_PROBE_OUT5_WIDTH {1} \
    CONFIG.C_PROBE_OUT6_WIDTH {6} \
    CONFIG.C_PROBE_OUT7_WIDTH {1} \
    CONFIG.C_PROBE_OUT8_WIDTH {1} \
] [get_ips vio_0]

# Create IP: ILA for Ethernet Debug
create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_0
set_property -dict [list \
    CONFIG.C_PROBE0_WIDTH {1} \
    CONFIG.C_PROBE1_WIDTH {8} \
    CONFIG.C_PROBE2_WIDTH {1} \
    CONFIG.C_Data_Depth {4096} \
    CONFIG.C_NUM_OF_PROBES {3} \
    CONFIG.C_INPUT_PIPE_STAGES {1} \
] [get_ips ila_0]

# Generate IP targets
generate_target all [get_ips clk_wiz_0]
generate_target all [get_ips vio_0]

# Set Top Module
set_property top top_wrapper [current_fileset]

# Run Synthesis
puts "Starting Synthesis..."
# Synthesis options can be tweaked here
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check Timing (Synthesis) and Utilization
open_run synth_1 -name synth_1
report_timing_summary -file ./post_synth_timing.rpt
report_utilization -file ./post_synth_utilization.rpt

# Run Implementation
puts "Starting Implementation..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# Check Timing (Implementation) and Utilization
open_run impl_1 -name impl_1
report_timing_summary -file ./post_impl_timing.rpt
report_utilization -file ./post_impl_utilization.rpt

# Copy Results back to project root
# The bitstream name defaults to the top module name
if {[file exists $output_dir/$project_name.runs/impl_1/top_wrapper.bit]} {
    # Copy Bitstream
    file copy -force $output_dir/$project_name.runs/impl_1/top_wrapper.bit ../top.bit
    puts "Bitstream generated and copied: ../top.bit"

    # Copy Probes file (ltx) if it exists
    if {[file exists $output_dir/$project_name.runs/impl_1/top_wrapper.ltx]} {
        file copy -force $output_dir/$project_name.runs/impl_1/top_wrapper.ltx ../probes.ltx
        puts "Probes file generated and copied: ../probes.ltx"
    } else {
         # Fallback search for any .ltx
         set ltx_files [glob -nocomplain $output_dir/$project_name.runs/impl_1/*.ltx]
         if {[llength $ltx_files] > 0} {
             file copy -force [lindex $ltx_files 0] ../probes.ltx
             puts "Probes file generated and copied: ../probes.ltx"
         }
    }

    # Copy Reports to root
    file copy -force ./post_impl_timing.rpt ../timing_summary.rpt
    puts "Timing report generated: timing_summary.rpt"

    file copy -force ./post_impl_utilization.rpt ../utilization.rpt
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
