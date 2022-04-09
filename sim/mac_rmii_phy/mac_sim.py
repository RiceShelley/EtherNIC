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

# Test RX pipeline of MAC
@cocotb.test()
async def mac_standard_rx_test(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    await RisingEdge(dut.clk)
    dut.s_axi_aresetn.value = 0 
    dut.rst.value = 0
    await RisingEdge(dut.clk)
    dut.s_axi_aresetn.value = 1
    await RisingEdge(dut.clk)

    phyClk = Clock(dut.rmii_clk, 20, units="ns")
    cocotb.start_soon(phyClk.start())

    rmiiSource = RMII_Source(dut.rmii_clk, dut.rmii_rx_data, dut.rmii_crs_dv)

    axis_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "rx_m_axis"), dut.clk, dut.rst)
    config = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axi"), dut.clk, dut.rst)
    eth = eth_frame(b'\xDE\xAD\xBE\xEF\x00\x00', b'\xCA\xFE\xBA\xBE\x00\x00')

    # test mdio bus TODO: Expand on this
    mdio_phy_addr = 3
    mdio_reg_addr = 5
    mdio_data = 0xCAFE
    mdio_write = 1
    mdio_pkt = (mdio_write << 31) | (mdio_reg_addr << 23) | (mdio_phy_addr << 15) | mdio_data
    await config.write_dword(0x0000, mdio_pkt)
    await config.write_dword(0x0008, 1)
    # Poll until MDIO controller completes transaction
    while (await config.read_dword(0x000C)) != 0:
        await Timer(30, 'us')

    trials = 0
    for _ in range(0, trials):
        # Create random packet
        random_data = ''.join(random.choice(string.ascii_letters) for i in range(random.randrange(0, 1000)))
        frame = GmiiFrame.from_payload(eth.gen_pkt(random_data))
        # Send packet
        await rmiiSource.send(frame)
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

    phyClk = Clock(dut.rmii_clk, 20, units="ns")
    cocotb.start_soon(phyClk.start())

    dut.rst.value = 0

    axis_source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "tx_s_axis"), dut.clk, dut.rst)

    await RisingEdge(dut.clk)

    rmiiSink = RMII_Sink(dut.rmii_clk, dut.rmii_tx_data, dut.rmii_tx_en)
    await cocotb.start(rmiiSink.run())

    await RisingEdge(dut.clk)

    eth = eth_frame(b'\xDE\xAD\xBE\xEF\x00\x00', b'\xCA\xFE\xBA\xBE\x00\x00')

    trials = 5
    for _ in range(0, trials):
        # Create random packet
        random_data = ''.join(random.choice(string.ascii_letters) for i in range(random.randrange(0, 1000)))
        pkt = eth.gen_pkt(random_data)
        # Send packet data to MAC AXI Stream Interface
        await axis_source.send(pkt)
        # Read packet from phy
        actual = (await rmiiSink.recv())
        # Verify that what was read matches what was sent
        expected = GmiiFrame.from_payload(pkt).data
        assert actual == expected
