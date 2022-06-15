library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library comp;

entity tb is
end entity tb;

architecture rtl of tb is
    constant DATA_WIDTH : natural := 8;
    constant DEPTH      : natural := 16;

    -- Write port
    signal wr_clk  : std_logic := '0';
    signal wr_data : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal wr_en   : std_logic := '0';
    signal full    : std_logic := '0';
    -- Read port
    signal rd_clk  : std_logic := '0';
    signal rd_data : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal rd_en   : std_logic := '0';
    signal empty   : std_logic := '0';

begin

    async_fifo_inst : entity comp.async_fifo(rtl)
    generic map (
        DATA_WIDTH  => DATA_WIDTH,
        DEPTH       => DEPTH
    ) port map (
        -- Write port
        wr_clk      => wr_clk,
        wr_data     => wr_data,
        wr_en       => wr_en,
        full        => full,
        -- Read port
        rd_clk      => rd_clk,
        rd_data     => rd_data,
        rd_en       => rd_en,
        empty       => empty
    );

end architecture rtl;