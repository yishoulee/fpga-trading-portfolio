# Build script for Project 03 CDC Blinky
set project_name "cdc_blinky_prj"
create_project -force $project_name ./$project_name -part xc7z015clg485-2

# Add sources
add_files [glob ./rtl/*.sv]
add_files -fileset constrs_1 ./constraints/AX7015B.xdc
add_files -fileset sim_1 ./tb/tb_async_fifo.sv

# Set top
set_property top top [current_fileset]

# Synthesis
puts "Running Synthesis..."
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check Synthesis Status
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed"
    exit 1
}

# Implementation and Bitstream
puts "Running Implementation and Bitstream Generation..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# Check Implementation Status
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed"
    exit 1
}

# Copy bitstream to root for convenience
file copy -force ./$project_name/$project_name.runs/impl_1/top.bit ./cdc_blinky.bit
puts "Build Complete. Bitstream generated: cdc_blinky.bit"
