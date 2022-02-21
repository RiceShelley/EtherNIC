import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
import logging

CLOCK_PERIOD = 10
DEBUG_LEVEL = logging.INFO
MEM_SIZE = 32

async def read_fifo(dut, start, end, units="ns"):
    """ Read all entries from the FIFO """
    dut.rd_data._log.setLevel(DEBUG_LEVEL)
    dut.wr_en.value = 0
    dut.rd_en.value = 0
    full_mem_test = False
    cycles = (end - start) // CLOCK_PERIOD
    if cycles >= MEM_SIZE:
        dut.rd_data._log.debug("asserts will assume an full to empty fifo")
        full_mem_test = True

    await Timer(start, units=units)
    dut.rd_en.value = 1
    list_results = []
    for i in range(cycles):
        if full_mem_test:
            assert dut.empty.value == 0, "FIFO is empty early"
        list_results.append(int(dut.rd_data.value))
        dut.rd_data._log.debug("Loop read rd_data %s" % (dut.rd_data.value))
        await Timer(CLOCK_PERIOD, units=units)
        if full_mem_test:
            assert dut.full.value == 0, "FIFO didn't lose full status after read"
    dut.rd_en.value = 0
    dut.rd_data._log.debug("Results collected: %s" % (list_results))
    dut.rd_data._log.debug("Expecting %s" % set(range(0,MEM_SIZE,1)))
    if cycles >= MEM_SIZE:
        assert dut.full.value == 0, "FIFO is still full after being read for %d cycles" % (cycles)
        assert dut.empty.value == 1, "FIFO is not empty after being read for %d cycles" % (cycles)
    if cycles == MEM_SIZE:
        assert set(list_results) == set(range(0,MEM_SIZE,1)), "Data read does not match ones input"


async def fill_fifo(dut, start, end, units="ns"):
    """ Function to fill up the FIFO with 0 to 31 """
    dut.wr_data._log.setLevel(DEBUG_LEVEL)
    dut.wr_data.value = 0
    dut.wr_data._log.debug("Setting wr_data to %s" % (dut.wr_data.value))
    dut.wr_en.value = 0
    full_mem_test = False
    cycles = (end - start) // CLOCK_PERIOD
    if cycles >= MEM_SIZE:
        dut.wr_data._log.debug("asserts will assume an empty to full fifo")
        full_mem_test = True
    
    await Timer(start, units=units)
    if full_mem_test:
        assert dut.full.value == 0, "FIFO is already full. That will mess with the test"
        assert dut.empty.value == 1, "FIFO isn't empty. That will mess with the test"
    dut.wr_en.value = 1
    
    for i in range(cycles):
        if full_mem_test:
            assert dut.full.value == 0, "FIFO is full too early"
        await Timer(CLOCK_PERIOD, units=units)
        dut.wr_data._log.debug("Loop: setting wr_data to %s" % (dut.wr_data.value))
        dut.wr_data.value = dut.wr_data.value + 1
        #dut.wr_data.value += 1         # Very interesting bug - This sets MSB to 1 for some reason
        if full_mem_test:
            assert dut.empty.value == 0, "FIFO is empty while being filled."
    dut.wr_en.value = 0
    if cycles >= MEM_SIZE:
        assert dut.full.value == 1, "FIFO didn't fill up after %d cycles of %d %s" % (cycles, CLOCK_PERIOD, units)
        assert dut.empty.value == 0, "FIFO empty /= 0 despite being full"

async def reset_dut(dut, start, end, units="ns"):
    """ Function to reset the DUT"""
    dut.rst.value = 0
    await Timer(start, units=units)
    dut.rst.value = 1
    await Timer(end - start, units=units)
    dut.rst.value = 0
    assert dut.empty.value == 1, "FIFO empty /= 1 after reset"
    assert dut.full.value == 0, "FIFO full /= 0 after reset"
    assert dut.rd_data == 0, "FIFO rd_data /= 0 after reset"
    dut._log.debug("Reset Done")

@cocotb.test()
async def empty_full_empty(dut):
    """ This test fills up the FIFO and the empties it completely. """
    clock = Clock(dut.clk, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    cocotb.start_soon(fill_fifo(dut, 50, 50+(MEM_SIZE * CLOCK_PERIOD)))
    cocotb.start_soon(read_fifo(dut, 400, 400+(MEM_SIZE * CLOCK_PERIOD)))
    await reset_dut(dut, 20, 45)
    await Timer(1000, 'ns')
