SIM=ghdl
SIM_ARGS += --wave=wave.ghw
TOPLEVEL_LANG=vhdl
VHDL_SOURCES = $(PWD)/../../hdl/nic/rtl/udp_traffic_gen.vhd 
TOPLEVEL = udp_traffic_gen
MODULE = udp_sim
include $(shell cocotb-config --makefiles)/Makefile.sim
