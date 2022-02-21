library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.MAC_pack.all;

------------------------------------------------------
-- NAME: MII_Phy_Interface 
-- 
-- DESCRIPTION: FIFO based interface to a MII Phy.
-- FIFO's are interfaced with a simple two way handshake
-- defined in the MAC_pack package. The Phy link speed
-- may be set to 25MHz for 100Mb or 2.5 MHz for 10Mb.
--
-- NOTES: sys_clk frequency must be greater than or 
-- equal to tx_clk frequency.
------------------------------------------------------

entity MII_Phy_Interface is 
    port (
        ----------------------------------
        -- Signals in system clock domain
        ----------------------------------
        sys_clk     : in std_logic := '0';
        sys_rst     : in std_logic := '0';
        tx_busy     : out std_logic := '0';
        rx_done     : out std_logic := '0';
        -- Tx Data in
        sph_din     : inout t_SPH;
        -- Rx Data Out
        sph_dout    : inout t_SPH;
        --------------------------------
        -- Signals in MII clock domain
        --------------------------------
        -- TX signals
        tx_clk      : in std_logic := '0';
        tx_en       : out std_logic := '0';
        tx_er       : out std_logic := '0';
        tx_data     : out std_logic_vector(3 downto 0) := (others => '0');
        -- RX signals 
        rx_clk      : in std_logic := '0';
        rx_en       : in std_logic := '0';
        rx_er       : in std_logic := '0';
        rx_data     : in std_logic_vector(3 downto 0) := (others => '0')
    );
end entity MII_Phy_Interface;

architecture rtl of MII_Phy_Interface is
    -- Inter packet gap is 12 bytes or 24 tx_clk cycles
    constant INTER_PKT_GAP_SIZE : natural := 12 * 2;

    constant TIMEOUT_MAX : natural := 8;

    -- RX recv process signals
    signal rx_byte      : std_logic_vector(7 downto 0) := (others => '0');
    signal got_rx_byte  : std_logic := '0';
    signal wr_rx_byte   : std_logic := '0';
    signal fifo_wr_rx   : std_logic := '0';
   
    -- RX output fifo signals
    signal dout_fifo_full   : std_logic := '0';
    signal dout_fifo_empty  : std_logic := '0';
   
    -- TX input fifo signals
    signal din_fifo_empty : std_logic := '0';
    signal phy_tx_data_sph : t_SPH := (
        data => (others => '0'),
        consent => '0',
        en => '0'
    );

    -- TX write process signals
    type tx_fsm_t is (WAIT_FOR_PKT, FIRST_NIBBLE, SECOND_NIBBLE, INTER_PKT_GAP);
    signal tx_fsm               : tx_fsm_t := WAIT_FOR_PKT;
    signal phy_clk_tx_busy      : std_logic := '0';
    signal tx_inter_pkt_gap_cnt : unsigned(31 downto 0) := (others => '0');

    signal rx_pkt_timeout           : unsigned(7 downto 0) := (others => '0');
    signal rx_active_pkt            : std_logic := '0';
    signal phy_rx_pkt_done          : std_logic := '0';

begin
    -------------------------------------------------------------------------------------------
    --                                      MII RX                                           --
    -------------------------------------------------------------------------------------------

    -------------------------------------------------
    -- Read packets from phy
    -------------------------------------------------
    proc_rx : process(rx_clk) 
    begin
        if rising_edge(rx_clk) then
            if rx_en = '1' then
                got_rx_byte             <= not got_rx_byte;
                wr_rx_byte              <= got_rx_byte;
                rx_byte                 <= rx_data & rx_byte(7 downto 4);
                rx_pkt_timeout          <= (others => '0');
                rx_active_pkt           <= '1';
                phy_rx_pkt_done         <= '0';
            else
                if (rx_active_pkt = '1') then
                    wr_rx_byte      <= '0';
                    if (rx_pkt_timeout = TIMEOUT_MAX) then
                        rx_active_pkt   <= '0';
                        phy_rx_pkt_done <= '1';
                    else
                        rx_pkt_timeout <= rx_pkt_timeout + 1;
                    end if;
                else
                    got_rx_byte     <= '0';
                    wr_rx_byte      <= '0';
                    rx_pkt_timeout  <= (others => '0');
                end if;
            end if;
        end if;
    end process proc_rx;
    
    -------------------------------------------------
    -- Sync phy_rx_pkt_done signal to sys clk domain
    -------------------------------------------------
    sync_rx_pkt_done : entity work.simple_pipe(rtl)
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
    sph_dout.consent    <= (not dout_fifo_empty);
    fifo_wr_rx          <= '1' when (wr_rx_byte = '1' and rx_pkt_timeout = 0) else '0';
    async_dout_fifo : entity work.async_fifo(rtl)
    generic map (
        DATA_WIDTH  => rx_byte'length,
        DEPTH       => 32
    ) port map (
        -- Write port (rx phy clk domain)
        wr_clk  => rx_clk,
        wr_data => rx_byte,
        wr_en   => fifo_wr_rx,
        full    => dout_fifo_full,
        -- Read port (System clk domain)
        rd_clk  => sys_clk,
        rd_data => sph_dout.data,
        rd_en   => sph_dout.en,
        empty   => dout_fifo_empty
    );

    -------------------------------------------------------------------------------------------
    --                                      MII TX                                           --
    -------------------------------------------------------------------------------------------

    ----------------------------------------------------------
    -- Sync tx packets from system clock to phy clock domain
    ----------------------------------------------------------
    phy_tx_data_sph.consent <= not din_fifo_empty;

    async_din_fifo : entity work.async_fifo(rtl)
    generic map (
        DATA_WIDTH => 8,
        DEPTH      => 32
    ) port map (
        -- Write port (System clk domain)
        wr_clk  => sys_clk,
        wr_data => sph_din.data,
        wr_en   => sph_din.en,
        full    => sph_din.consent,
        -- Read port (tx phy clk domain)
        rd_clk  => tx_clk,
        rd_data => phy_tx_data_sph.data,
        rd_en   => phy_tx_data_sph.en,
        empty   => din_fifo_empty
    );

    -------------------------
    -- Write packets to phy
    -------------------------
    tx_data <= phy_tx_data_sph.data(3 downto 0) when (tx_fsm = FIRST_NIBBLE) else phy_tx_data_sph.data(7 downto 4);
    tx_en <= phy_tx_data_sph.consent when (tx_fsm /= WAIT_FOR_PKT and tx_fsm /= INTER_PKT_GAP) else '0';

    -- When packet is available in fifo process reads a new byte every 2 tx_clk cycles until the FIFO is empty
    proc_write_tx_to_phy : process(tx_clk)
    begin
        if rising_edge(tx_clk) then
            phy_tx_data_sph.en <= '0';
            tx_inter_pkt_gap_cnt <= (others => '0');
            case tx_fsm is
                when WAIT_FOR_PKT =>
                    if phy_tx_data_sph.consent = '1' then
                        -- Packet is available
                        tx_fsm <= FIRST_NIBBLE;
                    end if;
                when FIRST_NIBBLE =>
                    if phy_tx_data_sph.consent = '0' then
                        -- Finished reading / writing packet
                        tx_fsm <= INTER_PKT_GAP;
                    else
                        -- Read next byte
                        phy_tx_data_sph.en <= '1';
                        tx_fsm <= SECOND_NIBBLE;
                    end if;
                when SECOND_NIBBLE =>
                    tx_fsm <= FIRST_NIBBLE;
                when INTER_PKT_GAP =>
                    if tx_inter_pkt_gap_cnt = INTER_PKT_GAP_SIZE then
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
    -- Sync phy_clk_tx_busy signal to sys clk domain
    -------------------------------------------------
    sync_tx_busy_signal : entity work.simple_pipe(rtl)
    generic map (
        PIPE_WIDTH  => 1,
        DEPTH       => 2
    ) port map (
        clk         => sys_clk,
        pipe_in(0)  => phy_clk_tx_busy,
        pipe_out(0) => tx_busy
    );

end architecture rtl;