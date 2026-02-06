# Makefile for Alinx AX7015B Safe Binary Counter

.PHONY: all build program clean help

# Default target
all: build

help:
	@echo "Available targets:"
	@echo "  make build    - Run Vivado synthesis and implementation to generate bitstream"
	@echo "  make program  - Program the Alinx AX7015B board via JTAG"
	@echo "  make sim      - Run simulation and generate waveform (top_tb.vcd)"
	@echo "  make clean    - Remove build artifacts and logs"

# Build the bitstream
build:
	vivado -mode batch -source scripts/build.tcl

# Program the FPGA
program:
	vivado -mode batch -source scripts/program.tcl

# Run Simulation
sim:
	vivado -mode batch -source scripts/sim.tcl

# Clean up build artifacts
clean:
	rm -rf counter_prj sim_prj* .Xil
	rm -f *.log *.jou *.rpt *.str *.vcd *.pb *.wdb
	rm -f counter.bit
