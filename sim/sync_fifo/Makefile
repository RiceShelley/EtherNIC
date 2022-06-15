SIM=ghdl
SIM_ARGS += --wave=wave.ghw
TOPLEVEL_LANG=vhdl

# Components lib
include ../../hdl/comp/sources.mk

VHDL_SOURCES = tb.vhd
TOPLEVEL = tb
MODULE = sync_fifo_sim
include $(shell cocotb-config --makefiles)/Makefile.sim
