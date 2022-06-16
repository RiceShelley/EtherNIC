library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library comp;
use comp.math_pack.all;

library mac;
use mac.MAC_pack.all;
use mac.eth_pack.all;


entity RMII_Phy_Interface is
    port (
        ----------------------------------
        -- Signals in system clock domain
        ----------------------------------
        sys_clk         : in std_logic := '0';
        sys_rst         : in std_logic := '0';
        tx_busy         : out std_logic := '0';
        rx_done         : out std_logic := '0';
        -- Tx Data in
        s_axis_tdata    : in std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
        s_axis_tvalid   : in std_logic;
        s_axis_tready   : out std_logic;
        -- Rx Data Out
        m_axis_tdata    : out std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
        m_axis_tvalid   : out std_logic;
        m_axis_tready   : in std_logic;
        ----------------------------------
        -- Signals in RMII clock domain
        ----------------------------------
        ref_clk_50mhz   : in std_logic;
        -- TX signals
        tx_en           : out std_logic := '0';
        tx_data         : out std_logic_vector(1 downto 0);
        -- RX signals
        rx_data         : in std_logic_vector(1 downto 0);
        crs_dv          : in std_logic;
        rx_er           : in std_logic
    );
end entity RMII_Phy_Interface;

architecture rtl of RMII_Phy_Interface is

    constant INTER_PKT_GAP_CYCLES   : natural := INTER_PKT_GAP_SIZE * 4;
    constant TIMEOUT_MAX            : natural := 8;
    constant DIBIT_COUNT            : natural := 4;

    -- RX recv process signals
    type rx_fsm_t is (IDLE, BUSY);
    signal rx_fsm           : rx_fsm_t := IDLE;
    signal rx_dibit_cnt     : unsigned(clog2(DIBIT_COUNT) - 1 downto 0) := (others => '0');
    signal rx_byte          : std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal fifo_wr_rx       : std_logic := '0';
    signal wr_rx_byte       : std_logic := '0';
    signal rx_pkt_timeout   : unsigned(clog2(TIMEOUT_MAX) - 1 downto 0) := (others => '0');
    signal rx_active_pkt    : std_logic := '0';
    signal phy_rx_pkt_done  : std_logic := '0';

    -- RX output fifo signals
    signal dout_fifo_full   : std_logic := '0';
    signal dout_fifo_empty  : std_logic := '0';

    signal skid_m_axis_tdata    : std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
    signal skid_m_axis_tvalid   : std_logic;
    signal skid_m_axis_tready   : std_logic;

    -- TX data fifo input signals
    signal din_fifo_empty : std_logic := '0';
    signal din_fifo_full  : std_logic := '0';
        
    -- TX data fifo output signals
    signal phy_tx_fifo_data     : std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
    signal phy_tx_fifo_ne       : std_logic;
    signal phy_tx_fifo_rd_en    : std_logic;
    
    signal skid_phy_tx_fifo_data    : std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
    signal skid_phy_tx_fifo_ne      : std_logic;
    signal skid_phy_tx_fifo_rd_en   : std_logic;

    -- TX write process signals
    type tx_fsm_t is (WAIT_FOR_PKT, FIRST_DIBIT, SECOND_DIBIT, THIRD_DIBIT, FOURTH_DIBIT, INTER_PKT_GAP);
    signal tx_fsm               : tx_fsm_t := WAIT_FOR_PKT;
    signal phy_clk_tx_busy      : std_logic := '0';
    signal tx_inter_pkt_gap_cnt : unsigned(clog2(INTER_PKT_GAP_CYCLES) downto 0) := (others => '0');
    signal tx_byte              : std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0) := (others => '0');

begin

    -------------------------------------------------------------------------------------------
    --                                     RMII RX                                           --
    -------------------------------------------------------------------------------------------

    -------------------------------------------------
    -- Read packets from phy
    -------------------------------------------------
    proc_rx : process(ref_clk_50mhz) 
    begin
        if rising_edge(ref_clk_50mhz) then
            wr_rx_byte <= '0';
            case (rx_fsm) is
                when IDLE =>
                    if (crs_dv = '1' and rx_data = "01") then
                        rx_byte                 <= rx_data & rx_byte(7 downto 2);
                        rx_dibit_cnt            <= to_unsigned(1, rx_dibit_cnt'length);
                        rx_fsm                  <= BUSY;
                    end if;
                when BUSY =>
                    if (crs_dv = '1') then
                        if (rx_dibit_cnt = DIBIT_COUNT - 1) then
                            rx_dibit_cnt <= (others => '0');
                            wr_rx_byte <= '1';
                        else
                            rx_dibit_cnt <= rx_dibit_cnt + 1;
                        end if;
                        rx_byte                 <= rx_data & rx_byte(7 downto 2);
                        rx_pkt_timeout          <= (others => '0');
                        rx_active_pkt           <= '1';
                        phy_rx_pkt_done         <= '0';
                    else
                        rx_dibit_cnt <= (others => '0');
                        if (rx_active_pkt = '1') then
                            if (rx_pkt_timeout = TIMEOUT_MAX - 1) then
                                rx_active_pkt   <= '0';
                                phy_rx_pkt_done <= '1';
                            else
                                rx_pkt_timeout <= rx_pkt_timeout + 1;
                            end if;
                        else
                            rx_pkt_timeout  <= (others => '0');
                            rx_fsm          <= IDLE;
                        end if;
                    end if;
                    when others =>
                        rx_fsm <= IDLE;
            end case;
        end if;
    end process proc_rx;

    -------------------------------------------------
    -- Sync phy_rx_pkt_done signal to sys clk domain
    -------------------------------------------------
    sync_rx_pkt_done : entity comp.simple_pipe(rtl)
    generic map (
        PIPE_WIDTH  => 1,
        DEPTH       => 2
    ) port map (
        clk         => sys_clk,
        pipe_in(0)  => phy_rx_pkt_done,
        pipe_out(0) => rx_done
    );

    -------------------------------------------------
    -- Sync packets from phy to sys clk domain
    -------------------------------------------------
    skid_m_axis_tvalid   <= (not dout_fifo_empty);
    fifo_wr_rx      <= '1' when (wr_rx_byte = '1' and rx_pkt_timeout = 0) else '0';
    async_dout_fifo : entity comp.async_fifo(rtl)
    generic map (
        DATA_WIDTH  => rx_byte'length,
        DEPTH       => 32
    ) port map (
        -- Write port (rx phy clk domain)
        wr_clk  => ref_clk_50mhz,
        wr_data => rx_byte,
        wr_en   => fifo_wr_rx,
        full    => dout_fifo_full,
        -- Read port (System clk domain)
        rd_clk  => sys_clk,
        rd_data => skid_m_axis_tdata,
        rd_en   => skid_m_axis_tready,
        empty   => dout_fifo_empty
    );

    dout_skid : entity comp.skid_buffer(rtl)
    generic map (
        DATA_WIDTH => rx_byte'length
    ) port map (
        clk             => sys_clk,
        clr             => sys_rst,
        input_valid     => skid_m_axis_tvalid,
        input_ready     => skid_m_axis_tready,
        input_data      => skid_m_axis_tdata,
        output_valid    => m_axis_tvalid,
        output_ready    => m_axis_tready,
        output_data     => m_axis_tdata
    );

    -------------------------------------------------------------------------------------------
    --                                      MII TX                                           --
    -------------------------------------------------------------------------------------------

    ----------------------------------------------------------
    -- Sync tx packets from system clock to phy clock domain
    ----------------------------------------------------------
    skid_phy_tx_fifo_ne <= not din_fifo_empty;
    s_axis_tready       <= not din_fifo_full;

    async_din_fifo : entity comp.async_fifo(rtl)
    generic map (
        DATA_WIDTH => 8,
        DEPTH      => 32
    ) port map (
        -- Write port (System clk domain)
        wr_clk  => sys_clk,
        wr_data => s_axis_tdata,
        wr_en   => s_axis_tvalid,
        full    => din_fifo_full,
        -- Read port (tx phy clk domain)
        rd_clk  => ref_clk_50mhz,
        rd_data => skid_phy_tx_fifo_data,
        rd_en   => skid_phy_tx_fifo_rd_en,
        empty   => din_fifo_empty
    );

    din_skid : entity comp.skid_buffer(rtl)
    generic map (
        DATA_WIDTH => rx_byte'length,
        ASYNC_INPUT => "TRUE"
    ) port map (
        clk             => sys_clk,
        clr             => sys_rst,
        input_valid     => skid_phy_tx_fifo_ne,
        input_ready     => skid_phy_tx_fifo_rd_en,
        input_data      => skid_phy_tx_fifo_data,
        output_valid    => phy_tx_fifo_ne,
        output_ready    => phy_tx_fifo_rd_en,
        output_data     => phy_tx_fifo_data
    );
    -------------------------
    -- Write packets to phy
    -------------------------
    -- When packet is available in fifo process reads a new byte every 2 ref_clk_50mhz cycles until the FIFO is empty
    proc_write_tx_to_phy : process(ref_clk_50mhz)
    begin
        if rising_edge(ref_clk_50mhz) then
            phy_tx_fifo_rd_en       <= '0';
            tx_en                   <= '0';
            tx_inter_pkt_gap_cnt    <= (others => '0');
            case tx_fsm is
                when WAIT_FOR_PKT =>
                    if phy_tx_fifo_ne = '1' then
                        -- Packet is available
                        tx_fsm  <= FIRST_DIBIT;
                        tx_byte <= phy_tx_fifo_data;
                    end if;
                when FIRST_DIBIT =>
                    if phy_tx_fifo_ne = '0' then
                        -- Finished reading / writing packet
                        tx_fsm <= INTER_PKT_GAP;
                    else
                        -- Read next byte
                        phy_tx_fifo_rd_en <= '1';
                        tx_en   <= '1';
                        tx_data <= tx_byte(1 downto 0);
                        tx_fsm  <= SECOND_DIBIT;
                    end if;
                when SECOND_DIBIT =>
                    tx_en   <= '1';
                    tx_data <= tx_byte(3 downto 2);
                    tx_fsm  <= THIRD_DIBIT;
                when THIRD_DIBIT =>
                    tx_en   <= '1';
                    tx_data <= tx_byte(5 downto 4);
                    tx_fsm  <= FOURTH_DIBIT;
                when FOURTH_DIBIT =>
                    tx_en   <= '1';
                    tx_data <= tx_byte(7 downto 6);
                    tx_byte <= phy_tx_fifo_data;
                    tx_fsm  <= FIRST_DIBIT;
                when INTER_PKT_GAP =>
                    if tx_inter_pkt_gap_cnt = INTER_PKT_GAP_CYCLES then
                        tx_fsm <= WAIT_FOR_PKT;
                    else
                        tx_inter_pkt_gap_cnt <= tx_inter_pkt_gap_cnt + 1;
                    end if;
                when others =>
                    tx_fsm <= WAIT_FOR_PKT;
            end case;
        end if;
    end process proc_write_tx_to_phy;

    -- Indicator that another packet can be loaded into the tx FIFO
    phy_clk_tx_busy <= '1' when (tx_fsm /= WAIT_FOR_PKT) else '0';
   
    -------------------------------------------------
    -- Sync ref_clk_50mhz signal to sys clk domain
    -------------------------------------------------
    sync_tx_busy_signal : entity comp.simple_pipe(rtl)
    generic map (
        PIPE_WIDTH  => 1,
        DEPTH       => 2
    ) port map (
        clk         => sys_clk,
        pipe_in(0)  => phy_clk_tx_busy,
        pipe_out(0) => tx_busy
    );

end architecture rtl;