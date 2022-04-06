SIM=ghdl
SIM_ARGS += --wave=wave.ghw -gGEN_RMII=TRUE
TOPLEVEL_LANG=vhdl
VHDL_SOURCES = \
$(PWD)/../../rtl/MAC_pack.vhd \
$(PWD)/../../rtl/eth_pack.vhd \
$(PWD)/../../rtl/math_pack.vhd \
$(PWD)/../../rtl/simple_pipe.vhd \
$(PWD)/../../rtl/async_fifo.vhd \
$(PWD)/../../rtl/sync_fifo.vhd \
$(PWD)/../../rtl/l1_eth_frame_decoder.vhd \
$(PWD)/../../rtl/crc32_check.vhd \
$(PWD)/../../rtl/MAC_rx_mtr_axis.vhd \
$(PWD)/../../rtl/fb_pipeline_writer.vhd \
$(PWD)/../../rtl/fb_pipeline_reader.vhd \
$(PWD)/../../rtl/tx_crc_pipe.vhd \
$(PWD)/../../rtl/frame_builder_pipe.vhd \
$(PWD)/../../rtl/MII_Phy_Interface.vhd \
$(PWD)/../../rtl/RMII_Phy_Interface.vhd \
$(PWD)/../../rtl/MAC_registers.vhd \
$(PWD)/../../rtl/MDIO_controller.vhd \
$(PWD)/../../rtl/MAC_rx_pipeline.vhd \
$(PWD)/../../rtl/MAC_tx_pipeline.vhd \
$(PWD)/../../rtl/MAC.vhd 
TOPLEVEL = mac
MODULE = mac_sim
include $(shell cocotb-config --makefiles)/Makefile.sim
