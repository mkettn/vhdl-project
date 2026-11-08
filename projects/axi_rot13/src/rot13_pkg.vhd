-- rot13_pkg: ROT13 transform and the axi_rot13 register map.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package rot13_pkg is
  -- Register byte offsets
  constant REG_DATA_IN  : natural := 16#0#;  -- RW: input word (4 characters)
  constant REG_DATA_OUT : natural := 16#4#;  -- RO: ROT13 of each byte of DATA_IN
  constant REG_ID       : natural := 16#8#;  -- RO: identification constant

  constant ROT13_ID : std_logic_vector(31 downto 0) := x"524F5431";  -- "ROT1"

  -- ROT13 of a single ASCII character; non-letters pass through unchanged.
  function rot13(c : std_logic_vector(7 downto 0)) return std_logic_vector;

  -- ROT13 of every byte of a word.
  function rot13_word(w : std_logic_vector) return std_logic_vector;
end package;

package body rot13_pkg is
  function rot13(c : std_logic_vector(7 downto 0)) return std_logic_vector is
    constant code : natural := to_integer(unsigned(c));
    variable base : natural;
  begin
    if code >= character'pos('A') and code <= character'pos('Z') then
      base := character'pos('A');
    elsif code >= character'pos('a') and code <= character'pos('z') then
      base := character'pos('a');
    else
      return c;
    end if;
    return std_logic_vector(to_unsigned(base + (code - base + 13) mod 26, 8));
  end function;

  function rot13_word(w : std_logic_vector) return std_logic_vector is
    constant wn     : std_logic_vector(w'length - 1 downto 0) := w;
    variable result : std_logic_vector(w'length - 1 downto 0);
  begin
    assert w'length mod 8 = 0 report "rot13_word: width must be a multiple of 8" severity failure;
    for i in 0 to w'length / 8 - 1 loop
      result(8 * i + 7 downto 8 * i) := rot13(wn(8 * i + 7 downto 8 * i));
    end loop;
    return result;
  end function;
end package body;
