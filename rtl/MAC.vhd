library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.MAC_pack.all;
use work.eth_pack.all;

entity MAC is
    generic (
        ITR_WIDTH           : natural := 16;
        DATA_WIDTH          : natural := 32;
        ADDR_WIDTH          : natural := 32;
        STRB_WIDTH          : natural := 32 / 8;
        RESP_WIDTH          : natural := 2;
        AXIS_DATA_WIDTH     : natural := 8;
        AXIS_STRB_WIDTH     : natural := 1
        );
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
        rx_m_axis_tdata        : out std_logic_vector(AXIS_DATA_WIDTH - 1 downto 0);
        rx_m_axis_tstrb        : out std_logic_vector(AXIS_STRB_WIDTH - 1 downto 0);
        rx_m_axis_tvalid       : out std_logic;
        rx_m_axis_tready       : in std_logic;
        rx_m_axis_tlast        : out std_logic;
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
    signal rx_done : std_logic;
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

begin

    ------------------------------------------------------------------
    -- Phy interfaces
    ------------------------------------------------------------------
    gen_mii_interface : if (GEN_MII = TRUE) generate
        mii_interface_inst : entity work.MII_Phy_Interface(rtl)
        port map (
            sys_clk     => clk,
            sys_rst     => rst,
            tx_busy     => tx_busy,
            rx_done     => rx_done,
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

    ------------------------------------------------------------------
    -- RX pipeline
    ------------------------------------------------------------------
    MAC_rx_pipeline_inst : entity work.MAC_rx_pipeline(rtl)
    generic map (
        AXIS_DATA_WIDTH => AXIS_DATA_WIDTH,
        AXIS_STRB_WIDTH => AXIS_STRB_WIDTH
    ) port map (
        clk             => clk,
        rst             => rst,
        rx_done_in      => rx_done,
        phy_data_in     => rx_data_fifo,
        m_axis_tdata    => rx_m_axis_tdata,
        m_axis_tstrb    => rx_m_axis_tstrb,
        m_axis_tvalid   => rx_m_axis_tvalid,
        m_axis_tready   => rx_m_axis_tready,
        m_axis_tlast    => rx_m_axis_tlast
    );

end architecture rtl;