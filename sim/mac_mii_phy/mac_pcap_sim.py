import cocotb
import struct
from cocotb.triggers import Timer
from cocotbext.eth import GmiiFrame, MiiPhy
from cocotb.clock import Clock
from cocotbext.axi import (AxiStreamBus, AxiStreamSource)

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

def add_eth_preamble_fcs(pkt:bytearray):
    PREAMBLE = b"\x55\x55\x55\x55\x55\x55\x55\xd5"
    FCS = b"\x00\x00\x00\x00"
    return bytearray(PREAMBLE + pkt + FCS)

@cocotb.test()
async def mac_with_pcap(dut):
    """ Test MAC sending packets from a pcap file. """
    try:
        import scapy.all
    except ModuleNotFoundError:
        dut._log.warning("Skipping test - scapy module not found.")
        return 0

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

    pcap_file = "test.pcapng"
    pcap_list = scapy.all.rdpcap(pcap_file)

    MAX_NUM_PACKETS = 100
    expected = []
    for i, p in enumerate(pcap_list):
        # Send packet data to MAC AXI Stream Interface
        if len(p) > 1700:   # Skip huge packets - Takes too long to simulate.
            continue
        p_bytes = bytearray(bytes(p))
        pkt = add_eth_preamble_fcs(p_bytes)
        await axis_source.send(pkt)
        expected.append(GmiiFrame.from_payload(pkt).data)
        if i > MAX_NUM_PACKETS:
            break

    await axis_source.wait()

    # Verify results
    for e in expected:
        actual = (await mii_phy.tx.recv()).data
        assert e == actual
