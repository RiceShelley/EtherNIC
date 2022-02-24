import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
import logging

WRITE_CLOCK_PERIOD = 10
READ_CLOCK_PERIOD = 7
DEBUG_LEVEL = logging.INFO
MEM_SIZE = 32

# Notes:
# Pessimistic full causes full to update immediately when filling but takes 2 read cycles to unset when reading
# Pessimistic empty causes empty to update immediately when reading but takes 2 write cycles to unset when writing

def round_up(x:int, up_to:int):
    """ Round up to the nearest specified value"""
    return x if x % up_to == 0 else x + up_to - x % up_to

async def read_fifo(dut, start, end, expected=None, units="ns"):
    """ Read all entries from the FIFO """
    global DEBUG_LEVEL
    global MEM_SIZE
    global READ_CLOCK_PERIOD
    global WRITE_CLOCK_PERIOD
    dut.rd_data._log.setLevel(DEBUG_LEVEL)
    dut.rd_en.value = 0
    full_mem_test = False
    cycles = (end - start) // READ_CLOCK_PERIOD
    local_expected = expected
    if cycles == MEM_SIZE and dut.full.value == 1:
        dut.rd_data._log.debug("asserts will assume an full to empty fifo")
        full_mem_test = True
        if local_expected is None:
            local_expected = list(range(0,MEM_SIZE,1))

    await Timer(start, units=units)
    dut.rd_en.value = 1
    list_results = []
    time_passed = 0
    for i in range(cycles):
        if full_mem_test:
            assert dut.empty.value == 0, "FIFO is empty early"
        dut.rd_data._log.debug("Loop read rd_data %s, empty=%s" % (dut.rd_data.value, dut.empty.value))
        if dut.empty.value == 0:
            list_results.append(int(dut.rd_data.value))
        await Timer(READ_CLOCK_PERIOD, units=units)
        time_passed += READ_CLOCK_PERIOD
        if time_passed >= (2 * (max(WRITE_CLOCK_PERIOD, READ_CLOCK_PERIOD) + WRITE_CLOCK_PERIOD)):     # pessimistic full
            assert dut.full.value == 0, "FIFO didn't lose full status after read"
    dut.rd_en.value = 0
    dut.rd_data._log.debug("Results collected: %s" % (list_results))
    dut.rd_data._log.debug("Expecting %s" % (local_expected))
    if cycles >= MEM_SIZE:
        if time_passed >= (2 * (max(WRITE_CLOCK_PERIOD, READ_CLOCK_PERIOD) + WRITE_CLOCK_PERIOD)):     # pessimistic full
            assert dut.full.value == 0, "FIFO is still full after being read for %d cycles" % (cycles)
        assert dut.empty.value == 1, "FIFO is not empty after being read for %d cycles" % (cycles)
    if cycles == MEM_SIZE or expected is not None:
        assert list_results == local_expected, "Data read does not match ones input"
    return list_results

async def fill_fifo(dut, start, end, wr_start=0, action=lambda x: x + 1, units="ns"):
    """ Function to fill up the FIFO """
    global DEBUG_LEVEL
    global MEM_SIZE
    global READ_CLOCK_PERIOD
    global WRITE_CLOCK_PERIOD
    dut.wr_data._log.setLevel(DEBUG_LEVEL)
    dut.wr_en.value = 0
    full_mem_test = False
    cycles = (end - start) // WRITE_CLOCK_PERIOD
    if cycles == MEM_SIZE and dut.empty.value == 1:
        dut.wr_data._log.debug("asserts will assume an empty to full fifo")
        full_mem_test = True

    await Timer(start, units=units)
    dut.wr_data.value = wr_start
    dut.wr_data._log.debug("Setting wr_data to %s" % (dut.wr_data.value))
    if full_mem_test:
        assert dut.full.value == 0, "FIFO is already full. That will mess with the test"
        assert dut.empty.value == 1, "FIFO isn't empty. That will mess with the test"
    dut.wr_en.value = 1
    time_passed = 0
    for i in range(cycles):
        if full_mem_test:
            assert dut.full.value == 0, "FIFO is full too early"
        #dut.wr_data.value += 1         # cocotb bug - This sets MSB to 1 for some reason
        await Timer(WRITE_CLOCK_PERIOD, units=units)
        time_passed += WRITE_CLOCK_PERIOD
        dut.wr_data._log.debug("Loop: setting wr_data to %s, full=%s" % (dut.wr_data.value, dut.full.value))
        dut.wr_data.value = action(dut.wr_data.value)
        if time_passed >= (2 * (max(READ_CLOCK_PERIOD, WRITE_CLOCK_PERIOD) + READ_CLOCK_PERIOD)):
            assert dut.empty.value == 0, "FIFO is empty while being filled."
    dut.wr_en.value = 0
    if cycles >= MEM_SIZE:
        assert dut.full.value == 1, "FIFO didn't fill up after %d cycles of %d %s" % (cycles, WRITE_CLOCK_PERIOD, units)
        if time_passed >= (2 * (max(READ_CLOCK_PERIOD, WRITE_CLOCK_PERIOD) + READ_CLOCK_PERIOD)):
            assert dut.empty.value == 0, "FIFO empty /= 0 despite being full"

async def big_test(dut):
    """ Really big test.
    
        1. Fills completely,
        2. Empties partially,
        3. Fills more than available,
        4. Reads the values from the first fill
        5. Reads the values from the second fill
    """
    global READ_CLOCK_PERIOD
    global WRITE_CLOCK_PERIOD
    global MEM_SIZE
    wr_clock = Clock(dut.wr_clk, WRITE_CLOCK_PERIOD, units="ns")
    rd_clock = Clock(dut.rd_clk, READ_CLOCK_PERIOD, units="ns")
    cocotb.start_soon(wr_clock.start())
    cocotb.start_soon(rd_clock.start())
    num_writes = MEM_SIZE
    fill_start = 50
    fill_end = fill_start + (num_writes * WRITE_CLOCK_PERIOD)
    num_reads = 10
    read_start = round_up(fill_end + (2*READ_CLOCK_PERIOD), 100)    # + 2*READ_CLOCKS to make sure empty is updated
    read_end = read_start + (num_reads * READ_CLOCK_PERIOD)
    num_writes2 = num_reads + 10
    fill2_start = round_up(read_end + (2*WRITE_CLOCK_PERIOD), 100)  # + 2*WRITE_CLOCKS to make sure full is updated
    fill2_end = fill2_start + (num_writes2 * WRITE_CLOCK_PERIOD)
    num_reads2 = num_writes - num_reads     # Read rest from the original fill
    read2_start = round_up(fill2_end + (2*READ_CLOCK_PERIOD), 100)
    read2_end = read2_start + (num_reads2 * READ_CLOCK_PERIOD)
    num_reads3 = num_reads
    read3_start = round_up(read2_end, 100)  # Shouldn't need longer wait. Previous read should handle pessimistic empty
    read3_end = read3_start + (num_reads3 * READ_CLOCK_PERIOD)
    dut._log.info("FIFO fill %d to %d" % (fill_start, fill_end))
    dut._log.info("FIFO read %d to %d" % (read_start, read_end))
    dut._log.info("FIFO fill2 %d to %d" % (fill2_start, fill2_end))
    dut._log.info("FIFO read2 %d to %d" % (read2_start, read2_end))
    dut._log.info("FIFO read3 %d to %d" % (read3_start, read3_end))
    write_start = 0xff
    write2_start = 0xa0
    expected_vals = list(range(write_start, write_start - min(num_reads, num_writes), -1))
    expected_vals2 = list(range(write_start - num_reads, write_start - num_writes, -1))
    expected_vals3 = list(range(write2_start, write2_start + num_reads, 1))
    cocotb.start_soon(fill_fifo(dut, fill_start, fill_end, wr_start=write_start, action=lambda x: x-1))
    cocotb.start_soon(read_fifo(dut, read_start, read_end, expected=expected_vals))
    cocotb.start_soon(fill_fifo(dut, fill2_start, fill2_end, wr_start=write2_start, action=lambda x: x+1))
    cocotb.start_soon(read_fifo(dut, read2_start, read2_end, expected=expected_vals2))
    await cocotb.start_soon(read_fifo(dut, read3_start, read3_end, expected=expected_vals3))

@cocotb.test()
async def empty_full_empty(dut):
    """ This test fills up the FIFO fully and the empties it completely. """
    global READ_CLOCK_PERIOD
    global WRITE_CLOCK_PERIOD
    global MEM_SIZE
    wr_clock = Clock(dut.wr_clk, WRITE_CLOCK_PERIOD, units="ns")
    rd_clock = Clock(dut.rd_clk, READ_CLOCK_PERIOD, units="ns")
    cocotb.start_soon(wr_clock.start())
    cocotb.start_soon(rd_clock.start())
    fill_start = 50
    fill_end = fill_start + (MEM_SIZE * WRITE_CLOCK_PERIOD)
    read_start = round_up(fill_end, 100) + 100
    read_end = read_start + (MEM_SIZE * READ_CLOCK_PERIOD)
    dut._log.info("FIFO fill %d to %d" % (fill_start, fill_end))
    dut._log.info("FIFO read %d to %d" % (read_start, read_end))
    cocotb.start_soon(fill_fifo(dut, fill_start, fill_end))
    cocotb.start_soon(read_fifo(dut, read_start, read_end, expected=list(range(0,MEM_SIZE,1))))
    test_end = round_up(read_end, 100) + 100
    await Timer(test_end, 'ns')

# Note: Values persist between tests. This is even more relevant without mem reset

@cocotb.test()
async def empty_partial_fill_empty(dut):
    """ This test fills up the FIFO partially and the empties it completely. """
    global READ_CLOCK_PERIOD
    global WRITE_CLOCK_PERIOD
    wr_clock = Clock(dut.wr_clk, WRITE_CLOCK_PERIOD, units="ns")
    rd_clock = Clock(dut.rd_clk, READ_CLOCK_PERIOD, units="ns")
    cocotb.start_soon(wr_clock.start())
    cocotb.start_soon(rd_clock.start())
    num_writes = 5
    fill_start = 50
    fill_end = fill_start + (num_writes * WRITE_CLOCK_PERIOD)
    num_reads = 10
    read_start = round_up(fill_end, 100) + 100
    read_end = read_start + (num_reads * READ_CLOCK_PERIOD)
    dut._log.info("FIFO fill %d to %d" % (fill_start, fill_end))
    dut._log.info("FIFO read %d to %d" % (read_start, read_end))
    write_start = 0xff
    expected_vals = list(range(write_start, write_start - min(num_reads, num_writes), -1))
    cocotb.start_soon(fill_fifo(dut, fill_start, fill_end, wr_start=write_start, action=lambda x: x-1))
    await cocotb.start_soon(read_fifo(dut, read_start, read_end, expected=expected_vals))   # No expected. Assert outside.

@cocotb.test()
async def emtpy_full_partial_empty_full(dut):
    """ Runs the big test with the default clock speeds """
    await big_test(dut)

# So far, biggest issue I've seen with the different clock speeds are due to
# simulation mistakes not accounting for pessimistic read/write

@cocotb.test()
async def fast_read_slow_write(dut):
    global READ_CLOCK_PERIOD
    global WRITE_CLOCK_PERIOD
    READ_CLOCK_PERIOD = 3       # Random hand-picked value
    WRITE_CLOCK_PERIOD = 262    # Random hand-picked value
    await big_test(dut)

@cocotb.test()
async def slow_read_fast_write(dut):
    global READ_CLOCK_PERIOD
    global WRITE_CLOCK_PERIOD
    READ_CLOCK_PERIOD = 341
    WRITE_CLOCK_PERIOD = 4
    await big_test(dut)

@cocotb.test()
async def same_clocks(dut):
    global READ_CLOCK_PERIOD
    global WRITE_CLOCK_PERIOD
    READ_CLOCK_PERIOD = 10
    WRITE_CLOCK_PERIOD = 10
    await big_test(dut)