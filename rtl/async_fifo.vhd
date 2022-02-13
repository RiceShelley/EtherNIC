library ieee;   use ieee.std_logic_1164.all;
                use ieee.numeric_std.all;

use work.math_pack.all;

entity async_fifo is
    generic (
        DATA_WIDTH : natural := 8;
        DEPTH : natural := 16
    );
    port (
        -- Write port
        wr_clk  : in std_logic := '0';
        wr_data : in std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
        wr_en   : in std_logic := '0';
        full    : out std_logic := '0';
        -- Read port
        rd_clk  : in std_logic := '0';
        rd_data : out std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
        rd_en   : in std_logic := '0';
        empty   : out std_logic := '0'
    );
end entity async_fifo;

architecture rtl of async_fifo is
    constant ADDR_WIDTH : natural := clog2(to_unsigned(DEPTH, 32));
    constant POW2_DEPTH : natural := 2 ** ADDR_WIDTH;
    constant SYNC_PIPE_DEPTH : natural := 2;

    type t_mem is array(0 to POW2_DEPTH - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal mem : t_mem := (others => (others => '0'));

    signal wr_addr : unsigned(ADDR_WIDTH downto 0) := (others => '0');
    signal rd_addr : unsigned(ADDR_WIDTH downto 0) := (others => '0');

    signal sync_wr_addr_gray : unsigned(ADDR_WIDTH downto 0) := (others => '0');
    signal sync_rd_addr_gray : unsigned(ADDR_WIDTH downto 0) := (others => '0');

    signal wr_addr_gray : unsigned(ADDR_WIDTH downto 0) := (others => '0');
    signal rd_addr_gray : unsigned(ADDR_WIDTH downto 0) := (others => '0');

    type t_addr_sync_pipe is array(0 to SYNC_PIPE_DEPTH - 1) of unsigned(ADDR_WIDTH downto 0);

    signal wr_addr_sync_pipe : t_addr_sync_pipe := (others => (others => '0'));
    signal rd_addr_sync_pipe : t_addr_sync_pipe := (others => (others => '0'));

    signal full_reg : std_logic := '0';
    signal empty_reg : std_logic := '1';

begin

    wr_addr_gray <= wr_addr xor ("0" & wr_addr(ADDR_WIDTH downto 1));
    rd_addr_gray <= rd_addr xor ("0" & rd_addr(ADDR_WIDTH downto 1));

    sync_wr_addr_gray <= wr_addr_sync_pipe(wr_addr_sync_pipe'right);
    sync_rd_addr_gray <= rd_addr_sync_pipe(rd_addr_sync_pipe'right);

    rd_data <= mem(to_integer(rd_addr(ADDR_WIDTH - 1 downto 0)));

    full <= full_reg;
    empty <= empty_reg;

    full_proc : process(wr_addr_gray, sync_rd_addr_gray) begin
        if (wr_addr_gray(ADDR_WIDTH downto ADDR_WIDTH - 1) = (not sync_rd_addr_gray(ADDR_WIDTH downto ADDR_WIDTH - 1))) 
            and (wr_addr_gray(ADDR_WIDTH - 2 downto 0) = sync_rd_addr_gray(ADDR_WIDTH - 2 downto 0)) then
            full_reg <= '1';
        else
            full_reg <= '0';
        end if;
    end process full_proc;

    wr_proc : process(wr_clk) begin
        if rising_edge(wr_clk) then
            if wr_en = '1' and full_reg /= '1' then
                mem(to_integer(wr_addr(ADDR_WIDTH - 1 downto 0))) <= wr_data;
                wr_addr <= wr_addr + 1;
            end if;
        end if;
    end process wr_proc;

    empty_proc : process(sync_wr_addr_gray, rd_addr_gray) begin
        if sync_wr_addr_gray = rd_addr_gray then
            empty_reg <= '1';
        else
            empty_reg <= '0';
        end if;
    end process empty_proc;

    rd_addr_proc : process(rd_clk) begin
        if rising_edge(rd_clk) then
            if rd_en = '1' and empty_reg = '0' then
                rd_addr <= rd_addr + 1;
            end if;
        end if;
    end process rd_addr_proc;

    rd_addr_to_wr_domain : process (wr_clk) begin
        if rising_edge(wr_clk) then
            rd_addr_sync_pipe <= rd_addr_gray & rd_addr_sync_pipe(0 to rd_addr_sync_pipe'right - 1);
        end if;
    end process;

    wr_addr_to_rd_domain : process (rd_clk) begin
        if rising_edge(rd_clk) then
            wr_addr_sync_pipe <= wr_addr_gray & wr_addr_sync_pipe(0 to wr_addr_sync_pipe'right - 1);
        end if;
    end process;

end architecture rtl;