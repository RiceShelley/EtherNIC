library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.MAC_pack.all;
use work.eth_pack.all;

entity MAC_tx_pipeline is 
    generic (
        AXIS_DATA_WIDTH : natural := 8;
        AXIS_STRB_WIDTH : natural := 1;
        PIPELINE_ELEM_CNT : natural := 2
    );
    port (
        clk                 : in std_logic;
        rst                 : in std_logic;
        tx_busy_in          : in std_logic;
        -- Axi Data Stream Slave
        s_axis_tdata        : in std_logic_vector(AXIS_DATA_WIDTH - 1 downto 0);
        s_axis_tstrb        : in std_logic_vector(AXIS_STRB_WIDTH - 1 downto 0);
        s_axis_tvalid       : in std_logic;
        s_axis_tready       : out std_logic;
        s_axis_tlast        : in std_logic;
        -- AXI Data Stream Master
        m_axis_tdata        : out std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
        m_axis_tvalid       : out std_logic;
        m_axis_tready       : in std_logic
    );
end entity MAC_tx_pipeline;

architecture rtl of MAC_tx_pipeline is

    signal fpb_in_axis_tdata    : t_axis_data_array(PIPELINE_ELEM_CNT - 1 downto 0);
    signal fpb_in_axis_tvalid   : std_logic_vector(PIPELINE_ELEM_CNT - 1 downto 0);
    signal fpb_in_axis_tready   : std_logic_vector(PIPELINE_ELEM_CNT - 1 downto 0);
    signal fpb_in_axis_tlast    : std_logic_vector(PIPELINE_ELEM_CNT - 1 downto 0);

    signal fpb_out_axis_tdata   : t_axis_data_array(PIPELINE_ELEM_CNT - 1 downto 0);
    signal fpb_out_axis_tvalid  : std_logic_vector(PIPELINE_ELEM_CNT - 1 downto 0);
    signal fpb_out_axis_tready  : std_logic_vector(PIPELINE_ELEM_CNT - 1 downto 0);

    signal empty        : std_logic_vector(PIPELINE_ELEM_CNT - 1 downto 0);
    signal frame_ready  : std_logic_vector(PIPELINE_ELEM_CNT - 1 downto 0);

    signal skid_m_axis_tdata    : std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
    signal skid_m_axis_tvalid   : std_logic;
    signal skid_m_axis_tready   : std_logic;
begin

    ---------------------------------------------------------------
    -- Frame Builder Pipeline Writer
    ---------------------------------------------------------------
    empty <= not fpb_out_axis_tvalid;
    fb_pipeline_writer_inst : entity work.fb_pipeline_writer(rtl)
    generic map (
        PIPELINE_ELEM_CNT => PIPELINE_ELEM_CNT
    ) port map (
        clk             => clk,
        rst             => rst,
        empty_in        => empty,
        -- AXI Data Stream Slave
        s_axis_tdata    => s_axis_tdata,
        s_axis_tstrb    => s_axis_tstrb,
        s_axis_tvalid   => s_axis_tvalid,
        s_axis_tready   => s_axis_tready,
        s_axis_tlast    => s_axis_tlast,
        -- AXI Data Stream Master
        m_axis_tdata    => fpb_in_axis_tdata,
        m_axis_tvalid   => fpb_in_axis_tvalid,
        m_axis_tready   => fpb_in_axis_tready,
        m_axis_tlast    => fpb_in_axis_tlast
    );

    ---------------------------------------------------------------
    -- Frame builder pipes
    ---------------------------------------------------------------
    gen_fb_pipes : for i in 0 to PIPELINE_ELEM_CNT - 1 generate
        frame_builder_pipe_inst : entity work.frame_builder_pipe(rtl)
        port map (
            clk                 => clk,
            rst                 => rst,
            frame_ready_out     => frame_ready(i),
            -- AXI Data Stream Slave
            s_axis_tdata    => fpb_in_axis_tdata(i),
            s_axis_tvalid   => fpb_in_axis_tvalid(i),
            s_axis_tready   => fpb_in_axis_tready(i),
            s_axis_tlast    => fpb_in_axis_tlast(i),
            -- AXI Data Stream Master
            m_axis_tdata    => fpb_out_axis_tdata(i),
            m_axis_tvalid   => fpb_out_axis_tvalid(i),
            m_axis_tready   => fpb_out_axis_tready(i)
        );
    end generate gen_fb_pipes;

    ---------------------------------------------------------------
    -- Frame Builder Pipeline Reader
    ---------------------------------------------------------------
    fb_pipeline_reader : entity work.fb_pipeline_reader(rtl)
    generic map (
        PIPELINE_ELEM_CNT => PIPELINE_ELEM_CNT
    ) port map (
        clk             => clk,
        ready_in        => frame_ready,
        tx_busy_in      => tx_busy_in,
        -- AXI Data Stream Slave
        s_axis_tdata    => fpb_out_axis_tdata,
        s_axis_tvalid   => fpb_out_axis_tvalid,
        s_axis_tready   => fpb_out_axis_tready,
        -- AXI Data Stream Master
        m_axis_tdata    => skid_m_axis_tdata,
        m_axis_tvalid   => skid_m_axis_tvalid,
        m_axis_tready   => skid_m_axis_tready
    );

    tx_pipe_out_skid : entity work.skid_buffer(rtl)
    generic map (
        DATA_WIDTH      => m_axis_tdata'length
    ) port map (
        clk             => clk,
        clr             => rst,
        input_valid     => skid_m_axis_tvalid,
        input_ready     => skid_m_axis_tready,
        input_data      => skid_m_axis_tdata,
        output_valid    => m_axis_tvalid,
        output_ready    => m_axis_tready,
        output_data     => m_axis_tdata
    );

end architecture rtl;