library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.MAC_pack.all;
use work.eth_pack.all;

entity MAC_rx_pipeline is
    port (
        clk : in std_logic;
        rst : in std_logic;
        phy_data_in : inout t_SPH
    );
end entity MAC_rx_pipeline;

architecture rtl of MAC_rx_pipeline is
    signal layer_two_eth : t_SPH;

    signal frame_start : std_logic;
    signal fcs_valid : std_logic;
    signal fcs_passed : std_logic;
    signal fcs_failed : std_logic;

    signal pkt_buffer_full  : std_logic;
    signal pkt_buffer_empty : std_logic;
    signal pkt_buffer_clr   : std_logic;
    signal pkt_buffer_out   : t_SPH := (
        data => (others => '0'),
        consent => '0',
        en => '0'
    );

begin

    ------------------------------------------------------------------
    -- Decode layer 1 eth frame to layer 2 eth frame
    ------------------------------------------------------------------
    l1_decoder_inst : entity work.l1_eth_frame_decoder(rtl)
    port map (
        clk             => clk,
        rst             => rst,
        din             => phy_data_in,
        dout            => layer_two_eth,
        frame_start_out => frame_start,
        fcs_valid_out   => fcs_valid
    );

    ------------------------------------------------------------------
    -- Check CRC of eth2 frame
    ------------------------------------------------------------------
    fcs_check_inst : entity work.crc32_check(rtl)
    port map (
        clk             => clk,
        frame_start_in  => frame_start,
        data_in         => layer_two_eth.data,
        data_valid_in   => layer_two_eth.en,
        fcs_valid_in    => fcs_valid,
        fcs_passed_out  => fcs_passed,
        fcs_failed_out  => fcs_failed
    );

    ------------------------------------------------------------------
    -- Layer 2 eth buffer
    ------------------------------------------------------------------
    pkt_buffer_clr          <= rst or fcs_failed;
    pkt_buffer_out.consent  <= not pkt_buffer_empty;
    pkt_buffer_inst : entity work.sync_fifo(rtl)
    generic map (
        DATA_WIDTH  => 8,
        DEPTH       => MAX_ETH_FRAME_SIZE)
    port map (
        clk     => clk,
        rst     => pkt_buffer_clr,
        wr_data => layer_two_eth.data,
        wr_en   => layer_two_eth.en,
        full    => pkt_buffer_full,
        rd_data => pkt_buffer_out.data,
        rd_en   => pkt_buffer_out.en,
        empty   => pkt_buffer_empty
    );


end architecture rtl;