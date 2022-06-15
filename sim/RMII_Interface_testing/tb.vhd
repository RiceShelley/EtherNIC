library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library mac;

entity tb is
end entity tb;

architecture rtl of tb is
    constant MAC_AXIS_DATA_WIDTH    : natural := 8;
    ----------------------------------
    -- Signals in system clock domain
    ----------------------------------
    signal sys_clk         : std_logic := '0';
    signal sys_rst         : std_logic := '0';
    signal tx_busy         : std_logic := '0';
    signal rx_done         : std_logic := '0';
    -- Tx Data in
    signal s_axis_tdata    : std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
    signal s_axis_tvalid   : std_logic;
    signal s_axis_tready   : std_logic;
    -- Rx Data Out
    signal m_axis_tdata    : std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
    signal m_axis_tvalid   : std_logic;
    signal m_axis_tready   : std_logic;
    ----------------------------------
    -- Signals in RMII clock domain
    ----------------------------------
    signal ref_clk_50mhz   : std_logic;
    -- TX signals
    signal tx_en           : std_logic := '0';
    signal tx_data         : std_logic_vector(1 downto 0);
    -- RX signals
    signal rx_data         : std_logic_vector(1 downto 0);
    signal crs_dv          : std_logic;
    signal rx_er           : std_logic;
begin

    rmii_phy_interface_inst : entity mac.RMII_Phy_Interface
    port map (
        ----------------------------------
        -- Signals in system clock domain
        ----------------------------------
        sys_clk         => sys_clk,
        sys_rst         => sys_rst,
        tx_busy         => tx_busy,
        rx_done         => rx_done,
        -- Tx Data in
        s_axis_tdata    => s_axis_tdata,
        s_axis_tvalid   => s_axis_tvalid,
        s_axis_tready   => s_axis_tready,
        -- Rx Data Out
        m_axis_tdata    => m_axis_tdata,
        m_axis_tvalid   => m_axis_tvalid,
        m_axis_tready   => m_axis_tready,
        ----------------------------------
        -- Signals in RMII clock domain
        ----------------------------------
        ref_clk_50mhz   => ref_clk_50mhz,
        -- TX signals
        tx_en           => tx_en,
        tx_data         => tx_data,
        -- RX signals
        rx_data         => rx_data,
        crs_dv          => crs_dv,
        rx_er           => rx_er
    );

end architecture rtl;