import cocotb
from cocotb.triggers import Timer
from cocotbext.eth import MiiSource, MiiSink
from cocotbext.eth import GmiiFrame, MiiPhy
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

pkt = []

def decode_pkt():
    print("\n\n")
    mac_dst_offset = 8
    mac_dst = []
    for i in range(mac_dst_offset, mac_dst_offset + 6):
        mac_dst.append(hex(pkt[i]))
    print(mac_dst)

    mac_src_offset = mac_dst_offset + 6
    mac_src = []
    for i in range(mac_src_offset, mac_src_offset + 6):
        mac_src.append(hex(pkt[i]))
    print(mac_src)

    length_offset = mac_src_offset + 6 + 4
    length = []
    for i in range(length_offset, length_offset + 2):
        length.append(hex(pkt[i]))
    print(length)

async def read_fifo_data(dut):
    while True:
        await RisingEdge(dut.sys_clk)
        dut.dout_en.value = 0
        if dut.dout_cn.value == 1:
            if dut.dout_en.value == 1:
                try:
                    print(hex(dut.dout_data.value.integer), end=' ')
                    pkt.append(dut.dout_data.value.integer)
                except:
                    print(dut.dout_data.value)
            dut.dout_en.value = 1

async def write_tx_fifo_data(dut):
    send_pkt = b'\xCA\xFE\xBA\xBE'
    dut.din_en.value = 1
    for b in send_pkt:
        await RisingEdge(dut.clk)
        dut.din_data.value = b
    await RisingEdge(dut.clk)
    dut.din_en.value = 0

@cocotb.test()
async def eth_sim(dut):

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

    #cocotb.start_soon(read_fifo_data(dut))
    #cocotb.start_soon(write_tx_fifo_data(dut))
    bstr = b'\xCA\xFE\xBA\xBE\xBE\xEF\xDE\xAD\xBA\xBE\xBE\xEF\x00\x00\x00\xFF\x00\x46'
    for i in range(70):
        bstr = bstr + i.to_bytes(1, byteorder='big')
    await mii_phy.rx.send(GmiiFrame.from_payload(bstr))
    #x_data = await mii_phy.tx.recv()
    await Timer(10, 'us')
    #decode_pkt()