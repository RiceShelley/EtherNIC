library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library mac;

entity tb is
end entity tb;

architecture rtl of tb is
    signal clk                     : std_logic;
    signal rst                     : std_logic;
    ---------------------------------------
    -- AXI RX Data Stream 
    ---------------------------------------
    signal rx_m_axis_tdata         : std_logic_vector(7 downto 0);
    signal rx_m_axis_tstrb         : std_logic_vector(0 downto 0);
    signal rx_m_axis_tvalid        : std_logic;
    signal rx_m_axis_tready        : std_logic;
    signal rx_m_axis_tlast         : std_logic;
    ---------------------------------------
    -- AXI TX Data Stream 
    ---------------------------------------
    signal tx_s_axis_tdata         : std_logic_vector(7 downto 0);
    signal tx_s_axis_tstrb         : std_logic_vector(0 downto 0);
    signal tx_s_axis_tvalid        : std_logic;
    signal tx_s_axis_tready        : std_logic;
    signal tx_s_axis_tlast         : std_logic;
    ---------------------------------------
    -- MII PHY interface
    ---------------------------------------
    signal mii_tx_clk              : std_logic;
    signal mii_tx_en               : std_logic := '0';
    signal mii_tx_er               : std_logic := '0';
    signal mii_tx_data             : std_logic_vector(3 downto 0) := (others => '0');
    signal mii_rx_clk              : std_logic;
    signal mii_rx_en               : std_logic;
    signal mii_rx_er               : std_logic;
    signal mii_rx_data             : std_logic_vector(3 downto 0);
    signal mii_rst_phy             : std_logic := '0';
begin

    mac_mii_inst : entity mac.MAC_MII
    port map (
        clk                     => clk,
        rst                     => rst,
        ---------------------------------------
        -- AXI RX Data Stream 
        ---------------------------------------
        rx_m_axis_tdata         => rx_m_axis_tdata,
        rx_m_axis_tstrb         => rx_m_axis_tstrb,
        rx_m_axis_tvalid        => rx_m_axis_tvalid,
        rx_m_axis_tready        => rx_m_axis_tready,
        rx_m_axis_tlast         => rx_m_axis_tlast,
        ---------------------------------------
        -- AXI TX Data Stream 
        ---------------------------------------
        tx_s_axis_tdata         => tx_s_axis_tdata,
        tx_s_axis_tstrb         => tx_s_axis_tstrb,
        tx_s_axis_tvalid        => tx_s_axis_tvalid,
        tx_s_axis_tready        => tx_s_axis_tready,
        tx_s_axis_tlast         => tx_s_axis_tlast,
        ---------------------------------------
        -- MII PHY interface
        ---------------------------------------
        mii_tx_clk              => mii_tx_clk,
        mii_tx_en               => mii_tx_en,
        mii_tx_er               => mii_tx_er,
        mii_tx_data             => mii_tx_data,
        mii_rx_clk              => mii_rx_clk,
        mii_rx_en               => mii_rx_en,
        mii_rx_er               => mii_rx_er,
        mii_rx_data             => mii_rx_data,
        mii_rst_phy             => mii_rst_phy
    );

end architecture rtl;