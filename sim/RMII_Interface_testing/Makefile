SIM=ghdl
SIM_ARGS += --wave=wave.ghw
TOPLEVEL_LANG=vhdl
VHDL_SOURCES = \
$(PWD)/../../hdl/mac/rtl/MAC_pack.vhd \
$(PWD)/../../hdl/mac/rtl/eth_pack.vhd \
$(PWD)/../../hdl/mac/rtl/math_pack.vhd \
$(PWD)/../../hdl/mac/rtl/skid_buffer.vhd \
$(PWD)/../../hdl/mac/rtl/simple_pipe.vhd \
$(PWD)/../../hdl/mac/rtl/async_fifo.vhd \
$(PWD)/../../hdl/mac/rtl/sync_fifo.vhd \
$(PWD)/../../hdl/mac/rtl/RMII_Phy_Interface.vhd 
TOPLEVEL = rmii_phy_interface
MODULE = RMII_phy_sim
#TESTCASE = mac_flood_tx_pipe
include $(shell cocotb-config --makefiles)/Makefile.sim
