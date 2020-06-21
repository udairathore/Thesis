# Root directory of source
SRC_DIR ?= "../Verilog"

# Vivado source
COMPILE_SRC ?= ./feeder.tcl


# RFSoC
DEVICE ?= RFSoC



all:
	mkdir -p outputs/ && vivado -mode batch -source $(COMPILE_SRC) -log ./outputs/vivado.log -journal ./outputs/vivado.jou -tclargs $(SRC_DIR) $(DEVICE)

clean:
	-rm -rf outputs/ project/ .Xil/
	-rm *.log *.jou
