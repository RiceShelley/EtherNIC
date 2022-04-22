library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.math_pack.all;

entity vid_mem is
    generic (
        -- Needs to be next pow 2 of 640
        FRAME_WIDTH         : natural := 640;
        KERN_DIM            : natural := 3;
        PIX_WIDTH           : natural := 8
    );
    port (
        clk             : in std_logic;
        clr             : in std_logic;
        -- AXI stream slave
        s_axis_tvalid   : in std_logic;
        s_axis_tdata    : in std_logic_vector(PIX_WIDTH - 1 downto 0);
        s_axis_tready   : out std_logic;
        -- AXI stream master
        m_axis_tvalid   : out std_logic;
        m_axis_tdata    : out std_logic_vector(PIX_WIDTH * KERN_DIM - 1 downto 0);
        m_axis_tready   : in std_logic
    );
end entity vid_mem;

architecture rtl of vid_mem is
    constant MEM_ADDR_WIDTH : natural := clog2(FRAME_WIDTH - 1);

    type mem_t is array (0 to 1024 * (KERN_DIM + 1) - 1) of std_logic_vector(PIX_WIDTH - 1 downto 0);
    signal vid_mem : mem_t;

    signal wrBlk : unsigned(1 downto 0) := (others => '0');
    signal wrPtr : unsigned(MEM_ADDR_WIDTH - 1 downto 0) := (others => '0');

    signal rdBlk : unsigned(1 downto 0) := (others => '0');
    signal rdPtr : unsigned(MEM_ADDR_WIDTH - 1 downto 0) := (others => '0');

    signal full : std_logic_vector(KERN_DIM downto 0) := (others => '0');

    type dout_type is array (0 to KERN_DIM - 1) of std_logic_vector(PIX_WIDTH - 1 downto 0);
    signal dout : dout_type;

    function can_read(idx : unsigned; n : natural; full : std_logic_vector) return std_logic is
        variable rtn : std_logic := '1';
    begin
        for i in 0 to n loop
            if full(to_integer(idx + to_unsigned(i, idx'length))) = '0' then
                rtn := '0';
            end if;
        end loop;
        return rtn;
    end function can_read;
begin

    s_axis_tready <= not full(to_integer(wrBlk));

    data_out_proc : process(dout) begin
        for i in 0 to KERN_DIM - 1 loop
            m_axis_tdata((i + 1) * PIX_WIDTH - 1 downto i * PIX_WIDTH) <= dout(i);
        end loop;
    end process data_out_proc;

    mem_proc : process(clk) begin
        if rising_edge(clk) then
            if clr = '1' then

            else 
                m_axis_tvalid <= '0';
                if (s_axis_tvalid = '1' and full(to_integer(wrBlk)) = '0') then
                    vid_mem(to_integer(wrBlk & wrPtr)) <= s_axis_tdata;
                    if wrPtr /= FRAME_WIDTH - 1 then
                        wrPtr <= wrPtr + 1;
                    else
                        wrPtr <= (others => '0');
                        full(to_integer(wrBlk)) <= '1';
                        wrBlk <= wrBlk + 1;
                    end if;
                elsif m_axis_tready = '1' then
                    if can_read(rdBlk, KERN_DIM - 1, full) = '1' then
                        for i in 0 to KERN_DIM - 1 loop
                            dout(i) <= vid_mem(to_integer((rdBlk + to_unsigned(i, rdBlk'length)) & rdPtr));
                        end loop;
                        m_axis_tvalid <= '1';
                        if rdPtr /= FRAME_WIDTH - 1 then
                            rdPtr <= rdPtr + 1;
                        else
                            rdPtr <= (others => '0');
                            full(to_integer(rdBlk)) <= '0';
                            rdBlk <= rdBlk + 1;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process mem_proc;

end architecture rtl;