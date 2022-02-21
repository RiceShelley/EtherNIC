library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.eth_pack.all;
use work.math_pack.all;

entity crc32_check is
    port (
        clk             : in std_logic;
        frame_start_in  : in std_logic;
        data_in         : in std_logic_vector(7 downto 0);
        data_valid_in   : in std_logic;
        frame_done_in   : in std_logic;
        fcs_passed_out  : out std_logic;
        fcs_failed_out  : out std_logic
    );
end entity crc32_check;

architecture rtl of crc32_check is

    signal shift_reg    : std_logic_vector(FCS_WIDTH - 1 downto 0) := (others => '1');
    signal crc          : std_logic_vector(FCS_WIDTH - 1 downto 0);

    signal expected_pkt_crc : std_logic_vector(FCS_WIDTH - 1 downto 0) := (others => '0');
    signal actual_pkt_crc   : std_logic_vector(FCS_WIDTH - 1 downto 0) := (others => '0');

    signal fcs_byte_cnt     : unsigned(clog2(FCS_SIZE) - 1 downto 0)            := (others => '0');
    signal byte_cnt         : unsigned(LENGTH_WIDTH - 1 downto 0)               := (others => '0');
    signal frame_length     : unsigned(LENGTH_WIDTH - 1 downto 0)               := (others => '0');
    signal got_frame_length : std_logic := '0';

    -- CRC 32 functions
    function lfsr_crc_serial (sr : std_logic_vector; data : std_logic) return std_logic_vector is
        variable rtn : std_logic_vector(31 downto 0);
    begin
        rtn(0) := sr(31) xor data;
        for i in 1 to sr'left loop
            if CRC32_POLY(i) = '1' then
                rtn(i) := sr(i - 1) xor rtn(0);
            else
                rtn(i) := sr(i - 1);
            end if;
        end loop;
        return rtn;
    end function lfsr_crc_serial;

    function crc_itr (sr : std_logic_vector; data : std_logic_vector) return std_logic_vector is
        variable rtn : std_logic_vector(31 downto 0);
    begin
        rtn := sr;
        for i in 0 to data'left loop
            rtn := lfsr_crc_serial(rtn, data(7 - i));
        end loop;
        return rtn;
    end function crc_itr;

    function reverse_vec(vec : in std_logic_vector) return std_logic_vector is
        variable result : std_logic_vector(vec'range);
        alias vec_reverse : std_logic_vector(vec'reverse_range) is vec;
    begin
        for i in vec_reverse'range loop
            result(i) := vec_reverse(i);
        end loop;
        return result;
    end;

begin

    crc <= not reverse_vec(shift_reg);

    shift : process (clk) begin
        if rising_edge(clk) then
            if (frame_start_in = '1') then
                shift_reg <= (others => '1');
            else
                if (data_valid_in = '1') then
                    shift_reg       <= crc_itr(shift_reg, reverse_vec(data_in));
                    actual_pkt_crc  <= data_in & actual_pkt_crc(31 downto 8);
                    byte_cnt        <= byte_cnt + 1;
                end if;
            end if;
        end if;
    end process shift;

    crc_delay_inst : entity work.simple_pipe(rtl)
    generic map (
        PIPE_WIDTH => shift_reg'length,
        DEPTH => FCS_SIZE
    ) port map (
        clk => clk,
        en => data_valid_in,
        pipe_in => crc,
        pipe_out => expected_pkt_crc
    );

    compare_fcs_proc : process (clk) begin
        if rising_edge(clk) then
            fcs_failed_out <= '0';
            fcs_passed_out <= '0';
            if (frame_done_in = '1') then
                if (actual_pkt_crc = expected_pkt_crc) then
                    fcs_passed_out <= '1';
                else
                    fcs_failed_out <= '1';
                end if;
            end if;
        end if;
    end process compare_fcs_proc;

end architecture rtl;