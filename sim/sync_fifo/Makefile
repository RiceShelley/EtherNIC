SIM=ghdl
SIM_ARGS += --wave=wave.ghw
TOPLEVEL_LANG=vhdl

VHDL_SOURCES = $(PWD)/../../rtl/sync_fifo.vhd \
$(PWD)/../../rtl/math_pack.vhd

TOPLEVEL = sync_fifo
MODULE = sync_fifo_sim
include $(shell cocotb-config --makefiles)/Makefile.sim

