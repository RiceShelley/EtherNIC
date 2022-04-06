library ieee;
use ieee.std_logic_1164.all;

library UNISIM;
use UNISIM.VComponents.all;

entity inout_pin is
    Port ( 
        padIO   : inout std_logic;
        sOut    : out std_logic;
        sIn     : in std_logic;
        sTri    : in std_logic
    );
end inout_pin;

architecture rtl of inout_pin is
begin

    OBUFT_inst : OBUFT
    generic map (
        DRIVE => 12,
        IOSTANDARD => "DEFAULT",
        SLEW => "SLOW")
    port map (
        O => padIO,
        I => sIn,
        T => sTri
    );
    
    IBUF_inst : IBUF
    generic map (
        IBUF_LOW_PWR => TRUE,
        IOSTANDARD => "DEFAULT")
    port map (
        O => sOut,
        I => padIO
    );

end rtl;
