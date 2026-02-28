# Makefile for Project 13: Low Latency Trading NPU

# Tool configuration
VIVADO ?= vivado
XVLOG ?= xvlog
XELAB ?= xelab
XSIM ?= xsim

# Project settings
PROJECT_NAME = low_latency_npu
TOP_MODULE = tb_system
PART = xc7z015clg485-2

# Source files
RTL_SOURCES = \
    rtl/axi_weight_regs.sv \
    rtl/mac_pe.sv \
    rtl/mac_rx.sv \
    rtl/udp_parser.sv \
    rtl/npu_core.sv \
    rtl/top.sv

TB_SOURCES = \
    tb/tb_system.sv

.PHONY: all sim compile elaborate simulate build program packet_test market_sim clean

# Default target
all: sim

# Simulation targets
sim: compile elaborate simulate

compile:
	$(XVLOG) -sv $(RTL_SOURCES) $(TB_SOURCES)

elaborate:
	$(XELAB) -debug typical -top $(TOP_MODULE) -snapshot $(PROJECT_NAME)_snapshot

simulate:
	$(XSIM) $(PROJECT_NAME)_snapshot -tclbatch scripts/sim.tcl

# Build steps (Vivado project creation and Bitstream generation)
build:
	$(VIVADO) -mode batch -source scripts/build.tcl -log build.log -journal build.jou

# Program FPGA
program:
	$(VIVADO) -mode batch -source scripts/program.tcl -log program.log -journal program.jou

# Test/Simulation Targets (Requires sudo for raw socket access)
packet_test:
	sudo python3 scripts/send_packet.py

market_sim:
	sudo python3 scripts/test_market_signals.py --mode mix --delay 1.5

clean:
	rm -rf *.log *.jou *.pb *.wdb *.str xsim.dir .Xil
	rm -rf $(PROJECT_NAME) $(PROJECT_NAME)_snapshot low_latency_npu build
	rm -rf utilization.rpt timing_summary.rpt *.bit *.ltx 


