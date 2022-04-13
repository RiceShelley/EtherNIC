#
"""
    Python code to simulate OV7670 camera.
"""
import logging

#from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge

#import cocotbext.eth.mii

logger = logging.getLogger("cam")

# For raw data, TP = Tpclk
# For YUV/RGB, TP = 2Tpclk

# 784 Tp for 1 row (Tline = 784)
# 480 Rows with data are sent.
HREF_TOTAL_TLINE = 480

HREF_ON_TP = 640            # 640 Tp with Href 1
HREF_DOWNTIME_TP = 144      # 144 Tp with Href 0
HREF_ROW_PERIOD_TP = 784    # 784 Tp for 1 row + invalid data.
TP_PER_TLINE = HREF_ROW_PERIOD_TP   # 784 Tp per Tline

VSYNC_HOLD_TLINE = 3                # 3 Tline high Vsync (start?)
VSYNC_BEFORE_HREF_TLINE = 17        # 17 Tline low after first Vsync high
VSYNC_LOW_AFTER_ROWS_TLINE = 10     # 10 Tline low after last Href high
VSYNC_PERIOD_TLINE = 510            # 510 Tline before Vsync high again.

VSYNC_HOLD_TP = VSYNC_HOLD_TLINE * TP_PER_TLINE
VSYNC_BEFORE_HREF_TP = VSYNC_BEFORE_HREF_TLINE * TP_PER_TLINE
VSYNC_PERIOD_TP = VSYNC_PERIOD_TLINE * TP_PER_TLINE

LAST_HREF_HIGH_TLINE = 500          # 500 Tline before Href is never high again
LAST_HREF_HIGH_TP = LAST_HREF_HIGH_TLINE * TP_PER_TLINE

MAX_DATA = HREF_ON_TP * HREF_TOTAL_TLINE

class OV7670:
    def __init__(self, pclk, href, vsync):
        #self.xclk = xclk
        self.pclk = pclk    # Should probably be created inside this. Oh well.
        self.href = href
        self.vsync = vsync

    async def send(self, data:bytes, runs=1):
        """ Send the data according to how the 0v7670 would send it. """
        #print(data)
        row_count = 0
        data_index = 0
        send_data = False
        out_of_data = False
        for r in range(runs):
            for ct in range(VSYNC_PERIOD_TP):
                await FallingEdge(self.pclk)    # Href updates on falling edge of pclk it seems.
                
                if ct < VSYNC_HOLD_TP:
                    self.vsync.value = 1
                else:
                    self.vsync.value = 0
                
                if ct >= VSYNC_BEFORE_HREF_TP and ct < LAST_HREF_HIGH_TP:
                    if (ct - VSYNC_BEFORE_HREF_TP) % HREF_ROW_PERIOD_TP < HREF_ON_TP:
                        self.href.value = 1
                        send_data = True
                    else:
                        self.href.value = 0
                        send_data = False
                else:
                    self.href.value = 0
                    send_data = False
                
                if send_data:
                    try:
                        self.data.value = data[data_index]
                        data_index += 1
                    except IndexError:
                        if not out_of_data:
                            logger.warning("Ran out of fake data.")
                            out_of_data = True
                        self.data.value = b"\0" # Ran out of data.
                else:
                    self.data.value = b"\0"     # Invalid data.

class DummyCocotb:
    """ Idea: Dummy cocotb object with the .value attribute. """
    def __init__(self):
        self.value = 0

def main():
    logger.warning("Running main.")

    raise NotImplementedError("TODO: Add non-cocotb based test of this.")

if __name__ == "__main__":
    logging.basicConfig(format="%(levelname)s:%(message)s")
    main()
