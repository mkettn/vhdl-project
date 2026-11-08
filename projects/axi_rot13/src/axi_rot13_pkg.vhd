-- axi_rot13_pkg: register map of the axi_rot13 peripheral.

library ieee;
use ieee.std_logic_1164.all;

package axi_rot13_pkg is
  -- Register byte offsets
  constant REG_DATA_IN  : natural := 16#0#;  -- RW: input word (4 characters)
  constant REG_DATA_OUT : natural := 16#4#;  -- RO: ROT13 of each byte of DATA_IN
  constant REG_ID       : natural := 16#8#;  -- RO: identification constant

  constant ROT13_ID : std_logic_vector(31 downto 0) := x"524F5431";  -- "ROT1"
end package;
