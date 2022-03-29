import cocotb
import struct
import string
import random
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge

# Test MDIO read
@cocotb.test()
async def mdio_rd_test(dut):
    dut.start.value = 0
    dut.wr.value = 0
    dut.phy_addr.value = 5
    dut.reg_addr.value = 3
    dut.data_in.value = 0

    clock = Clock(dut.mdio_clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    await RisingEdge(dut.mdio_clk)
    dut.start.value = 1
    await RisingEdge(dut.mdio_clk)
    dut.start.value = 0
    for _ in range(0, 64 - 16):
        await RisingEdge(dut.mdio_clk)

    data = 0x3FA5
    for _ in range(0, 16):
        await RisingEdge(dut.mdio_clk)
        dut.mdio_data.value = (data & 0x8000) >> 15
        data = data << 1

    for _ in range(0, 128):
        await RisingEdge(dut.mdio_clk)

    await Timer(100, "ns")

# Test MDIO write
@cocotb.test()
async def mdio_wr_test(dut):
    dut.start.value = 0
    dut.wr.value = 1
    dut.phy_addr.value = 5
    dut.reg_addr.value = 3
    dut.data_in.value = 0xF0CA

    clock = Clock(dut.mdio_clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    await RisingEdge(dut.mdio_clk)
    dut.start.value = 1
    await RisingEdge(dut.mdio_clk)
    dut.start.value = 0

    for _ in range(0, 128):
        await RisingEdge(dut.mdio_clk)

    await Timer(100, "ns")
