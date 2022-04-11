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
$(PWD)/../../hdl/mac/rtl/l1_eth_frame_decoder.vhd \
$(PWD)/../../hdl/mac/rtl/crc32_check.vhd \
$(PWD)/../../hdl/mac/rtl/MAC_rx_mtr_axis.vhd \
$(PWD)/../../hdl/mac/rtl/fb_pipeline_writer.vhd \
$(PWD)/../../hdl/mac/rtl/fb_pipeline_reader.vhd \
$(PWD)/../../hdl/mac/rtl/tx_crc_pipe.vhd \
$(PWD)/../../hdl/mac/rtl/frame_builder_pipe.vhd \
$(PWD)/../../hdl/mac/rtl/MII_Phy_Interface.vhd \
$(PWD)/../../hdl/mac/rtl/RMII_Phy_Interface.vhd \
$(PWD)/../../hdl/mac/rtl/MAC_registers.vhd \
$(PWD)/../../hdl/mac/rtl/MDIO_controller.vhd \
$(PWD)/../../hdl/mac/rtl/MAC_rx_pipeline.vhd \
$(PWD)/../../hdl/mac/rtl/MAC_tx_pipeline.vhd \
$(PWD)/../../hdl/mac/rtl/MAC_RMII.vhd \
$(PWD)/../../hdl/nic/rtl/Ov7670_reader.vhd \
$(PWD)/../../hdl/nic/rtl/udp_traffic_gen.vhd \
$(PWD)/../../hdl/nic/rtl/top.vhd
TOPLEVEL = top
MODULE = img_proc_sim
include $(shell cocotb-config --makefiles)/Makefile.sim
