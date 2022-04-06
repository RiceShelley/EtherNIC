SIM=ghdl
SIM_ARGS += --wave=wave.ghw
TOPLEVEL_LANG=vhdl
VHDL_SOURCES = \
$(PWD)/../../rtl/MAC_pack.vhd \
$(PWD)/../../rtl/eth_pack.vhd \
$(PWD)/../../rtl/math_pack.vhd \
$(PWD)/../../rtl/simple_pipe.vhd \
$(PWD)/../../rtl/async_fifo.vhd \
$(PWD)/../../rtl/sync_fifo.vhd \
$(PWD)/../../rtl/RMII_Phy_Interface.vhd 
TOPLEVEL = rmii_phy_interface
MODULE = RMII_phy_sim
#TESTCASE = mac_flood_tx_pipe
include $(shell cocotb-config --makefiles)/Makefile.sim
