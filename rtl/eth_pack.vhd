library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package eth_pack is

    ---------------------------------
    -- Ethernet frame constants
    ---------------------------------
    constant MAX_ETH_FRAME_SIZE : natural := 1530;

    -- Size in bytes of eth frame feilds 
    constant PREAMBLE_SIZE      : natural := 7;
    constant SFD_SIZE           : natural := 1;
    constant MAC_DST_SIZE       : natural := 6;
    constant MAC_SRC_SIZE       : natural := 6;
    constant TAG_SIZE           : natural := 4;
    constant LENGTH_SIZE        : natural := 2;
    constant FCS_SIZE           : natural := 4;
    constant INTER_PKT_GAP_SIZE : natural := 12;

    -- Offsets in bytes of eth frame feilds
    constant PREAMBLE_OFFSET        : natural := 0;
    constant SFD_OFFSET             : natural := PREAMBLE_OFFSET + PREAMBLE_SIZE;
    constant MAC_DST_OFFSET         : natural := SFD_OFFSET + SFD_SIZE;
    constant MAC_SRC_OFFSET         : natural := MAC_DST_OFFSET + MAC_DST_SIZE;
    constant TAG_OFFSET             : natural := MAC_SRC_OFFSET + MAC_SRC_SIZE;
    constant LENGTH_OFFSET          : natural := TAG_OFFSET + TAG_SIZE;
    constant FCS_OFFSET             : natural := LENGTH_OFFSET + LENGTH_SIZE;
    constant INTER_PKT_GAME_OFFSET  : natural := FCS_OFFSET + FCS_SIZE; 

    -- Bit width of eth frame feilds 
    constant PREAMBLE_WIDTH         : natural := PREAMBLE_SIZE * 8;
    constant SFD_WIDTH              : natural := SFD_SIZE * 8;
    constant MAC_DST_WIDTH          : natural := MAC_DST_SIZE * 8;
    constant MAC_SRC_WIDTH          : natural := MAC_SRC_SIZE * 8;
    constant TAG_WIDTH              : natural := TAG_SIZE * 8;
    constant LENGTH_WIDTH           : natural := LENGTH_SIZE * 8;
    constant FCS_WIDTH              : natural := FCS_SIZE * 8;
    constant INTER_PKT_GAP_WIDTH    : natural := INTER_PKT_GAP_SIZE * 8;

    -- Misc
    constant START_SEQ_SIZE     : natural := PREAMBLE_SIZE + SFD_SIZE;
    constant START_SEQ_WIDTH    : natural := START_SEQ_SIZE * 8;
    constant START_SEQ          : std_logic_vector(START_SEQ_WIDTH - 1 downto 0) := X"55555555555555D5";

    constant MIN_FRAME_SIZE : natural := 42;

    constant CRC32_POLY : std_logic_vector(31 downto 0) := X"04c11db7";

end package eth_pack;

package body eth_pack is

end package body eth_pack;