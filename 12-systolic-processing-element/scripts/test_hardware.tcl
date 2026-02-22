# Test Script for Project 12: Systolic PE Hardware Verification
# Usage: vivado -mode batch -source scripts/test_hardware.tcl

puts "--------------------------------------------------------"
puts "Starting Hardware Test for Systolic Processing Element"
puts "--------------------------------------------------------"

# 1. Connect to Hardware
open_hw_manager
connect_hw_server
open_hw_target

puts "Identifying Device..."
set dev [current_hw_device [get_hw_devices xc7z015*]]
refresh_hw_device -update_hw_probes false $dev

# Try to load existing probes file if not found
if {[get_property PROBES.FILE $dev] == ""} {
    set probes_file "top.ltx"
    if {[file exists $probes_file]} {
        puts "Loading probes file: $probes_file"
        set_property PROBES.FILE $probes_file $dev
        refresh_hw_device $dev
    } else {
        puts "WARNING: Probes file $probes_file not found. VIO names may be missing."
    }
} else {
    puts "Probes file already loaded: [get_property PROBES.FILE $dev]"
}

# Debug: List all VIOs found
set all_vios [get_hw_vios -of_objects $dev]
puts "Found VIOs: $all_vios"
foreach v $all_vios {
    puts "VIO: $v Name: [get_property CELL_NAME $v]"
}

# 2. Get VIO Object
# As per top.sv:
# probe_out0: rst_n (1 bit)
# probe_out1: weight (8 bit)
# probe_out2: feature (8 bit)
# probe_out3: valid (1 bit)
# probe_in0:  accum_out (32 bit)

# Try finding ANY VIO if specific name fails
if {[llength $all_vios] > 0} {
    set vio [lindex $all_vios 0]
    puts "Using VIO: $vio"
} else {
    set vio ""
}

if {$vio == ""} {
    puts "ERROR: VIO Core not found. Is the FPGA programmed?"
    exit 1
}

if {$vio != ""} {
    puts "VIO Probes:"
    set all_probes [get_hw_probes -of_objects $vio]
    foreach p $all_probes {
        puts "  Probe: $p Name: [get_property NAME $p]"
    }
}

# Define Signal Names for readability
# Probes seem to be named after the nets in top.sv
set vio_rst_n   [get_hw_probes -of_objects $vio -filter {NAME =~ "*vio_rst_n"}]
set vio_weight  [get_hw_probes -of_objects $vio -filter {NAME =~ "*vio_weight"}]
set vio_feature [get_hw_probes -of_objects $vio -filter {NAME =~ "*vio_feature"}]
set vio_valid   [get_hw_probes -of_objects $vio -filter {NAME =~ "*vio_valid"}]
set vio_accum   [get_hw_probes -of_objects $vio -filter {NAME =~ "*pe_accum_out"}]

# Verify all probes were found
if {[llength $vio_rst_n] == 0} { puts "ERROR: Probe vio_rst_n not found"; exit 1 }
if {[llength $vio_weight] == 0} { puts "ERROR: Probe vio_weight not found"; exit 1 }
if {[llength $vio_feature] == 0} { puts "ERROR: Probe vio_feature not found"; exit 1 }
if {[llength $vio_valid] == 0} { puts "ERROR: Probe vio_valid not found"; exit 1 }
if {[llength $vio_accum] == 0} { puts "ERROR: Probe pe_accum_out not found"; exit 1 }

# Helper function to step clock cycles manually? No, clock is free running at 250 MHz.
# We are driving VIO asynchronously from PC (slow).
# Since the bandwidth of VIO JTAG is much slower than 250 MHz, we can't do single-cycle accurate feeding via VIO.
# However, the PE logic accumulates P = P + (A*B) when valid is high.
# If we keep 'valid' high while we are setting 'feature' via VIO (which takes milliseconds),
# the PE will accumulate the SAME feature millions of times!
#
# CRITICAL: We cannot toggle valid/feature fast enough via VIO for a continuous stream.
# But we can test one multiplication at a time if we toggle valid quickly?
# Actually, VIO 'commit' operation writes the value.
#
# Strategy for VIO testing of Streaming Logic:
# 1. Set Feature and Weight.
# 2. Set Valid = 1.
# 3. Wait tiny bit?
# 4. Set Valid = 0.
#
# Even with the fastest Tcl command, 'Valid=1' will last for many milliseconds of FPGA time (thousands/millions of cycles).
# So: Result = Old_Accum + (Weight * Feature * Duration_in_Cycles).
# This makes verifying "30" impossible because the accumulation will run wild.
#
# OH! The user code has:
#    always_ff @(posedge clk_250m) begin
#        weight_reg  <= vio_weight;
#        feature_reg <= vio_feature;
#        valid_reg   <= vio_valid;
#    end
#
# The PE accumulates EVERY clock cycle while valid_in is 1.
#
# To verify this with VIO, we have a problem. We need a "Single Step" or "Pulse" mechanism in hardware,
# or we just accept that we will see a huge number.
#
# Alternatively, since we just want to verify connectivity and multiplication:
# We can set Weight=0. Then Accum should stay constant.
# We can set Weight=1, Feature=1. Accum should count up by 1 every cycle (Counter).
# We can set Weight=2, Feature=10. Accum should count up by 20 every cycle.
#
# Let's verify the "Counter" behavior.

puts "Test 1: Check Reset"
set_property OUTPUT_VALUE 0 $vio_rst_n
set_property OUTPUT_VALUE 0 $vio_valid
set_property OUTPUT_VALUE 00 $vio_weight
set_property OUTPUT_VALUE 00 $vio_feature
commit_hw_vio $vio_rst_n $vio_valid $vio_weight $vio_feature

refresh_hw_vio $vio
set result [get_property INPUT_VALUE $vio_accum]
scan $result %x decimal_result
puts "Reset Result (Expect 0): $decimal_result (Hex: $result)"

puts "Test 2: Release Reset (Valid=0)"
set_property OUTPUT_VALUE 1 $vio_rst_n
commit_hw_vio $vio_rst_n
refresh_hw_vio $vio
set result [get_property INPUT_VALUE $vio_accum]
scan $result %x decimal_result
puts "Idle Result (Expect 0): $decimal_result (Hex: $result)"

puts "Test 3: Free Running Accumulation (Weight=1, Feature=1)"
# P = P + (1*1) -> P increments by 1 every cycle (250 million times a second)
set_property OUTPUT_VALUE 01 $vio_weight
set_property OUTPUT_VALUE 01 $vio_feature
commit_hw_vio $vio_weight $vio_feature

puts "Enable Accumulator..."
set_property OUTPUT_VALUE 1 $vio_valid
commit_hw_vio $vio_valid
# It is now counting at 250 MHz...
after 1000 ;# Wait 1 second
set_property OUTPUT_VALUE 0 $vio_valid
commit_hw_vio $vio_valid

refresh_hw_vio $vio
set result [get_property INPUT_VALUE $vio_accum]
scan $result %x decimal_result
# Result should be approximately 250,000,000 (0x0EE6B280)
# But note 32-bit overflow happens at ~4 billion (17 seconds).
puts "1 Second Accumulation Result (Expect ~250M): $decimal_result (Hex: $result)"


puts "Test 4: High Growth (Weight=10, Feature=10)"
# Reset first
set_property OUTPUT_VALUE 0 $vio_rst_n
commit_hw_vio $vio_rst_n
set_property OUTPUT_VALUE 1 $vio_rst_n
commit_hw_vio $vio_rst_n

# Setup 10*10 = 100 per cycle.  10 = 0x0A
set_property OUTPUT_VALUE 0A $vio_weight
set_property OUTPUT_VALUE 0A $vio_feature
commit_hw_vio $vio_weight $vio_feature


set_property OUTPUT_VALUE 1 $vio_valid
commit_hw_vio $vio_valid
after 10 ;# Wait 10ms
set_property OUTPUT_VALUE 0 $vio_valid
commit_hw_vio $vio_valid

refresh_hw_vio $vio
set result [get_property INPUT_VALUE $vio_accum]
scan $result %x decimal_result
# 10ms * 250MHz = 2,500,000 cycles.
# 2.5M * 100 = 250,000,000.
puts "10ms High-Speed Accumulation (Expect ~250M): $decimal_result (Hex: $result)"

close_hw_target
close_hw_manager
