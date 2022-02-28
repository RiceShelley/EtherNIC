library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.MAC_pack.all;
use work.eth_pack.all;

entity MAC_rx_pipeline is
    port (
        clk                 : in std_logic;
        rst                 : in std_logic;
        rx_done_in          : in std_logic;
        -- AXI Stream Slave
        s_axis_tdata        : in std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
        s_axis_tvalid       : in std_logic;
        s_axis_tready       : out std_logic;
        -- Axi Stream Master
        m_axis_tdata        : out std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
        m_axis_tstrb        : out std_logic_vector(MAC_AXIS_STRB_WIDTH - 1 downto 0);
        m_axis_tvalid       : out std_logic;
        m_axis_tready       : in std_logic;
        m_axis_tlast        : out std_logic
    );
end entity MAC_rx_pipeline;

architecture rtl of MAC_rx_pipeline is
    signal layer_two_eth_tdata  : std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
    signal layer_two_eth_tvalid : std_logic;
    signal layer_two_eth_tready : std_logic;

    signal frame_length     : unsigned(LENGTH_WIDTH - 1 downto 0);
    signal frame_length_reg : unsigned(LENGTH_WIDTH - 1 downto 0);

    signal frame_start  : std_logic;
    signal frame_done   : std_logic;
    signal fcs_passed   : std_logic;
    signal fcs_failed   : std_logic;

    signal pkt_buffer_full  : std_logic;
    signal pkt_buffer_empty : std_logic;
    signal pkt_buffer_clr   : std_logic;

    signal pkt_buffer_axis_tdata    : std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
    signal pkt_buffer_axis_tvalid   : std_logic;
    signal pkt_buffer_axis_tready   : std_logic;

begin

    ------------------------------------------------------------------
    -- Decode layer 1 eth frame to layer 2 eth frame
    ------------------------------------------------------------------
    l1_decoder_inst : entity work.l1_eth_frame_decoder(rtl)
    port map (
        clk                 => clk,
        rx_done_in          => rx_done_in,
        frame_start_out     => frame_start,
        frame_length_out    => frame_length,
        frame_done_out      => frame_done,
        -- AXI Stream Slave
        s_axis_tdata        => s_axis_tdata,
        s_axis_tvalid       => s_axis_tvalid,
        s_axis_tready       => s_axis_tready,
        -- AXI Stream Master
        m_axis_tdata        => layer_two_eth_tdata,
        m_axis_tvalid       => layer_two_eth_tvalid,
        m_axis_tready       => layer_two_eth_tready
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
        data_in             => layer_two_eth_tdata,
        data_valid_in       => layer_two_eth_tvalid,
        frame_done_in       => frame_done,
        fcs_passed_out      => fcs_passed,
        fcs_failed_out      => fcs_failed
    );

    ------------------------------------------------------------------
    -- Layer 2 eth buffer
    ------------------------------------------------------------------
    pkt_buffer_clr          <= rst or fcs_failed;
    pkt_buffer_axis_tvalid  <= not pkt_buffer_empty;
    pkt_buffer_inst : entity work.sync_fifo(rtl)
    generic map (
        DATA_WIDTH  => 8,
        DEPTH       => MAX_ETH_FRAME_SIZE)
    port map (
        clk         => clk,
        rst         => pkt_buffer_clr,
        wr_data     => layer_two_eth_tdata,
        wr_en       => layer_two_eth_tvalid,
        full        => pkt_buffer_full,
        rd_data     => pkt_buffer_axis_tdata,
        rd_en       => pkt_buffer_axis_tready,
        empty       => pkt_buffer_empty
    );

    ------------------------------------------------------------------
    -- Packet AXI data stream encoder
    ------------------------------------------------------------------
    axis_mtr_inst : entity work.MAC_rx_mtr_axis(rtl)
    port map (
        clk                 => clk,
        trans_packet_in     => fcs_passed,
        pkt_length_in       => frame_length_reg,
        -- AXI Stream Slave
        s_axis_tdata        => pkt_buffer_axis_tdata,
        s_axis_tvalid       => pkt_buffer_axis_tvalid,
        s_axis_tready       => pkt_buffer_axis_tready,
        -- AXI Stream Master
        m_axis_tdata        => m_axis_tdata,
        m_axis_tstrb        => m_axis_tstrb,
        m_axis_tvalid       => m_axis_tvalid,
        m_axis_tready       => m_axis_tready,
        m_axis_tlast        => m_axis_tlast
    );

end architecture rtl;