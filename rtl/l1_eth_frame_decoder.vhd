library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.MAC_pack.all;
use work.eth_pack.all;
use work.math_pack.all;

entity l1_eth_frame_decoder is
    port (
        clk             : in std_logic;
        rst             : in std_logic;
        din             : inout t_SPH;
        dout            : inout t_SPH;
        frame_start_out : out std_logic;
        fcs_valid_out   : out std_logic
    );
end entity l1_eth_frame_decoder;

architecture rtl of l1_eth_frame_decoder is

    type decode_fsm_t is (IDLE, GET_LENGTH, WAIT_FOR_PAYLOAD_END, WAIT_FOR_FCS_END);
    signal decode_state : decode_fsm_t := IDLE;

    signal data_valid       : std_logic;
    signal pass_data        : std_logic;

    signal frame_start  : std_logic_vector(START_SEQ_WIDTH - 1 downto 0);
    signal frame_length : unsigned(LENGTH_WIDTH - 1 downto 0);

    signal get_length_cnt   : unsigned(clog2(LENGTH_OFFSET) - 1 downto 0)  := (others => '0');
    signal payload_end_cnt  : unsigned(LENGTH_WIDTH - 1 downto 0)          := (others => '0');
    signal fcs_end_cnt      : unsigned(clog2(FCS_OFFSET) - 1 downto 0)     := (others => '0');

begin

    dout.data       <= din.data when (pass_data = '1') else (others => '0');
    dout.en         <= din.consent and din.en and pass_data;
    dout.consent    <= '0';

    pass_data       <= '1' when (frame_start = START_SEQ or decode_state /= IDLE) else '0';
    frame_start_out <= '1' when (frame_start = START_SEQ) else '0';
    fcs_valid_out   <= '1' when (decode_state = WAIT_FOR_FCS_END) else '0';

    data_valid <= din.consent and din.en;

    decode_proc : process(clk) begin
        if rising_edge(clk) then
            if rst /= '0' then
                din.en          <= '0';
                frame_start     <= (others => '0');
                get_length_cnt  <= (others => '0');
                payload_end_cnt <= (others => '0');
                fcs_end_cnt     <= (others => '0');
            else
                din.en <= '1';
                case decode_state is
                    -- Idle until frame start sequence is detected
                    when IDLE =>
                        if (pass_data = '1') then
                            -- Frame start is valid go to next state
                            din.en          <= '0';
                            frame_start     <= (others => '0');
                            get_length_cnt  <= to_unsigned(START_SEQ_SIZE, get_length_cnt'length);
                            decode_state    <= GET_LENGTH;
                        elsif (data_valid = '1') then
                            -- Shift in new byte
                            frame_start <= frame_start((frame_start'left - din.data'length) downto 0) & din.data;
                        end if;
                    -- Get length field from frame
                    when GET_LENGTH => 
                        if (data_valid = '1') then
                            if (get_length_cnt = LENGTH_OFFSET) then
                                -- Store upper 8 bits of frame length
                                frame_length(15 downto 8) <= unsigned(din.data);
                            elsif (get_length_cnt = LENGTH_OFFSET + 1) then
                                -- Store lower 8 bits of frame length / go to next state
                                frame_length(7 downto 0)    <= unsigned(din.data);
                                din.en                      <= '0';
                                decode_state                <= WAIT_FOR_PAYLOAD_END;
                            end if;
                            get_length_cnt <= get_length_cnt + 1;
                        end if;
                    -- Wait for frame payload to end
                    when WAIT_FOR_PAYLOAD_END =>
                        if (data_valid = '1') then
                            if (frame_length > to_unsigned(MIN_FRAME_SIZE, frame_length'length) - 1) then
                                if (payload_end_cnt = frame_length - 1) then
                                    payload_end_cnt <= (others => '0');
                                    din.en          <= '0';
                                    decode_state    <= WAIT_FOR_FCS_END;
                                end if;
                            else
                                if (payload_end_cnt = to_unsigned(MIN_FRAME_SIZE, payload_end_cnt'length) - 1) then
                                    payload_end_cnt <= (others => '0');
                                    din.en          <= '0';
                                    decode_state    <= WAIT_FOR_FCS_END;
                                end if;
                            end if;
                            payload_end_cnt <= payload_end_cnt + 1;
                        end if;
                    -- Wait for frame check sequence to end 
                    when WAIT_FOR_FCS_END =>
                        if (data_valid = '1') then
                            fcs_end_cnt <= fcs_end_cnt + 1;
                            if (fcs_end_cnt = FCS_SIZE - 1) then
                                fcs_end_cnt     <= (others => '0');
                                din.en          <= '0';
                                decode_state    <= IDLE;
                            end if;
                        end if;
                    -- Bad state go back to IDLE
                    when others =>
                        decode_state <= IDLE;
                end case;
            end if;
        end if;
    end process decode_proc;

end architecture rtl;