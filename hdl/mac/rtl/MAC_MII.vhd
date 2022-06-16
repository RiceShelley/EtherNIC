library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.MAC_pack.all;
use work.eth_pack.all;

entity MAC_MII is
    generic (
        TX_UNFOLD_CNT       : natural := 2);
    port (
        clk                     : in std_logic;
        rst                     : in std_logic;
        ---------------------------------------
        -- AXI RX Data Stream 
        ---------------------------------------
        rx_m_axis_tdata         : out std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
        rx_m_axis_tstrb         : out std_logic_vector(MAC_AXIS_STRB_WIDTH - 1 downto 0);
        rx_m_axis_tvalid        : out std_logic;
        rx_m_axis_tready        : in std_logic;
        rx_m_axis_tlast         : out std_logic;
        ---------------------------------------
        -- AXI TX Data Stream 
        ---------------------------------------
        tx_s_axis_tdata         : in std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
        tx_s_axis_tstrb         : in std_logic_vector(MAC_AXIS_STRB_WIDTH - 1 downto 0);
        tx_s_axis_tvalid        : in std_logic;
        tx_s_axis_tready        : out std_logic;
        tx_s_axis_tlast         : in std_logic;
        ---------------------------------------
        -- MII PHY interface
        ---------------------------------------
        mii_tx_clk              : in std_logic;
        mii_tx_en               : out std_logic := '0';
        mii_tx_er               : out std_logic := '0';
        mii_tx_data             : out std_logic_vector(3 downto 0) := (others => '0');
        mii_rx_clk              : in std_logic;
        mii_rx_en               : in std_logic;
        mii_rx_er               : in std_logic;
        mii_rx_data             : in std_logic_vector(3 downto 0);
        mii_rst_phy             : out std_logic := '0'
    );
end entity MAC_MII;

architecture rtl of MAC_MII is
    ---------------------------
    -- Phy interface signals
    ---------------------------
    signal tx_busy : std_logic;
    signal rx_done : std_logic;

    signal rx_pipe_axis_tdata   : std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
    signal rx_pipe_axis_tvalid  : std_logic;
    signal rx_pipe_axis_tready  : std_logic;

    signal tx_pipe_axis_tdata   : std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
    signal tx_pipe_axis_tvalid  : std_logic;
    signal tx_pipe_axis_tready  : std_logic;

begin
    ------------------------------------------------------------------
    -- RX pipeline
    ------------------------------------------------------------------
    MAC_rx_pipeline_inst : entity work.MAC_rx_pipeline(rtl)
    port map (
        clk             => clk,
        rst             => rst,
        rx_done_in      => rx_done,
        -- Data in from PHY
        s_axis_tdata    => rx_pipe_axis_tdata,
        s_axis_tvalid   => rx_pipe_axis_tvalid,
        s_axis_tready   => rx_pipe_axis_tready,
        -- processed data out
        m_axis_tdata    => rx_m_axis_tdata,
        m_axis_tstrb    => rx_m_axis_tstrb,
        m_axis_tvalid   => rx_m_axis_tvalid,
        m_axis_tready   => rx_m_axis_tready,
        m_axis_tlast    => rx_m_axis_tlast
    );

    ------------------------------------------------------------------
    -- TX pipeline
    ------------------------------------------------------------------
    MAC_tx_pipeline_inst : entity work.MAC_tx_pipeline(rtl)
    generic map (
        PIPELINE_ELEM_CNT   => TX_UNFOLD_CNT
    ) port map (
        clk                 => clk,
        rst                 => rst,
        tx_busy_in          => tx_busy,
        -- Axi Data Stream Slave
        s_axis_tdata        => tx_s_axis_tdata,
        s_axis_tstrb        => tx_s_axis_tstrb,
        s_axis_tvalid       => tx_s_axis_tvalid,
        s_axis_tready       => tx_s_axis_tready,
        s_axis_tlast        => tx_s_axis_tlast,
        -- AXI Data Stream Master
        m_axis_tdata        => tx_pipe_axis_tdata,
        m_axis_tvalid       => tx_pipe_axis_tvalid,
        m_axis_tready       => tx_pipe_axis_tready
    );

    ------------------------------------------------------------------
    -- MII Phy interface
    ------------------------------------------------------------------
    mii_interface_inst : entity work.MII_Phy_Interface(rtl)
    port map (
        sys_clk         => clk,
        sys_rst         => rst,
        tx_busy         => tx_busy,
        rx_done         => rx_done,
        -- AXI Stream Slave
        s_axis_tdata    => tx_pipe_axis_tdata,
        s_axis_tvalid   => tx_pipe_axis_tvalid,
        s_axis_tready   => tx_pipe_axis_tready,
        -- AXI Stream Master
        m_axis_tdata    => rx_pipe_axis_tdata,
        m_axis_tvalid   => rx_pipe_axis_tvalid,
        m_axis_tready   => rx_pipe_axis_tready,
        -- PHY signals 
        tx_clk          => mii_tx_clk,
        tx_en           => mii_tx_en,
        tx_er           => mii_tx_er,
        tx_data         => mii_tx_data,
        rx_clk          => mii_rx_clk,
        rx_en           => mii_rx_en,
        rx_er           => mii_rx_er,
        rx_data         => mii_rx_data
    );

end architecture rtl;