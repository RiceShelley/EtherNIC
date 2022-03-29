library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MDIO_controller is

    port (
        mdio_clk        : in std_logic;
        mdio_data       : inout std_logic := 'Z';
        start           : in std_logic;
        wr              : in std_logic;
        phy_addr        : in std_logic_vector(4 downto 0);
        reg_addr        : in std_logic_vector(4 downto 0);
        data_in         : in std_logic_vector(15 downto 0);
        data_out        : out std_logic_vector(15 downto 0);
        data_out_valid  : out std_logic
    );

end entity MDIO_controller;

architecture rtl of MDIO_controller is

    type t_MDIO_state is (IDLE, TRANS);
    signal MDIO_state : t_MDIO_state := IDLE;

    constant MDIO_PRE32     : std_logic_vector(31 downto 0) := (others => '1');
    constant MDIO_START     : std_logic_vector(1 downto 0) := "01";
    constant MDIO_RD        : std_logic_vector(1 downto 0) := "10";
    constant MDIO_WR        : std_logic_vector(1 downto 0) := "01";
    constant MDIO_TA_WR     : std_logic_vector(1 downto 0) := "10";
    constant MDIO_TA_RD     : std_logic_vector(1 downto 0) := "ZZ";
    constant MDIO_TRI_DATA  : std_logic_vector(15 downto 0) := (others => 'Z');
    
    constant MDIO_SOD       : natural := 64 - 16;
    constant MDIO_PKT_LEN   : natural := 64;

    signal bit_idx      : natural := 0;
    signal mdio_pkt     : std_logic_vector(0 to 63);
    signal writeR       : std_logic := '0';
    signal dataReg      : std_logic_vector(15 downto 0);
    signal doutValidR   : std_logic := '0';

begin

    data_out <= dataReg;

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

    MDIO_FSM_Proc : process(mdio_clk) begin
        if rising_edge(mdio_clk) then
            mdio_data       <= 'Z';
            data_out_valid  <= doutValidR;
            doutValidR      <= '0';
            case MDIO_state is
                when IDLE =>
                    bit_idx <= 0;
                    if (start = '1') then
                        writeR      <= wr;
                        MDIO_state  <= TRANS;
                        bit_idx     <= 0;
                        if (wr = '1') then
                            mdio_pkt <= MDIO_PRE32 & MDIO_START & MDIO_WR & phy_addr & reg_addr & MDIO_TA_WR & data_in;
                        else
                            mdio_pkt <= MDIO_PRE32 & MDIO_START & MDIO_RD & phy_addr & reg_addr & MDIO_TA_RD & MDIO_TRI_DATA;
                        end if;
                    end if;
                when TRANS =>
                    mdio_data <= mdio_pkt(bit_idx);
                    if (bit_idx = MDIO_PKT_LEN - 1) then
                        MDIO_state <= IDLE;
                        bit_idx <= bit_idx + 1;
                        if (writeR = '0') then
                            doutValidR <= '1';
                        end if;
                    else
                        bit_idx <= bit_idx + 1;
                    end if;
                when others =>
                    MDIO_state <= IDLE;
            end case;
        end if;
    end process MDIO_FSM_Proc;

    MDIO_rd_proc : process(mdio_clk) begin
        if rising_edge(mdio_clk) then
            if (writeR = '0') then
                if (bit_idx > MDIO_SOD) then
                    dataReg <= dataReg(dataReg'left - 1 downto 0) & mdio_data;
                end if;
            end if;
        end if;
    end process MDIO_rd_proc;

end architecture rtl;