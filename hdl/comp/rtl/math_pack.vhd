library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package math_pack is

    function clog2 (NUM : unsigned) return natural;
    function clog2 (NUM : natural) return natural;

end package math_pack;

package body math_pack is

    function clog2(NUM : unsigned) return natural is 
        variable n : unsigned(NUM'range) := NUM - 1;
    begin
        if n = 0 then
            return 1;
        else
            for i in n'left downto 0 loop
                if n(i) = '1' then
                    return i + 1;
                end if;
            end loop;
        end if;
    end function clog2;

    function clog2(NUM : natural) return natural is
        variable u_num : unsigned(31 downto 0) := to_unsigned(NUM, 32);
    begin
        return clog2(u_num);
    end function clog2;

end package body math_pack;