library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package MAC_pack is

    constant MAC_AXIS_DATA_WIDTH : natural := 8;
    constant MAC_AXIS_STRB_WIDTH : natural := MAC_AXIS_DATA_WIDTH / 8;

    type t_axis_data_array is array (natural range<>) of std_logic_vector(MAC_AXIS_DATA_WIDTH - 1 downto 0);
    type t_axis_strb_array is array (natural range<>) of std_logic_vector(MAC_AXIS_STRB_WIDTH - 1 downto 0);

end package MAC_pack;

package body MAC_pack is

end package body MAC_pack;