import cocotb
import struct
import string
import random
from cocotb.triggers import Timer
from cocotb.queue import Queue, QueueFull
from cocotbext.eth import MiiSource, MiiSink
from cocotbext.eth import GmiiFrame, MiiPhy
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import (AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor)

@cocotb.test()
async def mult_accum_test(dut):
    mat = [
        [1, 1, 1],
        [1, 1, 1],
        [1, 1, 1]
    ]


    dut.rst.value = 0
    dut.start.value = 0

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    for _ in range(40):
        mat[0][0] = mat[0][0] + 1
        mat_vec = 0
        for row in mat:
            for pix in row:
                mat_vec = mat_vec << 8
                mat_vec |= pix
        dut.matIn.value = mat_vec
        await RisingEdge(dut.clk)

