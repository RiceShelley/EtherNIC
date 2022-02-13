library ieee;   use ieee.std_logic_1164.all;
                use ieee.numeric_std.all;

use work.math_pack.all;

entity sync_fifo is
    generic (
        DATA_WIDTH : natural := 8;
        DEPTH : natural := 16
    );
    port (
        clk  : in std_logic;
        rst  : in std_logic;
        -- Write port
        wr_data : in std_logic_vector(DATA_WIDTH - 1 downto 0);
        wr_en   : in std_logic;
        full    : out std_logic;
        -- Read port
        rd_data : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        rd_en   : in std_logic;
        empty   : out std_logic
    );
end entity sync_fifo;

architecture rtl of sync_fifo is
    constant ADDR_WIDTH : natural := clog2(to_unsigned(DEPTH, 32));
    constant POW2_DEPTH : natural := 2 ** ADDR_WIDTH;

    type t_mem is array(0 to POW2_DEPTH - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal mem : t_mem := (others => (others => '0'));

    signal wr_addr : unsigned(ADDR_WIDTH downto 0) := (others => '0');
    signal rd_addr : unsigned(ADDR_WIDTH downto 0) := (others => '0');

    signal fifo_full    : std_logic;
    signal fifo_empty   : std_logic;

begin

    full <= fifo_full;
    empty <= fifo_empty;

    fifo_full <= '1' when (wr_addr(ADDR_WIDTH) /= rd_addr(ADDR_WIDTH))
                and (wr_addr(ADDR_WIDTH - 1 downto 0) = rd_addr(ADDR_WIDTH - 1 downto 0)) else '0';
    fifo_empty <= '1' when (wr_addr = rd_addr) else '0';

    rd_data <= mem(to_integer(rd_addr(ADDR_WIDTH - 1 downto 0)));

    wr_proc : process(clk) begin
        if rising_edge(clk) then
            if rst /= '0' then
                wr_addr <= (others => '0');
            else
                if wr_en = '1' and fifo_full /= '1' then
                    mem(to_integer(wr_addr(ADDR_WIDTH - 1 downto 0))) <= wr_data;
                    wr_addr <= wr_addr + 1;
                end if;
            end if;
        end if;
    end process wr_proc;

    rd_addr_proc : process(clk) begin
        if rising_edge(clk) then
            if rst /= '0' then
                rd_addr <= (others => '0');
            else
                if rd_en = '1' and fifo_empty = '0' then
                    rd_addr <= rd_addr + 1;
                end if;
            end if;
        end if;
    end process rd_addr_proc;

end architecture rtl;