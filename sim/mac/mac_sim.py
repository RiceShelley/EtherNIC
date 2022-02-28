import cocotb
import struct
import string
import random
from cocotb.triggers import Timer
from cocotbext.eth import MiiSource, MiiSink
from cocotbext.eth import GmiiFrame, MiiPhy
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import (AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor)

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

# Test RX pipeline of MAC
@cocotb.test()
async def mac_standard_rx_test(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst.value = 0

    mii_phy = MiiPhy(
        dut.mii_tx_data, 
        dut.mii_tx_er, 
        dut.mii_tx_en, 
        dut.mii_tx_clk,
        dut.mii_rx_data, 
        dut.mii_rx_er, 
        dut.mii_rx_en, 
        dut.mii_rx_clk, 
        dut.mii_rst_phy, 
        speed=10e6
    )
    mii_phy.set_speed(100e6)
    axis_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "rx_m_axis"), dut.clk, dut.rst)
    eth = eth_frame(b'\xDE\xAD\xBE\xEF\x00\x00', b'\xCA\xFE\xBA\xBE\x00\x00')

    trials = 3

    for _ in range(0, trials):
        # Create random packet
        random_data = ''.join(random.choice(string.ascii_letters) for i in range(random.randrange(0, 1000)))
        frame = GmiiFrame.from_payload(eth.gen_pkt(random_data))
        # Send packet
        await mii_phy.rx.send(frame)
        # Read packet out of AXI data stream 
        actual = (await axis_sink.recv()).tdata
        # Verify that what was read matches what was sent
        expected = frame.data[8:]
        assert actual == expected

# Test TX pipeline of MAC
@cocotb.test()
async def mac_standard_tx_test(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst.value = 0

    mii_phy = MiiPhy(
        dut.mii_tx_data, 
        dut.mii_tx_er, 
        dut.mii_tx_en, 
        dut.mii_tx_clk,
        dut.mii_rx_data, 
        dut.mii_rx_er, 
        dut.mii_rx_en, 
        dut.mii_rx_clk, 
        dut.mii_rst_phy, 
        speed=10e6
    )
    axis_source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "tx_s_axis"), dut.clk, dut.rst)

    await Timer(10, 'us')
    mii_phy.set_speed(100e6)
    eth = eth_frame(b'\xDE\xAD\xBE\xEF\x00\x00', b'\xCA\xFE\xBA\xBE\x00\x00')

    trials = 3
    for _ in range(0, trials):
        # Create random packet
        random_data = ''.join(random.choice(string.ascii_letters) for i in range(random.randrange(0, 1000)))
        pkt = eth.gen_pkt(random_data)
        # Send packet data to MAC AXI Stream Interface
        await axis_source.send(pkt)
        # Read packet from phy
        actual = (await mii_phy.tx.recv()).data
        # Verify that what was read matches what was sent
        expected = GmiiFrame.from_payload(pkt).data
        assert actual == expected
