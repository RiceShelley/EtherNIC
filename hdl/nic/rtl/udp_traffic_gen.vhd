library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity udp_traffic_gen is
    port (
        clk                 : in std_logic;
        rst                 : in std_logic;
        send_pkt            : in std_logic;
        rst_cur_row         : in std_logic;
        -- AXI Data Stream Slave
        s_axis_tdata        : in std_logic_vector(7 downto 0);
        s_axis_tvalid       : in std_logic;
        s_axis_tready       : out std_logic;
        -- AXI Data Stream Master
        m_axis_tdata        : out std_logic_vector(7 downto 0);
        m_axis_tstrb        : out std_logic_vector(0 downto 0);
        m_axis_tvalid       : out std_logic;
        m_axis_tready       : in std_logic;
        m_axis_tlast        : out std_logic
    );
end entity udp_traffic_gen;

architecture rtl of udp_traffic_gen is
    constant PKT_HEADER_LEN     : natural := 42;
    constant ROW_TAG            : natural := 2;
    constant PKT_MAX_LEN        : natural := 1280 + PKT_HEADER_LEN + ROW_TAG;
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
        x"f2", x"50",                                                           -- IPV4 Header checksum
        x"c0", x"a8", x"01", x"2b",                                             -- IPV4 32-bit Source IP address
        x"c0", x"a8", x"01", x"02",                                             -- IPV4 32-bit Destination IP address
        x"10", x"fa",                                                           -- UDP Source port
        x"1a", x"85",                                                           -- UDP Dest port
        UDP_LENGTH(15 downto 8), UDP_LENGTH(7 downto 0),                        -- UDP length
        x"00", x"00"                                                            -- UDP checksum
    );

    type tgen_state_t is (IDLE, SEND_HEADER, SEND_ROW_TAG_B1, SEND_ROW_TAG_B2, SEND_DATA);
    signal state : tgen_state_t := IDLE;

    signal cur_byte : natural := 0;
    signal m_axis_tvalid_r : std_logic;
    
    signal data : unsigned(7 downto 0) := (others => '0');
    signal s_axis_tready_r : std_logic;
    signal cur_row : unsigned(15 downto 0) := (others => '0');
begin
    m_axis_tvalid <= m_axis_tvalid_r;
    m_axis_tstrb <= (others => '1');
    s_axis_tready <= s_axis_tready_r;

    fsm_proc : process(clk) begin
        if rising_edge(clk) then
            m_axis_tvalid_r <= '0';
            m_axis_tlast <= '0';
            s_axis_tready_r <= '0';
            if rst = '1' then
                state <= IDLE;
                cur_byte <= 0;
            else
                case state is
                    when IDLE =>
                        cur_byte <= 0;
                        if send_pkt = '1' then
                            state <= SEND_HEADER;
                            m_axis_tdata <= PKT_HEADER_ROM(cur_byte);
                            m_axis_tvalid_r <= '1';
                            cur_byte <= cur_byte + 1;
                        end if;
                    when SEND_HEADER =>
                        m_axis_tvalid_r <= '1';
                        if cur_byte /= PKT_HEADER_LEN - 1 then
                            if m_axis_tready = '1' and m_axis_tvalid_r = '1' then
                                m_axis_tdata <= PKT_HEADER_ROM(cur_byte);
                                cur_byte <= cur_byte + 1;
                            end if;
                        else
                            if m_axis_tready = '1' and m_axis_tvalid_r = '1' then
                                cur_byte <= cur_byte + 1;
                                m_axis_tdata <= PKT_HEADER_ROM(cur_byte);
                                state <= SEND_ROW_TAG_B1;
                            end if;
                        end if;
                    when SEND_ROW_TAG_B1 =>
                        m_axis_tvalid_r <= '1';
                        if m_axis_tready = '1' and m_axis_tvalid_r = '1' then
                            m_axis_tdata <= std_logic_vector(cur_row(15 downto 8));
                            cur_byte <= cur_byte + 1;
                            state <= SEND_ROW_TAG_B2;
                        end if;
                    when SEND_ROW_TAG_B2 =>
                        m_axis_tvalid_r <= '1';
                        if m_axis_tready = '1' and m_axis_tvalid_r = '1' then
                            cur_byte <= cur_byte + 1;
                            m_axis_tdata <= std_logic_vector(cur_row(7 downto 0));
                            cur_row <= cur_row + 1;
                            s_axis_tready_r <= '1';
                            state <= SEND_DATA;
                        end if;
                    when SEND_DATA =>
                        m_axis_tdata <= s_axis_tdata;
                        if cur_byte /= PKT_MAX_LEN then
                            m_axis_tvalid_r <= s_axis_tvalid;
                            s_axis_tready_r <= m_axis_tready;
                            if (m_axis_tready = '1' and m_axis_tvalid_r = '1') then
                                cur_byte <= cur_byte + 1;

                            end if;
                        else
                            m_axis_tvalid_r <= s_axis_tvalid;
                            s_axis_tready_r <= m_axis_tready;
                            m_axis_tlast <= m_axis_tready and s_axis_tvalid;
                            if (m_axis_tready = '1' and m_axis_tvalid_r = '1') then
                                cur_byte <= cur_byte + 1;
                                state <= IDLE;
                            end if;
                        end if;
                    when others =>
                        state <= IDLE;
                end case;
            end if;
            if (rst_cur_row = '1') then
                cur_row <= (others => '0');
            end if;
        end if;
    end process fsm_proc;

end architecture rtl;