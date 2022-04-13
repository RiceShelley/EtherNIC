library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity simple_pipe is
    generic (
        PIPE_WIDTH  : natural := 8;
        DEPTH       : natural := 2);
    port (
        clk         : in std_logic := '0';
        en          : in std_logic := '1';
        pipe_in     : in std_logic_vector(PIPE_WIDTH - 1 downto 0);
        pipe_out    : out std_logic_vector(PIPE_WIDTH - 1 downto 0)
    );
end entity simple_pipe;

architecture rtl of simple_pipe is
    type pipe_t is array (0 to DEPTH - 1) of std_logic_vector(PIPE_WIDTH - 1 downto 0);
    signal pipe : pipe_t := (others => (others => '0'));

    attribute shreg_extract : string;
    attribute shreg_extract of pipe : signal is "NO";
begin

    pipe_out <= pipe(0);

    shift_proc : process(clk) begin
        if rising_edge(clk) then
            if (en = '1') then
                pipe <= pipe(1 to pipe'right) & pipe_in;
            end if;
        end if;
    end process shift_proc;

end architecture;