library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mult is
    generic (
        PIX_WIDTH : natural := 8
    );
    port (
        clk     : in std_logic;
        clr     : in std_logic;
        pix0In  : in std_logic_vector(PIX_WIDTH - 1 downto 0);
        pix1In  : in std_logic_vector(PIX_WIDTH - 1 downto 0);
        pixOut  : out std_logic_vector(PIX_WIDTH * 2 - 1 downto 0)
    );
end entity mult;

architecture rtl of mult is
    signal pix0 : signed(PIX_WIDTH - 1 downto 0);
    signal pix1 : signed(PIX_WIDTH - 1 downto 0);

    constant PIPE_DEPTH : natural := 3;
    type lvec_array_t is array(0 to PIPE_DEPTH - 1) of signed(PIX_WIDTH * 2 - 1 downto 0);
    signal pipe : lvec_array_t := (others => (others => '0'));

begin

    pix0    <= signed(pix0In);
    pix1    <= signed(pix1In);
    pixOut <= std_logic_vector(pipe(pipe'right));

    mult_proc : process(clk) begin
        if rising_edge(clk) then
            if clr = '1' then
                pipe <= (others => (others => '0'));
            else
                for i in 1 to (pipe'length - 1) loop
                    pipe(i) <= pipe(i - 1);
                end loop;
                pipe(0) <= signed(pix0 * pix1);
            end if;
        end if;
    end process mult_proc;

end architecture;