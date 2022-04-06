SIM=ghdl
SIM_ARGS += --wave=wave.ghw
TOPLEVEL_LANG=vhdl

VHDL_SOURCES = $(PWD)/../../rtl/MDIO_controller.vhd

TOPLEVEL = mdio_controller
MODULE = mdio_sim
include $(shell cocotb-config --makefiles)/Makefile.sim

