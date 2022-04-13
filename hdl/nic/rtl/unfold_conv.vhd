library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity unfold_conv is
    generic (
        PIPE_CNT : natural := 10
    );
    port (
        clk         : in std_logic;
        rst         : in std_logic;
        start       : in std_logic;
        matIn       : in std_logic_vector(PIX_IN_WIDTH * KERN_SIZE ** 2 - 1 downto 0);
        pixOut      : out std_logic_vector(PIX_OUT_WIDTH - 1 downto 0);
        done        : out std_logic
    );
end entity unfold_conv;

architecture rtl of unfold_conv is
    signal cStart : std_logic_vector(PIPE_CNT - 1 downto 0);
    signal cDone : std_logic_vector(PIPE_CNT - 1 downto 0);
    type pix_array_t is array(0 to PIPE_CNT - 1) std_logic_vector(PIX_OUT_WIDTH - 1 downto 0);
begin

    gen_conv_pipes : for i in 0 to PIPE_CNT - 1 generate
        conv_pipe_inst : entity work.conv_pipe(rtl)
        port map (
            clk     => clk,
            start   => cStart(i),
            mat_in  => matIn,
            pix_out => cPixOut(i),
            done    => cDone(i)
        );
    end generate gen_conv_pipes;

end architecture rtl;