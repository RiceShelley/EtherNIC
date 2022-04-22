library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity conv_pipe is
    generic (
        PIX_IN_WIDTH    : natural := 8;
        PIX_OUT_WIDTH   : natural := 8 * 2;
        KERN_SIZE       : natural := 3
    );
    port (
        clk             : in std_logic;
        pass            : in std_logic;
        start           : in std_logic;
        mat_in          : in std_logic_vector(PIX_IN_WIDTH * KERN_SIZE ** 2 - 1 downto 0);
        pix_out         : out std_logic_vector(PIX_OUT_WIDTH - 1 downto 0);
        done            : out std_logic
    );
end entity conv_pipe;

architecture rtl of conv_pipe is

    constant MULT_LATENCY : natural := 3;

    type conv_fsm_t is (IDLE, BUSY);
    signal conv_state : conv_fsm_t := IDLE;

    signal clr      : std_logic := '0';
    signal matR     : std_logic_vector(PIX_IN_WIDTH * KERN_SIZE ** 2 - 1 downto 0) := (others => '0');
    signal pixIn    : std_logic_vector(PIX_IN_WIDTH - 1 downto 0) := (others => '0');
    signal kernPix  : std_logic_vector(PIX_IN_WIDTH - 1 downto 0) := (others => '0');
    signal multOut  : std_logic_vector(PIX_OUT_WIDTH - 1 downto 0) := (others => '0');
    signal curElem : natural := 0;
    signal pixOutR  : signed(15 downto 0) := (others => '0');
    signal doneR    : std_logic := '0';

    constant CONV_KERN_ROM : std_logic_vector((8 * (3 ** 2)) - 1 downto 0) :=
        (std_logic_vector(to_signed(-1, 8)) & std_logic_vector(to_signed(-1, 8)) & std_logic_vector(to_signed(-1, 8)) &
        std_logic_vector(to_signed(-1, 8)) & std_logic_vector(to_signed(8, 8))  & std_logic_vector(to_signed(-1, 8)) &
        std_logic_vector(to_signed(-1, 8)) & std_logic_vector(to_signed(-1, 8)) & std_logic_vector(to_signed(-1, 8)));

    constant PASS_KERN_ROM : std_logic_vector((8 * (3 ** 2)) - 1 downto 0) :=
        (std_logic_vector(to_signed(0, 8)) & std_logic_vector(to_signed(0, 8)) & std_logic_vector(to_signed(0, 8)) &
        std_logic_vector(to_signed(0, 8)) & std_logic_vector(to_signed(1, 8))  & std_logic_vector(to_signed(0, 8)) &
        std_logic_vector(to_signed(0, 8)) & std_logic_vector(to_signed(0, 8)) & std_logic_vector(to_signed(0, 8)));
begin

    pix_out <= std_logic_vector(pixOutR);
    done    <= doneR;

    mult_inst : entity work.mult(rtl)
    generic map (
        PIX_WIDTH => PIX_IN_WIDTH
    ) port map (
        clk       => clk,
        clr       => clr,
        pix0In    => pixIn,
        pix1In    => kernPix,
        pixOut    => multOut
    );

    -- Accumulate valids
    accum_proc : process(clk) begin
        if rising_edge(clk) then
            if clr = '1' then
                pixOutR <= (others => '0');
            else
                pixOutR <= pixOutR + signed(multOut);
            end if;
        end if;
    end process accum_proc;

    conv_fsm_proc : process(clk) begin
        if rising_edge(clk) then
            clr <= '0';
            case (conv_state) is
                when IDLE =>
                    if (start = '1') then
                        clr         <= '1';
                        curElem    <= 0;
                        matR        <= mat_in;
                        conv_state  <= BUSY;
                    end if;
                when BUSY =>
                    pixIn   <= matR((curElem + 1) * PIX_IN_WIDTH - 1 downto curElem * PIX_IN_WIDTH);
                    if pass = '1' then
                        kernPix <= PASS_KERN_ROM((curElem + 1) * PIX_IN_WIDTH - 1 downto curElem * PIX_IN_WIDTH);
                    else
                        kernPix <= CONV_KERN_ROM((curElem + 1) * PIX_IN_WIDTH - 1 downto curElem * PIX_IN_WIDTH);
                    end if;
                    if curElem /= (KERN_SIZE ** 2 - 1) then
                        curElem <= curElem + 1;
                    elsif doneR = '1' then
                        conv_state <= IDLE;
                    end if;
                when others =>
                    conv_state <= IDLE;
            end case;
        end if;
    end process conv_fsm_proc;

    -- Drive done signal
    delay_pipe_inst : entity work.simple_pipe(rtl)
    generic map (
        PIPE_WIDTH  => 1,
        DEPTH       => KERN_SIZE ** 2 + MULT_LATENCY + 1
    ) port map (
        clk         => clk,
        en          => '1',
        pipe_in(0)  => clr,
        pipe_out(0) => doneR
    );

end architecture rtl;

