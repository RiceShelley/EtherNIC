library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MDIO_controller is
    generic (
        DIV_CLK_BY_2N   : natural := 6
    );
    port (
        clk             : in std_logic;
        -- Signals to phy
        mdio_mdc        : out std_logic;
        mdio_data_out   : out std_logic;
        mdio_data_in    : in std_logic;
        mdio_data_tri   : out std_logic;
        -- Signals to MAC
        start           : in std_logic;
        wr              : in std_logic;
        phy_addr        : in std_logic_vector(4 downto 0);
        reg_addr        : in std_logic_vector(4 downto 0);
        data_in         : in std_logic_vector(15 downto 0);
        data_out        : out std_logic_vector(15 downto 0);
        data_out_valid  : out std_logic;
        busy_out        : out std_logic
    );
end entity MDIO_controller;

architecture rtl of MDIO_controller is

    constant MDIO_PRE32     : std_logic_vector(31 downto 0) := (others => '1');
    constant MDIO_START     : std_logic_vector(1 downto 0) := "01";
    constant MDIO_RD        : std_logic_vector(1 downto 0) := "10";
    constant MDIO_WR        : std_logic_vector(1 downto 0) := "01";
    constant MDIO_TA_WR     : std_logic_vector(1 downto 0) := "10";
    constant MDIO_TA_RD     : std_logic_vector(1 downto 0) := "00";
    constant MDIO_DATA_ZERO  : std_logic_vector(15 downto 0) := (others => '0');

    constant MDIO_SOD       : natural := 64 - 16;
    constant MDIO_PKT_LEN   : natural := 64;

    -- Regions of MDIO pkt to tristate output pin
    constant MDIO_RD_TRI_REGIONS : std_logic_vector(0 to MDIO_PKT_LEN - 1) := (not MDIO_PRE32) & "0000000000000011" & (not MDIO_DATA_ZERO);
    constant MDIO_WR_TRI_REGIONS : std_logic_vector(0 to MDIO_PKT_LEN - 1) := (not MDIO_PRE32) & "0000000000000000" & MDIO_DATA_ZERO;

    constant DIV_CLK_REDGE  : unsigned(DIV_CLK_BY_2N - 1 downto 0) := to_unsigned((2 ** (DIV_CLK_BY_2N - 1)) - 1, DIV_CLK_BY_2N);
    signal div_clk_reg      : unsigned(DIV_CLK_BY_2N - 1 downto 0) := (others => '0');
    signal div_clk          : std_logic;

    type t_MDIO_state is (IDLE, TRANS, CLK_DATA);
    signal MDIO_state : t_MDIO_state := IDLE;

    signal bit_idx      : natural := 0;
    signal mdio_pkt     : std_logic_vector(0 to 63);
    signal writeR       : std_logic := '0';
    signal dataReg      : std_logic_vector(15 downto 0);
    signal doutValidR   : std_logic := '0';
    signal mdio_redge   : std_logic := '0';

begin

    data_out    <= dataReg;

    div_clk     <= div_clk_reg(div_clk_reg'left);

    -- Generate MDIO clk
    mdio_clk_proc : process(clk) begin
        if rising_edge(clk) then
            if (start = '1') then
                div_clk_reg <= to_unsigned(1, div_clk_reg'length);
                mdio_redge <= '0';
            else
                mdio_redge <= '0';
                div_clk_reg <= div_clk_reg + 1;
                if (div_clk_reg = DIV_CLK_REDGE) then
                    mdio_redge <= '1';
                end if;
            end if;
        end if;
    end process mdio_clk_proc;

    -------------------------------------------------------------------------------------------------------------
    -- MDIO pkt format
    -- name         bits        desc
    -- PRE_32       32          pramble MAC sends 32 bits all 1 on MDIO line
    -- ST           2           Start field 2 bits -> always "01"
    -- OP           2           Opcode READ -> "10" / WRITE -> "01"
    -- PA5          5           PHY address (see phy / devboard data sheet)
    -- RA5          5           Register address
    -- TA           2           Turn around field: data is being written to the PHY -> MAC write "10"
    --                                             data is being read from the PHY -> MAC releases MDIO line 
    -- D16          16          16 data bits Can be send by the SME or the PHY depending on OP field
    -- Z                        Tristate MDIO
    -------------------------------------------------------------------------------------------------------------
    MDIO_FSM_Proc : process(clk) begin
        if rising_edge(clk) then
            if (mdio_redge = '1' or (start = '1' and MDIO_state = IDLE)) then
                mdio_mdc <= '0';
                data_out_valid  <= doutValidR;
                doutValidR      <= '0';
                case MDIO_state is
                    when IDLE =>
                        busy_out        <= '0';
                        bit_idx         <= 0;
                        mdio_data_tri   <= '1';
                        if (start = '1') then
                            writeR      <= wr;
                            MDIO_state  <= TRANS;
                            bit_idx     <= 0;
                            busy_out    <= '1';
                            if (wr = '1') then
                                mdio_pkt <= MDIO_PRE32 & MDIO_START & MDIO_WR & phy_addr & reg_addr & MDIO_TA_WR & data_in;
                            else
                                mdio_pkt <= MDIO_PRE32 & MDIO_START & MDIO_RD & phy_addr & reg_addr & MDIO_TA_RD & MDIO_DATA_ZERO;
                            end if;
                        end if;
                    when TRANS =>
                        -- Sample / Write to MDIO on negedges
                        if (writeR = '0') then
                            mdio_data_tri <= MDIO_RD_TRI_REGIONS(bit_idx);
                            if (bit_idx < MDIO_SOD) then
                                mdio_data_out <= mdio_pkt(bit_idx);
                            else
                                dataReg <= dataReg(dataReg'left - 1 downto 0) & mdio_data_in;
                            end if;
                        else
                            mdio_data_tri <= MDIO_WR_TRI_REGIONS(bit_idx);
                            mdio_data_out <= mdio_pkt(bit_idx);
                        end if;
                        MDIO_state <= CLK_DATA;
                    when CLK_DATA =>
                        mdio_mdc <= '1';
                        MDIO_state <= TRANS;
                        if (bit_idx = MDIO_PKT_LEN - 1) then
                            MDIO_state  <= IDLE;
                            bit_idx     <= bit_idx + 1;
                            if (writeR = '0') then
                                doutValidR <= '1';
                            end if;
                        else
                            bit_idx <= bit_idx + 1;
                        end if;

                    when others =>
                        mdio_data_tri   <= '1';
                        MDIO_state      <= IDLE;
                end case;
            end if;
        end if;
    end process MDIO_FSM_Proc;

end architecture rtl;