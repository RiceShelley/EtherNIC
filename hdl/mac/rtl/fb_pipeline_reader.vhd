library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library comp;
use comp.math_pack.all;

library mac;
use mac.MAC_pack.all;
use mac.eth_pack.all;

entity fb_pipeline_reader is
    generic (
        PIPELINE_ELEM_CNT : natural := 2
    );
    port (
        clk                 : in std_logic;
        ready_in            : in std_logic_vector(PIPELINE_ELEM_CNT - 1 downto 0);
        tx_busy_in          : in std_logic;
        -- AXI Data Stream Slave
        s_axis_tdata        : in t_axis_data_array(PIPELINE_ELEM_CNT - 1 downto 0);
        s_axis_tvalid       : in std_logic_vector(PIPELINE_ELEM_CNT - 1 downto 0);
        s_axis_tready       : out std_logic_vector(PIPELINE_ELEM_CNT - 1 downto 0);
        -- AXI Data Stream Master
        m_axis_tdata        : out std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
        m_axis_tvalid       : out std_logic;
        m_axis_tready       : in std_logic
    );
end entity fb_pipeline_reader;

architecture rtl of fb_pipeline_reader is

    signal rd_addr : unsigned(clog2(PIPELINE_ELEM_CNT) - 1 downto 0) := (others => '0');
    signal pipe_ready : std_logic;

    type t_rstate is (IDLE, BUSY, WAIT_FOR_PHY);
    signal rstate : t_rstate := IDLE;

    signal tx_busy_buff : std_logic_vector(1 downto 0) := (others => '0');
    signal phy_done : std_logic;

begin

    m_axis_tdata    <= s_axis_tdata(to_integer(rd_addr));
    m_axis_tvalid   <= '1' when (s_axis_tvalid(to_integer(rd_addr)) = '1' and rstate = BUSY) else '0';

    -- Pass m_axis_tready to current slave when rstate is busy
    s_tready_proc : process(rd_addr, m_axis_tready, rstate) begin
        for i in 0 to PIPELINE_ELEM_CNT - 1 loop
            s_axis_tready(i) <= '0';
            if (i = to_integer(rd_addr) and rstate = BUSY) then
                s_axis_tready(i) <= m_axis_tready;
            end if;
        end loop;
    end process s_tready_proc;

    ------------------------------------------------------------
    -- Frame buffer pipeline reader FSM
    ------------------------------------------------------------
    read_data_fsm_proc : process(clk) begin
        if rising_edge(clk) then
            case rstate is
                when IDLE =>
                    if (ready_in(to_integer(rd_addr)) = '1' and s_axis_tvalid(to_integer(rd_addr)) = '1') then
                        rstate <= BUSY;
                    end if;
                when BUSY => 
                    if (s_axis_tvalid(to_integer(rd_addr)) = '0') then
                        if (rd_addr /= PIPELINE_ELEM_CNT - 1) then
                            rd_addr <= rd_addr + 1;
                        else
                            rd_addr <= (others => '0');
                        end if;
                        rstate <= WAIT_FOR_PHY;
                    end if;
                when WAIT_FOR_PHY =>
                    if (phy_done = '1') then
                        rstate <= IDLE;
                    end if;
                when others =>
                    rstate <= IDLE;
            end case;
        end if;
    end process read_data_fsm_proc;

    ------------------------------------------------------------
    -- Drive PHY done signal
    -- Desc: Falling edge of tx_busy indicates that the
    -- PHY is done and we can write another packet 
    ------------------------------------------------------------
    phy_done <= '1' when (tx_busy_buff = "10") else '0';
    phy_done_proc : process(clk) begin
        if rising_edge(clk) then
            tx_busy_buff <= tx_busy_buff(tx_busy_buff'left - 1 downto 0) & tx_busy_in;
        end if;
    end process phy_done_proc;

end architecture rtl;