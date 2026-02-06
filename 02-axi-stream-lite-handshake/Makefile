# Makefile for AXI-Stream Lite Handshake

.PHONY: all sim clean help

all: sim

help:
	@echo "Available targets:"
	@echo "  make sim      - Run simulation"
	@echo "  make clean    - Remove build artifacts"

sim:
	vivado -mode batch -source scripts/sim.tcl

clean:
	rm -rf sim_axis_handshake* .Xil vivado*.log vivado*.jou xsim.dir *.pb *.wdb
