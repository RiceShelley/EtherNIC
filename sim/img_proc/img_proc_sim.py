import cocotb
import struct
import string
import random
from random import randint
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

async def send_frame_row(dut, frame_row):
    assert len(frame_row) == 1280

    dut.cam_vsync.value = 0
    dut.cam_href.value = 0
    dut.cam_data_in.value = 0

    for _ in range(4):
        await RisingEdge(dut.cam_pix_valid)

    dut.cam_vsync.value = 0
    await RisingEdge(dut.cam_pix_valid)
    dut.cam_vsync.value = 0

    for b in frame_row:
        dut.cam_href.value = 1
        dut.cam_data_in.value = b
        await RisingEdge(dut.cam_pix_valid)

    dut.cam_href.value = 0
    await RisingEdge(dut.cam_pix_valid)
    await RisingEdge(dut.cam_pix_valid)


@cocotb.test()
async def udp_pkt_send_test(dut):
    clock = Clock(dut.sys_clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    phyClk = Clock(dut.rmii_50mhz_clk, 20, units="ns")
    cocotb.start_soon(phyClk.start())

    camClk = Clock(dut.cam_pix_valid, 100, units="ns")
    cocotb.start_soon(camClk.start())

    dut.rst.value = 0

    await RisingEdge(dut.sys_clk)

    rmiiSink = RMII_Sink(dut.rmii_50mhz_clk, dut.rmii_tx_data, dut.rmii_tx_en)
    await cocotb.start(rmiiSink.run())


    for _ in range(4):
        # send camera frame to device
        #frame_row = [randint(0, 250) for _ in range(1280)]
        frame_row = [(i % 255) for i in range(1280)]
        await send_frame_row(dut, frame_row)

        await RisingEdge(dut.sys_clk)
        await RisingEdge(dut.sys_clk)

        # Read packet from phy
        actual = (await rmiiSink.recv())
        actual_payload = actual[52:-4]
        for e, a in zip(frame_row, actual_payload):
            assert int(a) == e
