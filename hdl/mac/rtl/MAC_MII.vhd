library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.MAC_pack.all;
use work.eth_pack.all;

entity MAC_MII is
    generic (
        TX_UNFOLD_CNT       : natural := 2;
        ITR_WIDTH           : natural := 16;
        DATA_WIDTH          : natural := 32;
        ADDR_WIDTH          : natural := 32;
        STRB_WIDTH          : natural := 32 / 8;
        RESP_WIDTH          : natural := 2);
    port (
        clk                     : in std_logic;
        rst                     : in std_logic;
        interrupts              : out std_logic_vector(ITR_WIDTH - 1 downto 0);
        ---------------------------------------
        -- AXI Lite Slave 
        ---------------------------------------
        s_axi_aresetn           : in std_logic;
        -- Read Address Channel
        s_axi_araddr            : in std_logic_vector(ADDR_WIDTH - 1 downto 0);
        s_axi_arvalid           : in std_logic;
        s_axi_arready           : out std_logic;
        -- Read Data Channel
        s_axi_rdata             : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        s_axi_rresp             : out std_logic_vector(RESP_WIDTH - 1 downto 0);
        s_axi_rvalid            : out std_logic;
        s_axi_rready            : in std_logic;
        -- Write Address Channel 
        s_axi_awaddr            : in std_logic_vector(ADDR_WIDTH - 1 downto 0);
        s_axi_awvalid           : in std_logic;
        s_axi_awready           : out std_logic;
        -- Write Data Channel
        s_axi_wvalid            : in std_logic;
        s_axi_wdata             : in std_logic_vector(DATA_WIDTH - 1 downto 0);
        s_axi_wstrb             : in std_logic_vector(STRB_WIDTH - 1 downto 0);
        s_axi_wready            : out std_logic;
        -- Write Response Channel 
        s_axi_bresp             : out std_logic_vector(RESP_WIDTH - 1 downto 0);
        s_axi_bvalid            : out std_logic;
        s_axi_bready            : in std_logic;
        ---------------------------------------
        -- AXI RX Data Stream 
        ---------------------------------------
        rx_m_axis_tdata         : out std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
        rx_m_axis_tstrb         : out std_logic_vector(MAC_AXIS_STRB_WIDTH - 1 downto 0);
        rx_m_axis_tvalid        : out std_logic;
        rx_m_axis_tready        : in std_logic;
        rx_m_axis_tlast         : out std_logic;
        ---------------------------------------
        -- AXI TX Data Stream 
        ---------------------------------------
        tx_s_axis_tdata         : in std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
        tx_s_axis_tstrb         : in std_logic_vector(MAC_AXIS_STRB_WIDTH - 1 downto 0);
        tx_s_axis_tvalid        : in std_logic;
        tx_s_axis_tready        : out std_logic;
        tx_s_axis_tlast         : in std_logic;
        ---------------------------------------
        -- PHY MDIO signals
        ---------------------------------------
        mdio_mdc_out            : out std_logic;
        mdio_data_out           : out std_logic;
        mdio_data_in            : in std_logic;
        mdio_data_tri           : out std_logic;
        ---------------------------------------
        -- MII PHY interface
        ---------------------------------------
        mii_tx_clk              : in std_logic;
        mii_tx_en               : out std_logic := '0';
        mii_tx_er               : out std_logic := '0';
        mii_tx_data             : out std_logic_vector(3 downto 0) := (others => '0');
        mii_rx_clk              : in std_logic;
        mii_rx_en               : in std_logic;
        mii_rx_er               : in std_logic;
        mii_rx_data             : in std_logic_vector(3 downto 0);
        mii_rst_phy             : out std_logic := '0'
    );
end entity MAC_MII;

architecture rtl of MAC_MII is
    ---------------------------
    -- Phy interface signals
    ---------------------------
    signal tx_busy : std_logic;
    signal rx_done : std_logic;

    signal rx_pipe_axis_tdata   : std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
    signal rx_pipe_axis_tvalid  : std_logic;
    signal rx_pipe_axis_tready  : std_logic;

    signal tx_pipe_axis_tdata   : std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
    signal tx_pipe_axis_tvalid  : std_logic;
    signal tx_pipe_axis_tready  : std_logic;

begin
    ------------------------------------------------------------------
    -- RX pipeline
    ------------------------------------------------------------------
    MAC_rx_pipeline_inst : entity work.MAC_rx_pipeline(rtl)
    port map (
        clk             => clk,
        rst             => rst,
        rx_done_in      => rx_done,
        -- Data in from PHY
        s_axis_tdata    => rx_pipe_axis_tdata,
        s_axis_tvalid   => rx_pipe_axis_tvalid,
        s_axis_tready   => rx_pipe_axis_tready,
        -- processed data out
        m_axis_tdata    => rx_m_axis_tdata,
        m_axis_tstrb    => rx_m_axis_tstrb,
        m_axis_tvalid   => rx_m_axis_tvalid,
        m_axis_tready   => rx_m_axis_tready,
        m_axis_tlast    => rx_m_axis_tlast
    );

    ------------------------------------------------------------------
    -- TX pipeline
    ------------------------------------------------------------------
    MAC_tx_pipeline_inst : entity work.MAC_tx_pipeline(rtl)
    generic map (
        PIPELINE_ELEM_CNT   => TX_UNFOLD_CNT
    ) port map (
        clk                 => clk,
        rst                 => rst,
        tx_busy_in          => tx_busy,
        -- Axi Data Stream Slave
        s_axis_tdata        => tx_s_axis_tdata,
        s_axis_tstrb        => tx_s_axis_tstrb,
        s_axis_tvalid       => tx_s_axis_tvalid,
        s_axis_tready       => tx_s_axis_tready,
        s_axis_tlast        => tx_s_axis_tlast,
        -- AXI Data Stream Master
        m_axis_tdata        => tx_pipe_axis_tdata,
        m_axis_tvalid       => tx_pipe_axis_tvalid,
        m_axis_tready       => tx_pipe_axis_tready
    );

    ------------------------------------------------------------------
    -- MII Phy interface
    ------------------------------------------------------------------
    mii_interface_inst : entity work.MII_Phy_Interface(rtl)
    port map (
        sys_clk         => clk,
        sys_rst         => rst,
        tx_busy         => tx_busy,
        rx_done         => rx_done,
        -- AXI Stream Slave
        s_axis_tdata    => tx_pipe_axis_tdata,
        s_axis_tvalid   => tx_pipe_axis_tvalid,
        s_axis_tready   => tx_pipe_axis_tready,
        -- AXI Stream Master
        m_axis_tdata    => rx_pipe_axis_tdata,
        m_axis_tvalid   => rx_pipe_axis_tvalid,
        m_axis_tready   => rx_pipe_axis_tready,
        -- PHY signals 
        tx_clk          => mii_tx_clk,
        tx_en           => mii_tx_en,
        tx_er           => mii_tx_er,
        tx_data         => mii_tx_data,
        rx_clk          => mii_rx_clk,
        rx_en           => mii_rx_en,
        rx_er           => mii_rx_er,
        rx_data         => mii_rx_data
    );

    -- MDIO controler and MAC config regs
    gen_mdio_and_ctrl : if (TRUE) generate

        signal mdio_start           : std_logic;
        signal mdio_write           : std_logic;
        signal mdio_phy_addr        : std_logic_vector(4 downto 0);
        signal mdio_reg_addr        : std_logic_vector(4 downto 0);
        signal reg_mdio_data_in     : std_logic_vector(15 downto 0);
        signal reg_mdio_data_out    : std_logic_vector(15 downto 0);
        signal mdio_data_valid      : std_logic;
        signal mdio_ctrl_busy            : std_logic;

    begin 
        ------------------------------------------------------------------
        -- MDIO Controller
        ------------------------------------------------------------------
        MDIO_controller_inst : entity work.MDIO_controller(rtl)
        port map (
            clk             => clk,
            -- Signals to phy
            mdio_mdc        => mdio_mdc_out,
            mdio_data_out   => mdio_data_out,
            mdio_data_in    => mdio_data_in,
            mdio_data_tri   => mdio_data_tri,
            -- Signals to MAC
            start           => mdio_start,
            wr              => mdio_write,
            phy_addr        => mdio_phy_addr,
            reg_addr        => mdio_reg_addr,
            data_in         => reg_mdio_data_in,
            data_out        => reg_mdio_data_out,
            data_out_valid  => mdio_data_valid,
            busy_out        => mdio_ctrl_busy
        );
    
        ------------------------------------------------------------------
        -- MAC Ctrl / Status Regs
        ------------------------------------------------------------------
        MAC_registers_inst : entity work.MAC_registers(rtl)
        port map (
            clk             => clk,
            rstn			=> s_axi_aresetn,
            --------------------------------------------------------------
            -- MDIO signals
            --------------------------------------------------------------
            mdio_phy_addr   => mdio_phy_addr,
            mdio_reg_addr   => mdio_reg_addr,
            mdio_data_out	=> reg_mdio_data_in,
            mdio_write		=> mdio_write,
            mdio_start		=> mdio_start,
            mdio_data_in	=> reg_mdio_data_out,
            mdio_din_valid	=> mdio_data_valid,
            mdio_busy_in    => mdio_ctrl_busy,
            ------------------------------------------------------------------------------
            -- AXI lite interface
            ------------------------------------------------------------------------------
            -- Address write channel
            S_AXI_AWADDR	=> s_axi_awaddr,
            S_AXI_AWVALID	=> s_axi_awvalid,
            S_AXI_AWREADY	=> s_axi_awready,
            -- Write channel
            S_AXI_WDATA		=> s_axi_wdata,
            S_AXI_WSTRB		=> s_axi_wstrb,
            S_AXI_WVALID	=> s_axi_wvalid,
            S_AXI_WREADY	=> s_axi_wready,
            -- Write response channel
            S_AXI_BRESP		=> s_axi_bresp,
            S_AXI_BVALID	=> s_axi_bvalid,
            S_AXI_BREADY	=> s_axi_bready,
            -- Read address channel
            S_AXI_ARADDR	=> s_axi_araddr,
            S_AXI_ARVALID	=> s_axi_arvalid,
            S_AXI_ARREADY	=> s_axi_arready,
            -- Read channel
            S_AXI_RDATA		=> s_axi_rdata,
            S_AXI_RRESP		=> s_axi_rresp,
            S_AXI_RVALID	=> s_axi_rvalid,
            S_AXI_RREADY	=> s_axi_rready
        );
    end generate gen_mdio_and_ctrl;

end architecture rtl;