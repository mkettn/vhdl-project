-- Independent ROT13 reference model used by the testbenches, written as a
-- lookup so it does not share an implementation with the DUT.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package rot13_ref_pkg is
  function ref_rot13(c : character) return character;
  function ref_rot13(s : string) return string;
  -- Pack up to 4 characters into a little-endian word (s(1) in bits 7:0).
  function to_word(s : string) return std_logic_vector;
end package;

package body rot13_ref_pkg is
  constant PLAIN  : string := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
  constant CIPHER : string := "NOPQRSTUVWXYZABCDEFGHIJKLMnopqrstuvwxyzabcdefghijklm";

  function ref_rot13(c : character) return character is
  begin
    for i in PLAIN'range loop
      if PLAIN(i) = c then
        return CIPHER(i);
      end if;
    end loop;
    return c;
  end function;

  function ref_rot13(s : string) return string is
    variable result : string(s'range);
  begin
    for i in s'range loop
      result(i) := ref_rot13(s(i));
    end loop;
    return result;
  end function;

  function to_word(s : string) return std_logic_vector is
    constant sn     : string(1 to s'length) := s;
    variable result : std_logic_vector(31 downto 0) := (others => '0');
  begin
    assert s'length <= 4 report "to_word: at most 4 characters" severity failure;
    for i in sn'range loop
      result(8 * i - 1 downto 8 * (i - 1)) :=
        std_logic_vector(to_unsigned(character'pos(sn(i)), 8));
    end loop;
    return result;
  end function;
end package body;
