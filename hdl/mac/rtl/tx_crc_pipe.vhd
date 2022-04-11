library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.MAC_pack.all;
use work.eth_pack.all;
use work.math_pack.all;

entity tx_crc_pipe is
    port (
        clk             : in std_logic;
        crc_done_out    : out std_logic;
        -- AXI Data Stream Slave
        s_axis_tdata    : in std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
        s_axis_tvalid   : in std_logic;
        s_axis_tready   : out std_logic;
        s_axis_tlast    : in std_logic;
        -- AXI Data Stream Master
        m_axis_tdata    : out std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
        m_axis_tvalid   : out std_logic;
        m_axis_tready   : in std_logic
    );
end entity tx_crc_pipe;

architecture rtl of tx_crc_pipe is
    signal shift_reg    : std_logic_vector(FCS_WIDTH - 1 downto 0) := (others => '1');
    signal crc          : std_logic_vector(FCS_WIDTH - 1 downto 0);

    signal fcs_byte_cnt : unsigned(clog2(FCS_SIZE) downto 0) := (others => '0');

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

    type t_cc_state is (IDLE, CALC, APPEND);
    signal cc_state : t_cc_state := IDLE;

begin

    crc <= not reverse_vec(shift_reg);

    calc_crc : process (clk) begin
        if rising_edge(clk) then
            m_axis_tdata    <= s_axis_tdata;
            m_axis_tvalid   <= '0';
            case (cc_state) is
                when IDLE =>
                    shift_reg <= (others => '1');
                    if (s_axis_tvalid = '1') then
                        m_axis_tvalid   <= '1';
                        shift_reg       <= crc_itr(shift_reg, reverse_vec(s_axis_tdata));
                        crc_done_out    <= '0';
                        cc_state        <= CALC;
                    end if;
                when CALC =>
                    if (s_axis_tvalid = '1') then
                        m_axis_tvalid   <= '1';
                        shift_reg       <= crc_itr(shift_reg, reverse_vec(s_axis_tdata));
                        if (s_axis_tlast = '1') then
                            fcs_byte_cnt    <= (others => '0');
                            cc_state        <= APPEND;
                        end if;
                    end if;
                when APPEND =>
                    if (fcs_byte_cnt /= FCS_SIZE) then
                        m_axis_tvalid   <= '1';
                        m_axis_tdata    <= crc((to_integer(fcs_byte_cnt) + 1) * 8 - 1 downto to_integer(fcs_byte_cnt) * 8);
                        fcs_byte_cnt    <= fcs_byte_cnt + 1;
                    else
                        crc_done_out    <= '1';
                        cc_state        <= IDLE;
                    end if;
                when others =>
                    cc_state <= IDLE;
            end case;
        end if;
    end process calc_crc;

end architecture;