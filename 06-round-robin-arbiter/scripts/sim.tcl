# Simulation Script for Round-Robin Arbiter

# 1. Create specific build directory for this project to avoid clutter
file mkdir build
cd build

# 2. Compile source files
puts "Compiling..."
# Use exec to run shell commands from Tcl. Note paths are now relative to build/
exec xvlog -sv -work work ../rtl/arbiter.sv ../tb/tb_arbiter.sv

# 3. Elaborate (Link) the design
puts "Elaborating..."
exec xelab -debug typical -top tb_arbiter -snapshot arbiter_snapshot

# 4. Simulate
puts "Simulating..."
exec xsim arbiter_snapshot -R
