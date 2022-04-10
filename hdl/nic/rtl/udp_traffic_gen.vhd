library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity udp_traffic_gen is
    port (
        clk                 : in std_logic;
        rst                 : in std_logic;
        send_pkt            : in std_logic;
        -- AXI Data Stream Slave
        --m_axis_tdata        : in std_logic_vector(7 downto 0);
        --m_axis_tvalid       : in std_logic;
        --m_axis_tready       : out std_logic;
        -- AXI Data Stream Master
        s_axis_tdata        : out std_logic_vector(7 downto 0);
        s_axis_tstrb        : out std_logic_vector(0 downto 0);
        s_axis_tvalid       : out std_logic;
        s_axis_tready       : in std_logic;
        s_axis_tlast        : out std_logic
    );
end entity udp_traffic_gen;

architecture rtl of udp_traffic_gen is
    constant PKT_HEADER_LEN     : natural := 42;
    constant PKT_MAX_LEN        : natural := 128;
    constant MAC_HEADER_LEN     : natural := 14;
    constant IPV4_HEADER_LEN    : natural := 20;
    constant IPV4_LENGTH        : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(PKT_MAX_LEN - MAC_HEADER_LEN, 16));
    constant UDP_LENGTH         : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(PKT_MAX_LEN - MAC_HEADER_LEN - IPV4_HEADER_LEN, 16));

    type lvec_array_t is array(natural range <>) of std_logic_vector(7 downto 0);

    constant PKT_HEADER_ROM : lvec_array_t(0 to PKT_HEADER_LEN - 1) := (
        x"2c", x"56", x"dc", x"9a", x"ee", x"60",                               -- ETH DST MAC addr
        x"ca", x"fe", x"be", x"ef", x"ba", x"be",                               -- ETH SRC MAC addr 
        x"08", x"00",                                                           -- ETH Type
        x"45",                                                                  -- IPV4 ver / header length
        x"00",                                                                  -- IPV4 Type of service
        IPV4_LENGTH(15 downto 8), IPV4_LENGTH(7 downto 0),                      -- IPV4 datagram length
        x"00", x"01",                                                           -- IPV4 16-bit identifier
        x"00", x"00",                                                           -- IPV4 flags / 13-bit frag offset
        x"40",                                                                  -- IPV4 TTL
        x"11",                                                                  -- IPV4 Upper layer proto
        x"f7", x"52",                                                           -- IPV4 Header checksum
        x"c0", x"a8", x"01", x"2b",                                             -- IPV4 32-bit Source IP address
        x"c0", x"a8", x"01", x"02",                                             -- IPV4 32-bit Destination IP address
        x"10", x"fa",                                                           -- UDP Source port
        x"1a", x"85",                                                           -- UDP Dest port
        UDP_LENGTH(15 downto 8), UDP_LENGTH(7 downto 0),                        -- UDP length
        x"00", x"00"                                                            -- UDP checksum
    );

    type tgen_state_t is (IDLE, SEND_HEADER, SEND_DATA);
    signal state : tgen_state_t := IDLE;

    signal cur_byte : natural := 0;
    signal s_axis_tvalid_r : std_logic;
    
    signal data : unsigned(7 downto 0) := (others => '0');
begin
    s_axis_tvalid <= s_axis_tvalid_r;
    s_axis_tstrb <= (others => '1');

    fsm_proc : process(clk) begin
        if rising_edge(clk) then
            s_axis_tvalid_r <= '0';
            s_axis_tlast <= '0';
            if rst = '1' then
                state <= IDLE;
                cur_byte <= 0;
            else
                case state is
                    when IDLE =>
                        cur_byte <= 0;
                        if send_pkt = '1' then
                            state <= SEND_HEADER;
                            s_axis_tdata <= PKT_HEADER_ROM(cur_byte);
                            s_axis_tvalid_r <= '1';
                            cur_byte <= cur_byte + 1;
                        end if;
                    when SEND_HEADER =>
                        s_axis_tvalid_r <= '1';
                        if cur_byte /= PKT_HEADER_LEN - 1 then
                            if s_axis_tready = '1' and s_axis_tvalid_r = '1' then
                                s_axis_tdata <= PKT_HEADER_ROM(cur_byte);
                                cur_byte <= cur_byte + 1;
                            end if;
                        else
                            if s_axis_tready = '1' and s_axis_tvalid_r = '1' then
                                cur_byte <= cur_byte + 1;
                                s_axis_tdata <= PKT_HEADER_ROM(cur_byte);
                                state <= SEND_DATA;
                            end if;
                        end if;
                    when SEND_DATA =>
                        if cur_byte /= PKT_MAX_LEN - 1 then
                            s_axis_tvalid_r <= '1';
                            if s_axis_tready = '1' and s_axis_tvalid_r = '1' then
                                data <= data + 1;
                                s_axis_tdata <= std_logic_vector(data);
                                cur_byte <= cur_byte + 1;
                            end if;
                        else
                            s_axis_tdata <= std_logic_vector(data);
                            s_axis_tvalid_r <= '1';
                            s_axis_tlast <= '1';
                            state <= IDLE;
                        end if;
                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process fsm_proc;

end architecture rtl;