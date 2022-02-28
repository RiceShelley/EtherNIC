library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.MAC_pack.all;
use work.eth_pack.all;
use work.math_pack.all;

entity fb_pipeline_writer is
    generic (
        PIPELINE_ELEM_CNT : natural := 2
    );
    port (
        clk                 : in std_logic;
        rst                 : in std_logic;
        -- AXI Data Stream Slave
        s_axis_tdata        : in std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
        s_axis_tstrb        : in std_logic_vector(MAC_AXIS_STRB_WIDTH - 1 downto 0);
        s_axis_tvalid       : in std_logic;
        s_axis_tready       : out std_logic;
        s_axis_tlast        : in std_logic;
        -- AXI Data Stream Master
        m_axis_tdata        : out t_axis_data_array(PIPELINE_ELEM_CNT - 1 downto 0);
        m_axis_tvalid       : out std_logic_vector(PIPELINE_ELEM_CNT - 1 downto 0);
        m_axis_tready       : in std_logic_vector(PIPELINE_ELEM_CNT - 1 downto 0);
        m_axis_tlast        : out std_logic_vector(PIPELINE_ELEM_CNT - 1 downto 0)
    );
end entity fb_pipeline_writer;

architecture rtl of fb_pipeline_writer is

    signal wr_addr : unsigned(clog2(PIPELINE_ELEM_CNT) - 1 downto 0) := (others => '0');

begin

    dout_proc : process(s_axis_tdata, s_axis_tstrb, s_axis_tvalid, s_axis_tlast, m_axis_tready, wr_addr) begin
        for i in 0 to PIPELINE_ELEM_CNT - 1 loop
            if (i = to_integer(wr_addr)) then
                m_axis_tdata(i)     <= s_axis_tdata;
                m_axis_tvalid(i)    <= s_axis_tvalid;
                m_axis_tlast(i)     <= s_axis_tlast;
            else
                m_axis_tdata(i)     <= (others => '0');
                m_axis_tvalid(i)    <= '0';
                m_axis_tlast(i)     <= '0';
            end if;
        end loop;
    end process dout_proc;

    s_axis_tready <= '1';

    axi_stream_proc : process(clk) begin
        if rising_edge(clk) then
            if (rst /= '0') then
                wr_addr <= (others => '0');
            else
                if (s_axis_tvalid = '1' and s_axis_tlast = '1') then
                    if (wr_addr /= (PIPELINE_ELEM_CNT - 1)) then
                        wr_addr <= wr_addr + 1;
                    else
                        wr_addr <= (others => '0');
                    end if;
                end if;
            end if;
        end if;
    end process axi_stream_proc;

end architecture rtl;