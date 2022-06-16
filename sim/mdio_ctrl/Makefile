SIM=ghdl
SIM_ARGS += --wave=wave.ghw
TOPLEVEL_LANG=vhdl

# MDIO lib
include ../../hdl/mdio/sources.mk

VHDL_SOURCES = tb.vhd

TOPLEVEL = tb
MODULE = mdio_sim
include $(shell cocotb-config --makefiles)/Makefile.sim
