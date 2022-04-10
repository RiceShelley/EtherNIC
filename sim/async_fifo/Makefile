SIM=ghdl
SIM_ARGS += --wave=wave.ghw
TOPLEVEL_LANG=vhdl

VHDL_SOURCES = $(PWD)/../../hdl/mac/rtl/async_fifo.vhd \
$(PWD)/../../hdl/mac/rtl/math_pack.vhd

TOPLEVEL = async_fifo
MODULE = async_fifo_sim
include $(shell cocotb-config --makefiles)/Makefile.sim

