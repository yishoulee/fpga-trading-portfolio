# Build script for Vivado
set project_name "counter_prj"
# Check if project was already created in memory or disk, but this script assumes batch mode from scratch or open
# Use a safe create_project
create_project -force $project_name ./$project_name -part xc7z015clg485-2

# Add sources
add_files [glob ./rtl/*.sv]
add_files -fileset constrs_1 ./constraints/AX7015B.xdc
add_files -fileset sim_1 ./tb/top_tb.sv

# Set top
set_property top top [current_fileset]

# Synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run synth_1

# Report Timing (KPI)
report_timing_summary -file timing_summary.rpt
report_utilization -file utilization.rpt

# Implementation
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
open_run impl_1

# Report Methodology
report_methodology -file methodology.rpt

# Copy bitstream to root
file copy -force ./counter_prj/counter_prj.runs/impl_1/top.bit ./counter.bit
