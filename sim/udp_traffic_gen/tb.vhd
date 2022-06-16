library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library nic;

entity tb is
end entity tb;

architecture rtl of tb is

    signal clk                 : std_logic;
    signal rst                 : std_logic;
    signal send_pkt            : std_logic;
    signal rst_cur_row         : std_logic;
    -- AXI Data Stream Slave
    signal s_axis_tdata        : std_logic_vector(7 downto 0);
    signal s_axis_tvalid       : std_logic;
    signal s_axis_tready       : std_logic;
    -- AXI Data Stream Master
    signal m_axis_tdata        : std_logic_vector(7 downto 0);
    signal m_axis_tstrb        : std_logic_vector(0 downto 0);
    signal m_axis_tvalid       : std_logic;
    signal m_axis_tready       : std_logic;
    signal m_axis_tlast        : std_logic;

begin

    udp_traffic_gen_inst : entity nic.udp_traffic_gen(rtl)
        port map (
            clk                 => clk,
            rst                 => rst,
            send_pkt            => send_pkt,
            rst_cur_row         => rst_cur_row,
            -- AXI Data Stream Slave
            s_axis_tdata        => s_axis_tdata,
            s_axis_tvalid       => s_axis_tvalid,
            s_axis_tready       => s_axis_tready,
            -- AXI Data Stream Master
            m_axis_tdata        => m_axis_tdata,
            m_axis_tstrb        => m_axis_tstrb,
            m_axis_tvalid       => m_axis_tvalid,
            m_axis_tready       => m_axis_tready,
            m_axis_tlast        => m_axis_tlast
        );

end architecture rtl;