import copy

import cocotb
import struct
from cocotb.triggers import Timer
from cocotbext.eth import GmiiFrame, MiiPhy
from cocotb.clock import Clock
from cocotbext.axi import (AxiStreamBus, AxiStreamSource)

import scapy.all

# MAC sim where a packet is sent through the MAC and the output from the MAC
# is then sent unaltered to a port on localhost via scapy.

BROADCAST_MAC = "ff:ff:ff:ff:ff:ff"
LOCAL_IP = "127.0.0.1"
SPORT = 20001
DPORT = 20000

def add_eth_preamble(pkt:bytearray):
    PREAMBLE = b"\x55\x55\x55\x55\x55\x55\x55\xd5"
    #FCS = b"\x00\x00\x00\x00"
    return bytearray(PREAMBLE + pkt)

def remove_eth_preamble_fcs(pkt:bytearray):
    pkt = bytes(pkt)
    new = pkt[8:]
    #new = new[:-4]
    return scapy.all.Ether(new)

@cocotb.test()
async def mac_with_pcap(dut):
    """ Test MAC sending packets from a pcap file. """
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

    #await Timer(10, 'us')
    mii_phy.set_speed(100e6)

    #pcap_file = "test.pcapng"
    #pcap_list = scapy.all.rdpcap(pcap_file)
    pcap_list = []
    e_layer = scapy.all.Ether(dst=BROADCAST_MAC)
    ip_layer = scapy.all.IP(src=LOCAL_IP, dst=LOCAL_IP)
    tcp_layer = scapy.all.TCP(sport=SPORT, dport=DPORT)
    pcap_list.append(e_layer / ip_layer / tcp_layer)

    dut._log.info("TCP:\n%r" % bytes(tcp_layer))

    MAX_NUM_PACKETS = 100
    expected = []
    for i, p in enumerate(pcap_list):
        # Send packet data to MAC AXI Stream Interface
        if len(p) > 1700:   # Skip huge packets - Takes too long to simulate.
            continue
        p_bytearray = bytearray(bytes(p))
        pkt = add_eth_preamble(p_bytearray)
        await axis_source.send(pkt)
        expected.append(GmiiFrame.from_payload(pkt).data)
        if i > MAX_NUM_PACKETS:
            break

    await axis_source.wait()

    # Verify results
    for e in expected:
        actual = (await mii_phy.tx.recv()).data
        #assert e == actual

    dut._log.info("From MAC: \n%r" % actual)
    s_ether = scapy.all.Ether(actual)
    dut._log.info("Received\n%r" % s_ether)
    new_s = remove_eth_preamble_fcs(actual)
    dut._log.info("Sending\n%r" % (new_s))

    try:
        scapy.all.sendp(new_s, iface="lo")
    except PermissionError:
        dut._log.warning("Scapy requires sudo to send packets.")
        dut._log.warning("Sample command for running make with sudo:\
            \nsudo -E env PATH=$PATH make\n")
        raise

