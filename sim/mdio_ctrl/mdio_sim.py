import cocotb
import struct
import string
import random
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.utils import get_sim_time

# Test MDIO read
@cocotb.test()
async def mdio_rd_test(dut):
    dut.start.value = 0
    dut.wr.value = 0
    dut.phy_addr.value = 1
    dut.reg_addr.value = 3
    dut.data_in.value = 0

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(64 - 16):
        await RisingEdge(dut.mdio_mdc)

    data = 0xBFA5
    for i in range(16):
        dut.mdio_data_in.value = (data & 0x8000) >> 15
        data = data << 1
        await RisingEdge(dut.mdio_mdc)
        print(str(i) + " time " + str(get_sim_time()))
    
    for _ in range(0, 128):
        await RisingEdge(dut.clk)

    await Timer(10, "us")

# Test MDIO write
@cocotb.test()
async def mdio_wr_test(dut):
    dut.start.value = 0
    dut.wr.value = 1
    dut.phy_addr.value = 1
    dut.reg_addr.value = 3
    dut.data_in.value = 0xF0CA

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    for _ in range(64):
        await RisingEdge(dut.mdio_mdc)

    await Timer(10, "us")
