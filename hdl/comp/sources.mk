# Components lib
mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
PREFIX := $(dir $(mkfile_path))
VHDL_SOURCES_COMP := \
$(PREFIX)rtl/math_pack.vhd 		\
$(PREFIX)rtl/async_fifo.vhd 	\
$(PREFIX)rtl/sync_fifo.vhd 		\
$(PREFIX)rtl/skid_buffer.vhd 	\
$(PREFIX)rtl/simple_pipe.vhd