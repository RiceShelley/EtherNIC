library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MAC_registers is
	generic (
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		C_S_AXI_ADDR_WIDTH	: integer	:= 32
	);
	port (
		clk             : in std_logic;
		rstn			: in std_logic;
		------------------------------------------------------------------------------
		-- MDIO signals
		------------------------------------------------------------------------------
		mdio_phy_addr   : out std_logic_vector(4 downto 0);
		mdio_reg_addr   : out std_logic_vector(4 downto 0);
		mdio_data_out	: out std_logic_vector(15 downto 0);
		mdio_write		: out std_logic;
		mdio_start		: out std_logic;
		mdio_data_in	: in std_logic_vector(15 downto 0);
		mdio_din_valid	: in std_logic;
		mdio_busy_in    : in std_logic;
		------------------------------------------------------------------------------
		-- AXI lite interface
		------------------------------------------------------------------------------
		-- Address write channel
		S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_AWVALID	: in std_logic;
		S_AXI_AWREADY	: out std_logic;
		-- Write channel
		S_AXI_WDATA		: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_WSTRB		: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		S_AXI_WVALID	: in std_logic;
		S_AXI_WREADY	: out std_logic;
		-- Write response channel
		S_AXI_BRESP		: out std_logic_vector(1 downto 0);
		S_AXI_BVALID	: out std_logic;
		S_AXI_BREADY	: in std_logic;
		-- Read address channel
		S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_ARVALID	: in std_logic;
		S_AXI_ARREADY	: out std_logic;
		-- Read channel
		S_AXI_RDATA		: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_RRESP		: out std_logic_vector(1 downto 0);
		S_AXI_RVALID	: out std_logic;
		S_AXI_RREADY	: in std_logic
	);
end MAC_registers;

architecture rtl of MAC_registers is

	signal axi_awaddr	: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_awready	: std_logic;
	signal axi_wready	: std_logic;
	signal axi_bresp	: std_logic_vector(1 downto 0);
	signal axi_bvalid	: std_logic;
	signal axi_araddr	: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_arready	: std_logic;
	signal axi_rdata	: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal axi_rresp	: std_logic_vector(1 downto 0);
	signal axi_rvalid	: std_logic;

	constant ADDR_LSB  			: integer := (C_S_AXI_DATA_WIDTH/32)+ 1;
	constant OPT_MEM_ADDR_BITS 	: integer := 1;

	signal mdio_config	: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal mdio_status	: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

	signal slv_reg_rden	: std_logic;
	signal slv_reg_wren	: std_logic;

	signal reg_data_out	: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

	signal byte_index	: integer;
	signal aw_en		: std_logic;

	signal mdio_data_in_reg : std_logic_vector(15 downto 0);

begin

	mdio_data_out	<= mdio_config(15 downto 0);
	mdio_phy_addr	<= mdio_config(20 downto 16);
	mdio_reg_addr	<= mdio_config(28 downto 24);
	mdio_write		<= mdio_config(31);

	mdio_status(31 downto 1) 	<= (others => '0');
	mdio_status(0)  			<= mdio_busy_in;

	S_AXI_AWREADY	<= axi_awready;
	S_AXI_WREADY	<= axi_wready;
	S_AXI_BRESP		<= axi_bresp;
	S_AXI_BVALID	<= axi_bvalid;
	S_AXI_ARREADY	<= axi_arready;
	S_AXI_RDATA		<= axi_rdata;
	S_AXI_RRESP		<= axi_rresp;
	S_AXI_RVALID	<= axi_rvalid;

	-- AW ready generation
	-- axi_awready is asserted for one S_AXI_ACLK clock cycle when both
	-- S_AXI_AWVALID and S_AXI_WVALID are asserted.
	process (clk) begin
		if rising_edge(clk) then 
			if rstn = '0' then
				axi_awready	<= '0';
				aw_en 		<= '1';
			else
				if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
					axi_awready	<= '1';
					aw_en 		<= '0';
				elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
					aw_en 		<= '1';
					axi_awready	<= '0';
				else
				axi_awready <= '0';
				end if;
			end if;
		end if;
	end process;

	-- latch AW addr
	process (clk) begin
		if rising_edge(clk) then 
			if rstn = '0' then
				axi_awaddr <= (others => '0');
			else
				if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
					axi_awaddr <= S_AXI_AWADDR;
				end if;
			end if;
		end if;                   
	end process; 

	-- W ready generation
	-- axi_wready is asserted for one S_AXI_ACLK clock cycle when both
	-- S_AXI_AWVALID and S_AXI_WVALID are asserted.
	process (clk) begin
		if rising_edge(clk) then 
			if rstn = '0' then
				axi_wready <= '0';
			else
				if (axi_wready = '0' and S_AXI_WVALID = '1' and S_AXI_AWVALID = '1' and aw_en = '1') then
					axi_wready <= '1';
				else
					axi_wready <= '0';
				end if;
			end if;
		end if;
	end process; 

	-- Implement memory mapped register select and write logic generation
	slv_reg_wren <= axi_wready and S_AXI_WVALID and axi_awready and S_AXI_AWVALID ;

	process (clk)
		variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0); 
	begin
		if rising_edge(clk) then 
			mdio_start <= '0';
			if rstn = '0' then
				mdio_config <= (others => '0');
			else
				loc_addr := axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
				if (slv_reg_wren = '1') then
					case loc_addr is
						-- MDIO config
						when b"00" =>
							for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
								if (S_AXI_WSTRB(byte_index) = '1') then
									mdio_config(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
								end if;
							end loop;
						-- MDIO ctrl register (Write 1 to start MDIO transaction)
						when b"10" =>
								mdio_start <= S_AXI_WDATA(0);
						when others =>
							mdio_config <= mdio_config;
					end case;
				end if;
			end if;
		end if;                   
	end process; 
	
	-- Write response generation
	process (clk) begin
		if rising_edge(clk) then 
			if rstn = '0' then
				axi_bvalid  <= '0';
				axi_bresp   <= "00";
			else
				if (axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and S_AXI_WVALID = '1' and axi_bvalid = '0'  ) then
					axi_bvalid <= '1';
					axi_bresp  <= "00"; 
				elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
					axi_bvalid <= '0';
				end if;
			end if;
		end if;                   
	end process; 

	-- AR ready generation / capture AR addr
	process (clk) begin
		if rising_edge(clk) then 
			if rstn = '0' then
				axi_arready <= '0';
				axi_araddr  <= (others => '1');
			else
				if (axi_arready = '0' and S_AXI_ARVALID = '1') then
					axi_arready <= '1';
					axi_araddr  <= S_AXI_ARADDR;           
				else
					axi_arready <= '0';
				end if;
			end if;
		end if;                   
	end process; 

	-- Implement axi_arvalid generation
	process (clk) begin
		if rising_edge(clk) then
			if rstn = '0' then
				axi_rvalid <= '0';
				axi_rresp  <= "00";
			else
				if (axi_arready = '1' and S_AXI_ARVALID = '1' and axi_rvalid = '0') then
					axi_rvalid <= '1';
					axi_rresp  <= "00";
				elsif (axi_rvalid = '1' and S_AXI_RREADY = '1') then
					axi_rvalid <= '0';
				end if;            
			end if;
		end if;
	end process;

	-- Implement memory mapped register select
	slv_reg_rden <= axi_arready and S_AXI_ARVALID and (not axi_rvalid);

	process (mdio_config, mdio_data_in_reg, mdio_status, axi_araddr, rstn, slv_reg_rden)
		variable loc_addr :std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
	begin
		-- Address decoding for reading registers
		loc_addr := axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
		case loc_addr is
			when b"00" =>
				reg_data_out <= mdio_config;
			when b"01" =>
				reg_data_out <= x"0000" & mdio_data_in_reg;
			when b"11" =>
				reg_data_out <= mdio_status;
			when others =>
				reg_data_out  <= (others => '0');
		end case;
	end process; 

	-- Output register or memory read data
	process(clk) is begin
		if (rising_edge(clk)) then
			if (rstn = '0' ) then
				axi_rdata  <= (others => '0');
			else
				if (slv_reg_rden = '1') then
					axi_rdata <= reg_data_out;
				end if;   
			end if;
		end if;
	end process;

	-- Capture MDIO data in
	process (clk) begin
		if rising_edge(clk) then
			if rstn = '0' then
				mdio_data_in_reg <= (others => '0');
			else
				if mdio_din_valid = '1' then
					mdio_data_in_reg <= mdio_data_in;
				end if;
			end if;
		end if;
	end process;
end rtl;
