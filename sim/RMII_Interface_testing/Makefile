SIM=ghdl
SIM_ARGS += --wave=wave.ghw
TOPLEVEL_LANG=vhdl

# Components lib
include ../../hdl/comp/sources.mk
# MAC lib
include ../../hdl/mac/sources.mk

VHDL_SOURCES = tb.vhd
TOPLEVEL = tb
MODULE = RMII_phy_sim
include $(shell cocotb-config --makefiles)/Makefile.sim
