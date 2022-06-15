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
    -- RMII PHY interface
    ---------------------------------------
    signal rmii_clk                : std_logic;
    signal rmii_tx_en              : std_logic := '0';
    signal rmii_tx_data            : std_logic_vector(1 downto 0);
    signal rmii_rx_data            : std_logic_vector(1 downto 0);
    signal rmii_crs_dv             : std_logic;
    signal rmii_rx_er              : std_logic;
begin

    mac_rmii_inst : entity mac.MAC_RMII
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
        -- RMII PHY interface
        ---------------------------------------
        rmii_clk                => rmii_clk,
        rmii_tx_en              => rmii_tx_en,
        rmii_tx_data            => rmii_tx_data,
        rmii_rx_data            => rmii_rx_data,
        rmii_crs_dv             => rmii_crs_dv,
        rmii_rx_er              => rmii_rx_er
    );

end architecture rtl;