library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.MAC_pack.all;
use work.eth_pack.all;

entity MAC is
    generic (
        ITR_WIDTH   : natural := 16;
        DATA_WIDTH  : natural := 32;
        ADDR_WIDTH  : natural := 32;
        STRB_WIDTH  : natural := 32 / 8;
        RESP_WIDTH  : natural := 2);
    port (
        clk         : in std_logic;
        rst         : in std_logic;
        interrupts  : out std_logic_vector(ITR_WIDTH - 1 downto 0);
        ---------------------------------------
        -- AXI Lite Slave 
        ---------------------------------------
        aResetn     : in std_logic;
        -- Read Address Channel
        arAddrIn    : in std_logic_vector(ADDR_WIDTH - 1 downto 0);
        arValidIn   : in std_logic;
        arReadyOut  : out std_logic;
        -- Read Data Channel
        rDataOut    : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        rRespOut    : out std_logic_vector(RESP_WIDTH - 1 downto 0);
        rValidOut   : out std_logic;
        rReadyOut   : in std_logic;
        -- Write Address Channel 
        awAddrIn    : in std_logic_vector(ADDR_WIDTH - 1 downto 0);
        awValidIn   : in std_logic;
        awReadyOut  : out std_logic;
        -- Write Data Channel
        wValidIn    : in std_logic;
        wDataIn     : in std_logic_vector(DATA_WIDTH - 1 downto 0);
        wStrbIn     : in std_logic_vector(STRB_WIDTH - 1 downto 0);
        wReadyOut   : out std_logic;
        -- Write Response Channel 
        bRespOut    : out std_logic_vector(RESP_WIDTH - 1 downto 0);
        bValidOut   : out std_logic;
        bReadyIn    : in std_logic;
        ---------------------------------------
        -- AXI RX Data Stream 
        ---------------------------------------

        ---------------------------------------
        -- AXI TX Data Stream 
        ---------------------------------------

        ---------------------------------------
        -- PHY interface
        ---------------------------------------
        mii_tx_clk  : in std_logic;
        mii_tx_en   : out std_logic := '0';
        mii_tx_er   : out std_logic := '0';
        mii_tx_data : out std_logic_vector(3 downto 0) := (others => '0');
        mii_rx_clk  : in std_logic;
        mii_rx_en   : in std_logic;
        mii_rx_er   : in std_logic;
        mii_rx_data : in std_logic_vector(3 downto 0);
        mii_rst_phy : out std_logic := '0'
    );
end entity MAC;

architecture rtl of MAC is
    constant GEN_MII : boolean := TRUE;

    ---------------------------
    -- Phy interface signals
    ---------------------------
    signal tx_busy : std_logic;
    signal tx_data_fifo : t_SPH := (
        data => (others => '0'),
        consent => '0',
        en => '0'
    );

    signal rx_data_fifo : t_SPH := (
        data => (others => '0'),
        consent => '0',
        en => '0'
    );

    signal layer_two_eth_out : t_SPH;
    signal layer_two_eth_start : std_logic;

    signal layer_two_eth_fifo_full : std_logic;

    signal layer_two_fifo_out : t_SPH := (
        data => (others => '0'),
        consent => '0',
        en => '0'
    );

    signal layer_two_fifo_empty : std_logic;

begin

    gen_mii_interface : if (GEN_MII = TRUE) generate
        mii_interface_inst : entity work.MII_Phy_Interface(rtl)
        port map (
            sys_clk     => clk,
            sys_rst     => rst,
            tx_busy     => tx_busy,
            sph_din     => tx_data_fifo,
            sph_dout    => rx_data_fifo,
            tx_clk      => mii_tx_clk,
            tx_en       => mii_tx_en,
            tx_er       => mii_tx_er,
            tx_data     => mii_tx_data,
            rx_clk      => mii_rx_clk,
            rx_en       => mii_rx_en,
            rx_er       => mii_rx_er,
            rx_data     => mii_rx_data
        );
    end generate gen_mii_interface;

    eth_to_layer_two_eth_inst : entity work.eth_to_layer_two_eth(rtl)
    port map (
        clk => clk,
        rst => rst,
        pkt_start => layer_two_eth_start,
        din => rx_data_fifo,
        dout => layer_two_eth_out
    );

    layer_two_fifo_out.consent <= not layer_two_fifo_empty;

    layer_two_eth_fifo : entity work.sync_fifo(rtl)
    generic map (
        DATA_WIDTH  => 8,
        DEPTH       => MAX_ETH_FRAME_SIZE)
    port map (
        clk     => clk,
        rst     => rst,
        wr_data => layer_two_eth_out.data,
        wr_en   => layer_two_eth_out.en,
        full    => layer_two_eth_fifo_full,
        rd_data => layer_two_fifo_out.data,
        rd_en   => layer_two_fifo_out.en,
        empty   => layer_two_fifo_empty
    );

end architecture rtl;