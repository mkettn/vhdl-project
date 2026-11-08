-- Unit tests for the bus-agnostic rot13 device (no clock, no bus).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

use work.rot13_ref_pkg.all;

entity tb_rot13 is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_rot13 is
  constant SETTLE : time := 1 ns;

  signal data_in  : std_logic_vector(31 downto 0) := (others => '0');
  signal data_out : std_logic_vector(31 downto 0);

  -- Second instance fed by the first, to check that ROT13 is an involution.
  signal data_back : std_logic_vector(31 downto 0);
begin
  dut : entity work.rot13
    generic map (NUM_BYTES => 4)
    port map (data_in => data_in, data_out => data_out);

  dut_inverse : entity work.rot13
    generic map (NUM_BYTES => 4)
    port map (data_in => data_out, data_out => data_back);

  main : process
    variable expected : std_logic_vector(31 downto 0);
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("matches_reference_for_all_byte_values") then
        for i in 0 to 255 loop
          -- Same byte in every lane exercises all four rot13_char instances.
          data_in <= std_logic_vector(to_unsigned(i, 8)) & std_logic_vector(to_unsigned(i, 8)) &
                     std_logic_vector(to_unsigned(i, 8)) & std_logic_vector(to_unsigned(i, 8));
          wait for SETTLE;
          expected := to_word((1 to 4 => ref_rot13(character'val(i))));
          check_equal(data_out, expected, "rot13 of byte " & integer'image(i));
        end loop;

      elsif run("is_an_involution") then
        for i in 0 to 255 loop
          data_in <= std_logic_vector(to_unsigned(i, 8)) & x"00" & x"7F" & std_logic_vector(to_unsigned(255 - i, 8));
          wait for SETTLE;
          check_equal(data_back, data_in, "rot13(rot13(x)) = x");
        end loop;

      elsif run("transforms_each_byte_independently") then
        data_in <= to_word("Hell");
        wait for SETTLE;
        check_equal(data_out, to_word("Uryy"));
        data_in <= to_word("o, W");
        wait for SETTLE;
        check_equal(data_out, to_word("b, J"));
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
