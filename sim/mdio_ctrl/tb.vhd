library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library mdio;

entity tb is
end entity tb;

architecture rtl of tb is

    constant DIV_CLK_BY_2N  : natural := 6;

    signal clk              : std_logic;
    -- Signals to phy
    signal mdio_mdc         : std_logic;
    signal mdio_data_out    : std_logic;
    signal mdio_data_in     : std_logic;
    signal mdio_data_tri    : std_logic;
    -- Signals to MAC
    signal start            : std_logic;
    signal wr               : std_logic;
    signal phy_addr         : std_logic_vector(4 downto 0);
    signal reg_addr         : std_logic_vector(4 downto 0);
    signal data_in          : std_logic_vector(15 downto 0);
    signal data_out         : std_logic_vector(15 downto 0);
    signal data_out_valid   : std_logic;
    signal busy_out         : std_logic;

begin

    mdio_controller_inst : entity mdio.MDIO_controller(rtl)
    generic map (
        DIV_CLK_BY_2N   => DIV_CLK_BY_2N
    ) port map (
        clk             => clk,
        -- Signals to phy
        mdio_mdc        => mdio_mdc,
        mdio_data_out   => mdio_data_out,
        mdio_data_in    => mdio_data_in,
        mdio_data_tri   => mdio_data_tri,
        -- Signals to MAC
        start           => start,
        wr              => wr,
        phy_addr        => phy_addr,
        reg_addr        => reg_addr,
        data_in         => data_in,
        data_out        => data_out,
        data_out_valid  => data_out_valid,
        busy_out        => busy_out
    );

end architecture rtl;