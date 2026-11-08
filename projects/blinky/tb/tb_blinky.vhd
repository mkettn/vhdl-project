library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_blinky is
  generic (
    runner_cfg    : string;
    -- Small values keep simulation fast; overridden from run.py.
    CLK_FREQ_HZ   : positive := 1_000;
    BLINK_FREQ_HZ : positive := 50
  );
end entity;

architecture tb of tb_blinky is
  constant CLK_PERIOD  : time := 1 sec / CLK_FREQ_HZ;
  constant HALF_CYCLES : positive := CLK_FREQ_HZ / (2 * BLINK_FREQ_HZ);

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal led : std_logic;
begin
  clk <= not clk after CLK_PERIOD / 2;

  dut : entity work.blinky
    generic map (
      CLK_FREQ_HZ   => CLK_FREQ_HZ,
      BLINK_FREQ_HZ => BLINK_FREQ_HZ
    )
    port map (
      clk => clk,
      rst => rst,
      led => led
    );

  main : process
    variable t_edge : time;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      rst <= '1';
      wait until rising_edge(clk);
      wait until rising_edge(clk);

      if run("led_is_low_during_reset") then
        for i in 1 to 4 * HALF_CYCLES loop
          wait until rising_edge(clk);
          check_equal(led, '0', "LED must stay low while in reset");
        end loop;

      elsif run("led_toggles_with_expected_period") then
        rst <= '0';
        wait until led = '1';
        t_edge := now;
        for i in 1 to 4 loop
          wait until led'event;
          check_equal(now - t_edge, HALF_CYCLES * CLK_PERIOD,
                      "Time between LED toggles");
          t_edge := now;
        end loop;

      elsif run("reset_restarts_blinking") then
        rst <= '0';
        wait until led = '1';
        wait until rising_edge(clk);
        rst <= '1';
        wait until rising_edge(clk);
        wait for 1 ps;
        check_equal(led, '0', "LED cleared by reset");
        rst <= '0';
        t_edge := now;
        wait until led = '1';
        -- First toggle occurs a full half period after reset release.
        check_equal(now - t_edge, HALF_CYCLES * CLK_PERIOD - 1 ps,
                    "Time from reset release to first toggle");
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 100 * HALF_CYCLES * CLK_PERIOD);
end architecture;
