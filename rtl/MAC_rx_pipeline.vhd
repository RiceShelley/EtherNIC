library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.MAC_pack.all;
use work.eth_pack.all;

entity MAC_rx_pipeline is
    generic (
        AXIS_DATA_WIDTH     : natural := 8;
        AXIS_STRB_WIDTH     : natural := 1
    );
    port (
        clk                 : in std_logic;
        rst                 : in std_logic;
        rx_done_in          : in std_logic;
        phy_data_in         : inout t_SPH;
        -- Axi Data Stream
        m_axis_tdata        : out std_logic_vector(AXIS_DATA_WIDTH - 1 downto 0);
        m_axis_tstrb        : out std_logic_vector(AXIS_STRB_WIDTH - 1 downto 0);
        m_axis_tvalid       : out std_logic;
        m_axis_tready       : in std_logic;
        m_axis_tlast        : out std_logic
    );
end entity MAC_rx_pipeline;

architecture rtl of MAC_rx_pipeline is
    signal layer_two_eth : t_SPH;

    signal frame_length     : unsigned(LENGTH_WIDTH - 1 downto 0);
    signal frame_length_reg : unsigned(LENGTH_WIDTH - 1 downto 0);

    signal frame_start  : std_logic;
    signal frame_done   : std_logic;
    signal fcs_passed   : std_logic;
    signal fcs_failed   : std_logic;

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
        clk                 => clk,
        rx_done_in          => rx_done_in,
        din                 => phy_data_in,
        dout                => layer_two_eth,
        frame_start_out     => frame_start,
        frame_length_out    => frame_length,
        frame_done_out      => frame_done
    );

    ------------------------------------------------------------------
    -- Capture frame length from layer 1 eth decoder
    ------------------------------------------------------------------
    cap_frame_length_proc : process(clk) begin
        if rising_edge(clk) then
            if (frame_done = '1') then
                frame_length_reg <= frame_length;
            end if;
        end if;
    end process cap_frame_length_proc;

    ------------------------------------------------------------------
    -- Check CRC of eth2 frame
    ------------------------------------------------------------------
    fcs_check_inst : entity work.crc32_check(rtl)
    port map (
        clk                 => clk,
        frame_start_in      => frame_start,
        data_in             => layer_two_eth.data,
        data_valid_in       => layer_two_eth.en,
        frame_done_in       => frame_done,
        fcs_passed_out      => fcs_passed,
        fcs_failed_out      => fcs_failed
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
        clk         => clk,
        rst         => pkt_buffer_clr,
        wr_data     => layer_two_eth.data,
        wr_en       => layer_two_eth.en,
        full        => pkt_buffer_full,
        rd_data     => pkt_buffer_out.data,
        rd_en       => pkt_buffer_out.en,
        empty       => pkt_buffer_empty
    );

    ------------------------------------------------------------------
    -- Packet AXI data stream encoder
    ------------------------------------------------------------------
    axis_mtr_inst : entity work.MAC_rx_mtr_axis(rtl)
    generic map (
        DATA_WIDTH          => AXIS_DATA_WIDTH,
        STRB_WIDTH          => AXIS_STRB_WIDTH
    ) port map (
        clk                 => clk,
        trans_packet_in     => fcs_passed,
        pkt_length_in       => frame_length_reg,
        data_in             => pkt_buffer_out,
        m_axis_tdata        => m_axis_tdata,
        m_axis_tstrb        => m_axis_tstrb,
        m_axis_tvalid       => m_axis_tvalid,
        m_axis_tready       => m_axis_tready,
        m_axis_tlast        => m_axis_tlast
    );

end architecture rtl;