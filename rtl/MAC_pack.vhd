library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package MAC_pack is

    -- Simple handshake record
    type t_SPH is record
        data    : std_logic_vector(7 downto 0);
        consent : std_logic;
        en      : std_logic;
    end record t_SPH;

    constant MAC_PACK_EMPTY_SPH : t_SPH := (
        data    => (others => '0'),
        consent => '0',
        en      => '0'
    );

end package MAC_pack;

package body MAC_pack is

end package body MAC_pack;