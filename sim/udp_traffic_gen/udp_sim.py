import cocotb
import struct
import string
import random
from cocotb.triggers import Timer
from cocotbext.eth import GmiiFrame, MiiPhy
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import (AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor, AxiLiteMaster, AxiLiteBus)

@cocotb.test()
async def udp_traffic_gen(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.send_pkt.value = 0
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)
    dut.s_axis_tready.value = 1
    for _ in range(5):
        await RisingEdge(dut.clk)

    dut.send_pkt.value = 1
    await RisingEdge(dut.clk)
    dut.send_pkt.value = 0

    for _ in range(100):
        await RisingEdge(dut.clk)

    