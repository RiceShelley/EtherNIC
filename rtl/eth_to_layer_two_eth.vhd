library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.MAC_pack.all;

entity eth_to_layer_two_eth is
    port (
        clk         : in std_logic;
        rst         : in std_logic;
        pkt_start   : out std_logic;
        din         : inout t_SPH;
        dout        : inout t_SPH
    );
end entity eth_to_layer_two_eth;

architecture rtl of eth_to_layer_two_eth is
    constant ETH_FRAME_START_SEQ_SIZE   : natural := 8 * 8;
    constant ETH_FRAME_START_SEQ        : std_logic_vector(ETH_FRAME_START_SEQ_SIZE - 1 downto 0) := X"55555555555555D5";
    constant ETH_PKT_LENGTH_OFFSET      : natural := 16;
    constant ETH_LENGTH_WIDTH           : natural := 8 * 2;
    constant MIN_ETH_SIZE               : natural := 42;
    constant FCS_LENGTH                 : natural := 4;

    signal read_input       : std_logic;
    signal pass_data        : std_logic;
    signal eth_frame_data   : std_logic_vector(ETH_FRAME_START_SEQ_SIZE - 1 downto 0);

    type decode_fsm_t is (IDLE, GET_LENGTH, WAIT_FOR_PAYLOAD_END, WAIT_FOR_FCS_END);
    signal decode_state : decode_fsm_t := IDLE;

    signal pkt_length_offset_cnt : unsigned(15 downto 0) := (others => '0');
    signal pkt_length : unsigned(15 downto 0);

    signal pkt_length_cnt : unsigned(8 * 2 - 1 downto 0) := (others => '0');

    signal fcs_length_cnt : unsigned(8 * 2 - 1 downto 0) := (others => '0');

begin

    ------------------------
    -- TODO: clean this up
    ------------------------

    dout.data <= din.data when (pass_data = '1') else (others => '0');
    dout.en <= din.consent and din.en and pass_data;
    dout.consent <= '0';

    pass_data <= '1' when (eth_frame_data = ETH_FRAME_START_SEQ or decode_state /= IDLE) else '0';
    pkt_start <= '1' when (eth_frame_data = ETH_FRAME_START_SEQ) else '0';

    read_input <= din.consent and din.en;

    recv_proc : process(clk) begin
        if rising_edge(clk) then
            if rst /= '0' then
                din.en <= '0';
                eth_frame_data          <= (others => '0');
                pkt_length_offset_cnt   <= (others => '0');
                pkt_length_cnt          <= (others => '0');
                fcs_length_cnt          <= (others => '0');
            else
                din.en <= '1';
                case decode_state is
                    when IDLE =>
                        if pass_data = '1' then
                            eth_frame_data <= (others => '0');
                            din.en <= '0';
                            decode_state <= GET_LENGTH;
                        elsif read_input = '1' then
                            eth_frame_data <= eth_frame_data(eth_frame_data'left - din.data'length downto 0) & din.data;
                        end if;
                    when GET_LENGTH => 
                        if read_input = '1' then
                            pkt_length_offset_cnt <= pkt_length_offset_cnt + 1;
                            if (pkt_length_offset_cnt = ETH_PKT_LENGTH_OFFSET) then
                                pkt_length(15 downto 8) <= unsigned(din.data);
                            elsif (pkt_length_offset_cnt = ETH_PKT_LENGTH_OFFSET + 1) then
                                pkt_length(7 downto 0) <= unsigned(din.data);
                                pkt_length_offset_cnt <= (others => '0');
                                din.en <= '0';
                                decode_state <= WAIT_FOR_PAYLOAD_END;
                            end if;
                        end if;
                    when WAIT_FOR_PAYLOAD_END =>
                        if read_input = '1' then
                            pkt_length_cnt <= pkt_length_cnt + 1;
                            if pkt_length > to_unsigned(MIN_ETH_SIZE, pkt_length'length) - 1 then
                                if pkt_length_cnt = pkt_length - 1 then
                                    pkt_length_cnt <= (others => '0');
                                    din.en <= '0';
                                    decode_state <= WAIT_FOR_FCS_END;
                                end if;
                            else
                                if pkt_length_cnt = to_unsigned(MIN_ETH_SIZE, pkt_length_cnt'length) - 1 then
                                    pkt_length_cnt <= (others => '0');
                                    din.en <= '0';
                                    decode_state <= WAIT_FOR_FCS_END;
                                end if;
                            end if;
                        end if;
                    when WAIT_FOR_FCS_END =>
                        if read_input = '1' then
                            fcs_length_cnt <= fcs_length_cnt + 1;
                            if fcs_length_cnt = FCS_LENGTH - 1 then
                                fcs_length_cnt <= (others => '0');
                                din.en <= '0';
                                decode_state <= IDLE;
                            end if;
                        end if;
                    when others =>
                        decode_state <= IDLE;
                end case;
            end if;
        end if;
    end process recv_proc;

end architecture rtl;