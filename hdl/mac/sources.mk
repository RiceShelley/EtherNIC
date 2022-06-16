# MAC lib
mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
PREFIX := $(dir $(mkfile_path))
VHDL_SOURCES_MAC := \
$(PREFIX)rtl/MAC_pack.vhd 				\
$(PREFIX)rtl/eth_pack.vhd 				\
$(PREFIX)rtl/l1_eth_frame_decoder.vhd 	\
$(PREFIX)rtl/crc32_check.vhd 			\
$(PREFIX)rtl/MAC_rx_mtr_axis.vhd 		\
$(PREFIX)rtl/fb_pipeline_writer.vhd		\
$(PREFIX)rtl/fb_pipeline_reader.vhd 	\
$(PREFIX)rtl/tx_crc_pipe.vhd 			\
$(PREFIX)rtl/frame_builder_pipe.vhd 	\
$(PREFIX)rtl/MII_Phy_Interface.vhd 		\
$(PREFIX)rtl/RMII_Phy_Interface.vhd 	\
$(PREFIX)rtl/MAC_rx_pipeline.vhd 		\
$(PREFIX)rtl/MAC_tx_pipeline.vhd 		\
$(PREFIX)rtl/MAC_RMII.vhd 				\
$(PREFIX)rtl/MAC_MII.vhd