# Makefile for Project 03: CDC Blinky

# Paths
SCRIPTS_DIR := scripts
SIM_BUILD_DIR := sim_build

.PHONY: all sim gui clean

default: sim

build:
	vivado -mode batch -source $(SCRIPTS_DIR)/build.tcl

program:
	vivado -mode batch -source $(SCRIPTS_DIR)/program.tcl

sim:
	vivado -mode batch -source $(SCRIPTS_DIR)/sim.tcl

gui:
	cd $(SIM_BUILD_DIR) && xsim tb_async_fifo_snap -gui -tclbatch ../$(SCRIPTS_DIR)/xsim_wave.tcl

clean:
	rm -rf $(SIM_BUILD_DIR) cdc_blinky.bit cdc_blinky_prj .Xil
	rm -f *.log *.jou *.pb *.wdb *.str *.rpt
	rm -f $(SCRIPTS_DIR)/*.log $(SCRIPTS_DIR)/*.jou
