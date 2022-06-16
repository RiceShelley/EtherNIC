SIM=ghdl
SIM_ARGS += --wave=wave.ghw
TOPLEVEL_LANG=vhdl

# NIC lib
include ../../hdl/nic/sources.mk

VHDL_SOURCES = $(PWD)/tb.vhd
TOPLEVEL = tb
MODULE = udp_sim
include $(shell cocotb-config --makefiles)/Makefile.sim
