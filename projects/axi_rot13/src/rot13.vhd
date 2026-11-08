-- rot13: the ROT13 device. Applies ROT13 to every byte of a data word.
--
-- Purely combinational and bus-agnostic; see axi_rot13 for an AXI4-Lite
-- embedding. Byte i of data_in maps to byte i of data_out.

library ieee;
use ieee.std_logic_1164.all;

entity rot13 is
  generic (
    NUM_BYTES : positive := 4
  );
  port (
    data_in  : in  std_logic_vector(8 * NUM_BYTES - 1 downto 0);
    data_out : out std_logic_vector(8 * NUM_BYTES - 1 downto 0)
  );
end entity;

architecture rtl of rot13 is
begin
  gen_bytes : for i in 0 to NUM_BYTES - 1 generate
    char_inst : entity work.rot13_char
      port map (
        char_in  => data_in(8 * i + 7 downto 8 * i),
        char_out => data_out(8 * i + 7 downto 8 * i)
      );
  end generate;
end architecture;
