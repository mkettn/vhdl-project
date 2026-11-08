-- Unit tests for the pure functions in rot13_pkg (no clock, no DUT).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

use work.rot13_pkg.all;
use work.rot13_ref_pkg.all;

entity tb_rot13_pkg is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_rot13_pkg is
begin
  main : process
    variable c : std_logic_vector(7 downto 0);
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("matches_reference_for_all_byte_values") then
        for i in 0 to 255 loop
          c := std_logic_vector(to_unsigned(i, 8));
          check_equal(rot13(c),
                      to_unsigned(character'pos(ref_rot13(character'val(i))), 8),
                      "rot13 of byte " & integer'image(i));
        end loop;

      elsif run("is_an_involution") then
        for i in 0 to 255 loop
          c := std_logic_vector(to_unsigned(i, 8));
          check_equal(rot13(rot13(c)), c, "rot13(rot13(x)) = x for " & integer'image(i));
        end loop;

      elsif run("word_transforms_each_byte") then
        check_equal(rot13_word(to_word("Hell")), to_word("Uryy"));
        check_equal(rot13_word(to_word("o, W")), to_word("b, J"));
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
