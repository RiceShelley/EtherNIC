import cocotb
import struct
import string
import random
from cocotb.triggers import Timer
from cocotbext.eth import GmiiFrame, MiiPhy
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import (AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor, AxiLiteMaster, AxiLiteBus)

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

    async def run(self):
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
                self.pkts.append(bytearray(pkt))
                print("Got pkt: " + str(bytearray(pkt)))
                pkt = []

    async def recv(self):
        while len(self.pkts) == 0:
            await RisingEdge(self.clk)
        return bytearray(self.pkts.pop(0))


class eth_frame:
    def __init__(self, src_mac : bytearray, dst_mac : bytearray):
        self.src_mac = src_mac
        self.dst_mac = dst_mac

    def gen_pkt(self, payload : bytearray):
        if len(payload) < 46:
            for i in range(0, 46 - len(payload)):
                payload += bytes([0]).decode()
        pkt = []
        for b in self.dst_mac:
            pkt.append(b)
        for b in self.src_mac:
            pkt.append(b)
        for b in struct.pack('>H', len(payload)):
            pkt.append(b)
        for b in payload.encode():
            pkt.append(b)
        return bytearray(pkt)

@cocotb.test()
async def udp_pkt_send_test(dut):
    clock = Clock(dut.sys_clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    phyClk = Clock(dut.rmii_50mhz_clk, 20, units="ns")
    cocotb.start_soon(phyClk.start())

    dut.rst.value = 0

    await RisingEdge(dut.sys_clk)

    rmiiSink = RMII_Sink(dut.rmii_50mhz_clk, dut.rmii_tx_data, dut.rmii_tx_en)
    await cocotb.start(rmiiSink.run())

    await RisingEdge(dut.sys_clk)
    await RisingEdge(dut.sys_clk)



    for _ in range(4):
        # Read packet from phy
        actual = (await rmiiSink.recv())
        for p in actual:
            print(hex(p), end=' ')
        print("")
