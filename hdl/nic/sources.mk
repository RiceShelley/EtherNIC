# MDIO lib
mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
PREFIX := $(dir $(mkfile_path))
VHDL_SOURCES_NIC := \
$(PREFIX)rtl/NIC.vhd					\
$(PREFIX)rtl/Ov7670_reader.vhd			\
$(PREFIX)rtl/udp_traffic_gen.vhd		\
