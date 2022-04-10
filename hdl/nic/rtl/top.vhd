library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
    generic (
        DATA_WIDTH          : natural := 32;
        ADDR_WIDTH          : natural := 32;
        STRB_WIDTH          : natural := 32 / 8;
        RESP_WIDTH          : natural := 2);
    port (
        sys_clk                 : in std_logic;
        rst                     : in std_logic;
        dout                    : out std_logic_vector(7 downto 0);
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
        -- PHY MDIO signals
        ---------------------------------------
        mdio_mdc_out            : out std_logic;
        mdio_data_out           : out std_logic;
        mdio_data_in            : in std_logic;
        mdio_data_tri           : out std_logic;
        ---------------------------------------
        -- RMII PHY interface
        ---------------------------------------
        rmii_50mhz_clk          : in std_logic;
        rmii_tx_en              : out std_logic := '0';
        rmii_tx_data            : out std_logic_vector(1 downto 0);
        rmii_rx_data            : in std_logic_vector(1 downto 0);
        rmii_crs_dv             : in std_logic;
        rmii_rx_er              : in std_logic
    );
end entity top;

architecture rtl of top is
    signal interrupts              : std_logic_vector(15 downto 0);

    ---------------------------------------
    -- AXI RX Data Stream 
    ---------------------------------------
    signal rx_m_axis_tdata         : std_logic_vector(7 downto 0);
    signal rx_m_axis_tstrb         : std_logic_vector(0 downto 0);
    signal rx_m_axis_tvalid        : std_logic;
    signal rx_m_axis_tready        : std_logic;
    signal rx_m_axis_tlast         : std_logic;

    ---------------------------------------
    -- AXI TX Data Stream 
    ---------------------------------------
    signal tx_s_axis_tdata         : std_logic_vector(7 downto 0);
    signal tx_s_axis_tstrb         : std_logic_vector(0 downto 0);
    signal tx_s_axis_tvalid        : std_logic;
    signal tx_s_axis_tready        : std_logic;
    signal tx_s_axis_tlast         : std_logic;

    signal send_pkt : std_logic;
    signal pkt_timer : unsigned(9 downto 0) := (others => '0');

begin

    capture_data_proc : process (sys_clk) begin
        if rising_edge(sys_clk) then
            if (rx_m_axis_tvalid = '1' and rx_m_axis_tready = '1') then
                dout <= rx_m_axis_tdata;
            end if;
        end if;
    end process capture_data_proc;

    send_pkt <= '1' when (pkt_timer = ((2 ** pkt_timer'length) - 1)) else '0';

    pkt_timer_proc : process (sys_clk) begin
        if rising_edge(sys_clk) then
            pkt_timer <= pkt_timer + 1;
        end if;
    end process pkt_timer_proc;

    udp_traffic_inst : entity work.udp_traffic_gen(rtl)
    port map (
        clk             => sys_clk,
        rst             => rst,
        send_pkt        => send_pkt,
        s_axis_tdata    => tx_s_axis_tdata,
        s_axis_tstrb    => tx_s_axis_tstrb,
        s_axis_tvalid   => tx_s_axis_tvalid,
        s_axis_tready   => tx_s_axis_tready,
        s_axis_tlast    => tx_s_axis_tlast
    );

    mac_inst : entity work.MAC_RMII(rtl)
    port map (
        clk                     => sys_clk,
        rst                     => rst,
        interrupts              => interrupts,
        ---------------------------------------
        -- AXI Lite Slave 
        ---------------------------------------
        s_axi_aresetn           => s_axi_aresetn,
        -- Read Address Channel
        s_axi_araddr            => s_axi_araddr,
        s_axi_arvalid           => s_axi_arvalid,
        s_axi_arready           => s_axi_arready,
        -- Read Data Channel
        s_axi_rdata             => s_axi_rdata,
        s_axi_rresp             => s_axi_rresp,
        s_axi_rvalid            => s_axi_rvalid,
        s_axi_rready            => s_axi_rready,
        -- Write Address Channel 
        s_axi_awaddr            => s_axi_awaddr,
        s_axi_awvalid           => s_axi_awvalid,
        s_axi_awready           => s_axi_awready,
        -- Write Data Channel
        s_axi_wvalid            => s_axi_wvalid,
        s_axi_wdata             => s_axi_wdata,
        s_axi_wstrb             => s_axi_wstrb,
        s_axi_wready            => s_axi_wready,
        -- Write Response Channel 
        s_axi_bresp             => s_axi_bresp,
        s_axi_bvalid            => s_axi_bvalid,
        s_axi_bready            => s_axi_bready,
        ---------------------------------------
        -- AXI RX Data Stream 
        ---------------------------------------
        rx_m_axis_tdata         => rx_m_axis_tdata,
        rx_m_axis_tstrb         => rx_m_axis_tstrb,
        rx_m_axis_tvalid        => rx_m_axis_tvalid,
        rx_m_axis_tready        => rx_m_axis_tready,
        rx_m_axis_tlast         => rx_m_axis_tlast,
        ---------------------------------------
        -- AXI TX Data Stream 
        ---------------------------------------
        tx_s_axis_tdata         => tx_s_axis_tdata,
        tx_s_axis_tstrb         => tx_s_axis_tstrb,
        tx_s_axis_tvalid        => tx_s_axis_tvalid,
        tx_s_axis_tready        => tx_s_axis_tready,
        tx_s_axis_tlast         => tx_s_axis_tlast,
        ---------------------------------------
        -- PHY MDIO signals
        ---------------------------------------
        mdio_mdc_out            => mdio_mdc_out,
        mdio_data_out           => mdio_data_out,
        mdio_data_in            => mdio_data_in,
        mdio_data_tri           => mdio_data_tri,
        ---------------------------------------
        -- RMII PHY interface
        ---------------------------------------
        rmii_clk                => rmii_50mhz_clk,
        rmii_tx_en              => rmii_tx_en,
        rmii_tx_data            => rmii_tx_data,
        rmii_rx_data            => rmii_rx_data,
        rmii_crs_dv             => rmii_crs_dv,
        rmii_rx_er              => rmii_rx_er
    );

end architecture rtl;