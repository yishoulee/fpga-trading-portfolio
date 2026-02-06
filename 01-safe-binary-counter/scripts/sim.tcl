# Create a simulation project structure
create_project -force sim_prj -part xc7z015clg485-2

# Add sources
read_verilog -sv [glob ./rtl/*.sv]
read_verilog -sv [glob ./tb/*.sv]

# Set top
set_property top top_tb [get_filesets sim_1]

# Launch Simulation
launch_simulation

# Run simulation
# Current scope is inside the simulation object
restart
run all

# Close
close_project

# Copy VCD to root
file copy -force ./sim_prj.sim/sim_1/behav/xsim/top_tb.vcd ./top_tb.vcd

exit
