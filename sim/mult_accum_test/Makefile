SIM=ghdl
SIM_ARGS += --wave=wave.ghw
TOPLEVEL_LANG=vhdl
VHDL_SOURCES = \
$(PWD)/../../hdl/mac/rtl/simple_pipe.vhd \
$(PWD)/../../hdl/nic/rtl/mult.vhd \
$(PWD)/../../hdl/nic/rtl/conv_pipe.vhd 
TOPLEVEL = conv_pipe
MODULE = mult_accum_sim
include $(shell cocotb-config --makefiles)/Makefile.sim
