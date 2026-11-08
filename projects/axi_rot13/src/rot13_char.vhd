-- rot13_char: combinational ROT13 of a single ASCII character.
--
-- Letters are rotated by 13 positions within their case; every other byte
-- passes through unchanged.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rot13_char is
  port (
    char_in  : in  std_logic_vector(7 downto 0);
    char_out : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of rot13_char is
  constant UPPER_A : unsigned(7 downto 0) := to_unsigned(character'pos('A'), 8);
  constant UPPER_M : unsigned(7 downto 0) := to_unsigned(character'pos('M'), 8);
  constant UPPER_Z : unsigned(7 downto 0) := to_unsigned(character'pos('Z'), 8);
  constant LOWER_A : unsigned(7 downto 0) := to_unsigned(character'pos('a'), 8);
  constant LOWER_M : unsigned(7 downto 0) := to_unsigned(character'pos('m'), 8);
  constant LOWER_Z : unsigned(7 downto 0) := to_unsigned(character'pos('z'), 8);

  signal c                      : unsigned(7 downto 0);
  signal first_half, last_half  : boolean;
begin
  c <= unsigned(char_in);

  -- A..M / a..m move forward by 13, N..Z / n..z move back by 13.
  first_half <= (c >= UPPER_A and c <= UPPER_M) or (c >= LOWER_A and c <= LOWER_M);
  last_half  <= (c > UPPER_M and c <= UPPER_Z) or (c > LOWER_M and c <= LOWER_Z);

  char_out <= std_logic_vector(c + 13) when first_half else
              std_logic_vector(c - 13) when last_half else
              char_in;
end architecture;
