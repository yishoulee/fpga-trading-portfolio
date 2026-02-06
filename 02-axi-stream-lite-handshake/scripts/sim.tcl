# Create a simulation project structure
create_project -force sim_axis_handshake -part xc7z015clg485-2

# Add sources
# Note: glob path is relative to where vivado is launched, which is usually project root in Makefile
read_verilog -sv [glob ./rtl/*.sv]
read_verilog -sv [glob ./tb/*.sv]

# Set top
set_property top tb_axis_handshake [get_filesets sim_1]

# Launch Simulation
launch_simulation

# Run simulation
restart
run 200us


# Close
close_project
