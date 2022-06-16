library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library comp;
use comp.math_pack.all;

library mac;
use mac.MAC_pack.all;
use mac.eth_pack.all;

entity l1_eth_frame_decoder is
    port (
        clk                 : in std_logic;
        rx_done_in          : in std_logic;
        frame_start_out     : out std_logic;
        frame_length_out    : out unsigned(LENGTH_WIDTH - 1 downto 0);
        frame_done_out      : out std_logic;
        -- AXI Stream Slave
        s_axis_tdata        : in std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
        s_axis_tvalid       : in std_logic;
        s_axis_tready       : out std_logic;
        -- AXI Stream Master
        m_axis_tdata        : out std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
        m_axis_tvalid       : out std_logic;
        m_axis_tready       : in std_logic
    );
end entity l1_eth_frame_decoder;

architecture rtl of l1_eth_frame_decoder is

    type decode_fsm_t is (IDLE, GET_LENGTH);
    signal decode_state : decode_fsm_t := IDLE;

    signal frame_start_seq  : std_logic_vector(START_SEQ_WIDTH - 1 downto 0);
    signal byte_cnt     : unsigned(LENGTH_WIDTH - 1 downto 0) := (others => '0');
    signal data_valid   : std_logic;
    signal pass_data    : std_logic;

    signal axis_ready_reg : std_logic;

begin

    s_axis_tready   <= axis_ready_reg;    

    m_axis_tdata    <= s_axis_tdata when (pass_data = '1') else (others => '0');
    m_axis_tvalid   <= s_axis_tvalid and axis_ready_reg and pass_data;

    pass_data       <= '1' when (frame_start_seq = START_SEQ or decode_state /= IDLE) else '0';
    data_valid      <= s_axis_tvalid and axis_ready_reg;

    decode_proc : process(clk) begin
        if rising_edge(clk) then
            frame_done_out  <= '0';
            frame_start_out <= '0';
            axis_ready_reg   <= '1';
            case decode_state is
                -- Idle until frame start sequence is detected
                when IDLE =>
                    if (pass_data = '1') then
                        -- Frame start is valid go to next state
                        frame_start_seq <= (others => '0');
                        axis_ready_reg  <= '0';
                        frame_start_out <= '1';
                        byte_cnt        <= (others => '0');
                        decode_state    <= GET_LENGTH;
                    elsif (data_valid = '1') then
                        -- Shift in new byte
                        frame_start_seq <= frame_start_seq((frame_start_seq'left - s_axis_tdata'length) downto 0) & s_axis_tdata;
                    end if;
                -- Get length of packet
                when GET_LENGTH => 
                        if (rx_done_in = '1') then
                            decode_state        <= IDLE;
                            axis_ready_reg       <= '0';
                            frame_done_out      <= '1';
                            frame_length_out    <= byte_cnt;
                        elsif (data_valid = '1') then
                            byte_cnt <= byte_cnt + 1;
                        end if;
                -- Bad state go back to IDLE
                when others =>
                    decode_state <= IDLE;
            end case;
        end if;
    end process decode_proc;

end architecture rtl;