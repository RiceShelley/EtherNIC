library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library mac;
use mac.MAC_pack.all;
use mac.eth_pack.all;

entity MAC_rx_mtr_axis is
    port (
        clk                 : in std_logic;
        trans_packet_in     : in std_logic;
        pkt_length_in       : in unsigned(LENGTH_WIDTH - 1 downto 0);
        -- AXI Stream Slave
        s_axis_tdata        : in std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
        s_axis_tvalid       : in std_logic;
        s_axis_tready       : out std_logic;
        -- Axi Data Stream
        m_axis_tdata        : out std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
        m_axis_tstrb        : out std_logic_vector(MAC_AXIS_STRB_WIDTH - 1 downto 0);
        m_axis_tvalid       : out std_logic;
        m_axis_tready       : in std_logic;
        m_axis_tlast        : out std_logic
    );
end entity MAC_rx_mtr_axis;

architecture rtl of MAC_rx_mtr_axis is

    type axis_fsm_state_t is (IDLE, STREAM);
    signal axis_state : axis_fsm_state_t := IDLE;

    signal pkt_length : unsigned(LENGTH_WIDTH - 1 downto 0);
    signal bytes_sent : unsigned(LENGTH_WIDTH - 1 downto 0);

begin

    m_axis_tstrb <= (others => '1');
    m_axis_tdata <= s_axis_tdata;

    axis_mtr_proc : process (clk) begin
        if (rising_edge(clk)) then
            m_axis_tvalid   <= '0';
            m_axis_tlast    <= '0';
            s_axis_tready   <= '0';
            case axis_state is
                when IDLE =>
                    if (trans_packet_in = '1') then
                        bytes_sent <= (others => '0');
                        pkt_length <= pkt_length_in;
                        axis_state <= STREAM;
                    end if;
                when STREAM =>
                    if (bytes_sent /= pkt_length) then
                        if (bytes_sent = pkt_length - 1) then
                            m_axis_tlast <= '1';
                        end if;
                        m_axis_tvalid   <= '1';
                        s_axis_tready   <= '1';
                        bytes_sent      <= bytes_sent + 1;
                    else
                        axis_state <= IDLE;
                    end if;
                when others =>
                    axis_state <= IDLE;
            end case;
        end if;
    end process axis_mtr_proc;

end architecture rtl;