library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.math_pack.all;

entity unfold_conv is
    generic (
        PIX_IN_WIDTH    : natural := 8;
        PIX_OUT_WIDTH   : natural := 8 * 2;
        KERN_SIZE       : natural := 3;
        PIPE_CNT        : natural := 16
    );
    port (
        clk             : in std_logic;
        rst             : in std_logic;
        pass            : in std_logic;
        start           : in std_logic;
        matIn           : in std_logic_vector(PIX_IN_WIDTH * KERN_SIZE ** 2 - 1 downto 0);
        pixOut          : out std_logic_vector(PIX_OUT_WIDTH - 1 downto 0);
        done            : out std_logic
    );
end entity unfold_conv;

architecture rtl of unfold_conv is

    constant PTR_WIDTH : natural := clog2(PIPE_CNT);

    signal cStart   : std_logic_vector(PIPE_CNT - 1 downto 0);
    signal matInR   : std_logic_vector(PIX_IN_WIDTH * KERN_SIZE ** 2 - 1 downto 0);
    signal cDone    : std_logic_vector(PIPE_CNT - 1 downto 0);

    type pix_array_t is array(0 to PIPE_CNT - 1) of std_logic_vector(PIX_OUT_WIDTH - 1 downto 0);
    signal cPixOut : pix_array_t := (others => (others => '0'));

    signal wrPtr : unsigned(PTR_WIDTH - 1 downto 0) := (others => '0');
    signal rdPtr : unsigned(PTR_WIDTH - 1 downto 0) := (others => '0');
begin

    wr_proc : process(clk) begin
        if rising_edge(clk) then
            if rst /= '0' then
                cStart  <= (others => '0');
                wrPtr   <= (others => '0');
            else
                matInR <= matIn;
                -- Route start signal to the correct pipe
                for i in 0 to PIPE_CNT - 1 loop
                    if i = wrPtr then
                        cStart(i) <= start;
                    else
                        cStart(i) <= '0';
                    end if;
                end loop;
                -- Inc write pointer
                if start = '1' then
                    if wrPtr /= PIPE_CNT - 1 then
                        wrPtr <= wrPtr + 1;
                    else
                        wrPtr <= (others => '0');
                    end if;
                end if;
            end if;
        end if;
    end process wr_proc;

    gen_conv_pipes : for i in 0 to PIPE_CNT - 1 generate
        conv_pipe_inst : entity work.conv_pipe(rtl)
        port map (
            clk     => clk,
            pass    => pass,
            start   => cStart(i),
            mat_in  => matInR,
            pix_out => cPixOut(i),
            done    => cDone(i)
        );
    end generate gen_conv_pipes;

    rd_proc : process(clk) begin
        if rising_edge(clk) then
            if rst /= '0' then
                done    <= '0';
                pixOut  <= (others => '0');
                rdPtr   <= (others => '0');
            else
                done <= '0';
                if (cDone(to_integer(rdPtr)) = '1') then
                    -- Capture data
                    done    <= '1';
                    pixOut  <= cPixOut(to_integer(rdPtr));
                    -- Inc read pointer
                    if rdPtr /= PIPE_CNT - 1 then
                        rdPtr <= rdPtr + 1;
                    else
                        rdPtr <= (others => '0');
                    end if;
                end if;
            end if;
        end if;
    end process rd_proc;

end architecture rtl;