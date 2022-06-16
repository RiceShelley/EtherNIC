library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library comp;
use comp.math_pack.all;

library mac;
use mac.MAC_pack.all;
use mac.eth_pack.all;

entity fb_pipeline_writer is
    generic (
        PIPELINE_ELEM_CNT : natural := 2
    );
    port (
        clk                 : in std_logic;
        rst                 : in std_logic;
        empty_in            : in std_logic_vector(PIPELINE_ELEM_CNT - 1 downto 0);
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

    type t_axis_fsm is (IDLE, NEXT_PIPE);
    signal axis_state : t_axis_fsm := IDLE;

    signal wr_addr : unsigned(clog2(PIPELINE_ELEM_CNT) - 1 downto 0) := (others => '0');

begin

    -------------------------------------------------------------
    -- Route AXI signals
    -------------------------------------------------------------
    s_axis_tready <= m_axis_tready(to_integer(wr_addr)) when (axis_state = IDLE) else '0';
    dout_proc : process(s_axis_tdata, s_axis_tstrb, s_axis_tvalid, s_axis_tlast, m_axis_tready, wr_addr, axis_state) begin
        for i in 0 to PIPELINE_ELEM_CNT - 1 loop
            if (i = to_integer(wr_addr)) then
                m_axis_tdata(i)     <= s_axis_tdata;
                m_axis_tlast(i)     <= s_axis_tlast;
                if (axis_state = IDLE) then
                    m_axis_tvalid(i)    <= s_axis_tvalid;
                else
                    m_axis_tvalid(i)    <= '0';
                end if;
            else
                m_axis_tdata(i)     <= (others => '0');
                m_axis_tlast(i)     <= '0';
                m_axis_tvalid(i)    <= '0';
            end if;
        end loop;
    end process dout_proc;

    -------------------------------------------------------------
    -- AXI Stream FSM proc
    -------------------------------------------------------------
    axi_stream_proc : process(clk) begin
        if rising_edge(clk) then
            if (rst /= '0') then
                wr_addr     <= (others => '0');
                axis_state  <= IDLE;
            else
                case axis_state is
                when IDLE =>
                    if (s_axis_tvalid = '1' and s_axis_tlast = '1') then
                        if (wr_addr /= (PIPELINE_ELEM_CNT - 1)) then
                            wr_addr <= wr_addr + 1;
                        else
                            wr_addr <= (others => '0');
                        end if;
                        axis_state <= NEXT_PIPE;
                    end if;
                when NEXT_PIPE =>
                    -- Wait for pipe to become available
                    if (empty_in(to_integer(wr_addr)) = '1') then
                        axis_state <= IDLE;
                    end if;
                when others =>
                    axis_state <= IDLE;
                end case;
            end if;
        end if;
    end process axi_stream_proc;

end architecture rtl;