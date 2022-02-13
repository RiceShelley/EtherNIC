SIM=ghdl
SIM_ARGS += --wave=wave.ghw
TOPLEVEL_LANG=vhdl
VHDL_SOURCES = $(PWD)/../rtl/MAC.vhd \
$(PWD)/../rtl/MII_Phy_Interface.vhd \
$(PWD)/../rtl/MAC_pack.vhd \
$(PWD)/../rtl/math_pack.vhd \
$(PWD)/../rtl/async_fifo.vhd \
$(PWD)/../rtl/simple_pipe.vhd \
$(PWD)/../rtl/eth_to_layer_two_eth.vhd \
$(PWD)/../rtl/eth_pack.vhd \
$(PWD)/../rtl/sync_fifo.vhd
TOPLEVEL = mac
MODULE = eth_sim
include $(shell cocotb-config --makefiles)/Makefile.sim


