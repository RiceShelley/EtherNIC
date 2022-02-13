library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package math_pack is

    function clog2 (NUM : unsigned) return natural;

end package math_pack;

package body math_pack is

    function clog2(NUM : unsigned) return natural is 
    begin
        for i in NUM'left downto 0 loop
            if NUM(i) = '1' then
                return i + 1;
            end if;
        end loop;
    end function clog2;

end package body math_pack;