.PHONY: all sim build program clean

all: sim build

sim:
	# Run simulation for core logic
	tclsh scripts/sim.tcl

build:
	# Run Synthesis and Implementation to generate bitstream
	vivado -mode batch -source scripts/build.tcl

program:
	# Program the FPGA with the generated bitstream
	vivado -mode batch -source scripts/program.tcl

test_hw:
	# Run interactive hardware test via VIO
	vivado -mode batch -source scripts/test_hardware.tcl

clean:
	rm -rf sim_build build xsim.dir .Xil
	rm -f *.log *.jou *.pb *.wdb *.str *.backup.log *.backup.jou
	rm -f top.bit top.ltx captured_data.csv *.rpt


