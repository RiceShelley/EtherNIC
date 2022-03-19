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

class RMII_Source:

    def __init__(self, clk, data, crs_dv):
        self.clk = clk
        self.data = data
        self.crs_dv = crs_dv

    async def send(self, udata : bytearray):
        print(udata)
        self.crs_dv.value = 1
        for b in udata:
            for _ in range(0, 4):
                self.data.value = b & 0x3
                b = b >> 2
                await RisingEdge(self.clk)
        self.crs_dv.value = 0

class RMII_Sink:

    def __init__(self, clk, data, tx_en):
        self.clk = clk
        self.data = data
        self.tx_en = tx_en
        self.pkts = []

    async def recv(self):
        print("ran")
        pkt = []
        lastEn = 0
        while True:
            await RisingEdge(self.clk)
            if self.tx_en.value == 1:
                lastEn = 1
                d = 0
                for i in range(0, 4):
                    d |= self.data.value << 6
                    if i < 3:
                        d = d >> 2
                        await RisingEdge(self.clk)
                pkt.append(d)
            elif lastEn == 1:
                lastEn = 0
                self.pkts.append(pkt)
                print("Got pkt: ", end='')
                for p in pkt:
                    print(hex(p), end=' ')
                print("")

                print(self.pkts)
                pkt = []

async def load_pkt(dut, pkt : bytearray):
    await RisingEdge(dut.sys_clk)
    for p in pkt:
        dut.s_axis_tdata.value = p
        dut.s_axis_tvalid.value = 1
        await RisingEdge(dut.sys_clk)
    dut.s_axis_tvalid.value = 0

# Test RX pipeline of RMII interface 
@cocotb.test()
async def rmii_standard_rx_test(dut):
    # init values
    dut.m_axis_tready.value = 1
    dut.sys_rst.value = 0
    dut.crs_dv.value = 0
    dut.rx_data.value = 0
    dut.s_axis_tvalid.value = 0

    # Start clocks
    clock = Clock(dut.sys_clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    phyClock = Clock(dut.ref_clk_50mhz, 20, units="ns")
    cocotb.start_soon(phyClock.start())

    rmiiSink = RMII_Sink(dut.ref_clk_50mhz, dut.tx_data, dut.tx_en)
    await cocotb.start(rmiiSink.recv())

    await RisingEdge(dut.sys_clk)
    await RisingEdge(dut.sys_clk)

    await load_pkt(dut, b'\xCA\xFE\xBA\xBE')

    rmiiSource = RMII_Source(dut.ref_clk_50mhz, dut.rx_data, dut.crs_dv) 
    await rmiiSource.send(b'\xCE\xFE\xBA\xBE')

    for i in range(0, 10):
        await RisingEdge(dut.ref_clk_50mhz)
    await Timer(100, 'ns')
