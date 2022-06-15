# MDIO lib
mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
PREFIX := $(dir $(mkfile_path))
VHDL_SOURCES_MDIO := \
$(PREFIX)rtl/MAC_registers.vhd		\
$(PREFIX)rtl/MDIO_controller.vhd