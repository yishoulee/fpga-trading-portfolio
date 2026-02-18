# Makefile for Project 06: Round-Robin Arbiter

.PHONY: all clean sim

all: sim

sim:
	vivado -mode batch -source scripts/sim.tcl
	@echo ""
	@echo "### Simulation Output ###"
	@cat build/xsim.log

clean:
	rm -rf .Xil *.log *.jou build/