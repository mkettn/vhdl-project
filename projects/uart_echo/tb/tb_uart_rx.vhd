-- Unit tests for uart_rx, driving the rx line directly so that malformed
-- frames (bad stop bit, BREAK) can be produced.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity tb_uart_rx is
  generic (
    runner_cfg  : string;
    CLK_FREQ_HZ : positive := 50_000_000;
    BAUD_RATE   : positive := 1_000_000
  );
end entity;

architecture tb of tb_uart_rx is
  constant CLK_PERIOD : time := 1 sec / CLK_FREQ_HZ;
  constant BIT_TIME   : time := 1 sec / BAUD_RATE;

  signal clk       : std_logic := '0';
  signal rst       : std_logic := '1';
  signal rx        : std_logic := '1';
  signal m_data    : std_logic_vector(7 downto 0);
  signal m_valid   : std_logic;
  signal frame_err : std_logic;

  -- Pulse counters and the last received byte, kept by the monitor process.
  signal valid_count : natural := 0;
  signal error_count : natural := 0;
  signal last_byte   : std_logic_vector(7 downto 0) := (others => '0');
begin
  clk <= not clk after CLK_PERIOD / 2;

  dut : entity work.uart_rx
    generic map (CLK_FREQ_HZ => CLK_FREQ_HZ, BAUD_RATE => BAUD_RATE)
    port map (
      clk       => clk,
      rst       => rst,
      rx        => rx,
      m_data    => m_data,
      m_valid   => m_valid,
      frame_err => frame_err
    );

  monitor : process (clk)
  begin
    if rising_edge(clk) then
      if m_valid = '1' then
        valid_count <= valid_count + 1;
        last_byte   <= m_data;
      end if;
      if frame_err = '1' then
        error_count <= error_count + 1;
      end if;
    end if;
  end process;

  main : process
    -- Send one 8N1 frame; stop_bit = '0' produces a framing error.
    procedure send_frame(data : std_logic_vector(7 downto 0); stop_bit : std_logic := '1') is
    begin
      rx <= '0';
      wait for BIT_TIME;
      for i in 0 to 7 loop
        rx <= data(i);
        wait for BIT_TIME;
      end loop;
      rx <= stop_bit;
      wait for BIT_TIME;
      rx <= '1';
    end procedure;
  begin
    test_runner_setup(runner, runner_cfg);

    wait for 10 * CLK_PERIOD;
    rst <= '0';
    wait for 10 * CLK_PERIOD;

    while test_suite loop
      if run("receives_a_byte") then
        send_frame(x"A5");
        wait for BIT_TIME;
        check_equal(valid_count, 1, "bytes received");
        check_equal(last_byte, std_logic_vector'(x"A5"), "received byte");
        check_equal(error_count, 0, "framing errors");

      elsif run("bad_stop_bit_reports_framing_error") then
        send_frame(x"3C", stop_bit => '0');
        wait for 2 * BIT_TIME;
        check_equal(valid_count, 0, "bytes received");
        check_equal(error_count, 1, "framing errors");

      elsif run("break_reports_a_single_framing_error") then
        -- Hold the line low for many frame times, as a BREAK does.
        rx <= '0';
        wait for 50 * BIT_TIME;
        rx <= '1';
        wait for 2 * BIT_TIME;
        check_equal(error_count, 1, "framing errors during BREAK");
        check_equal(valid_count, 0, "bytes received during BREAK");

      elsif run("byte_after_break_is_received") then
        rx <= '0';
        wait for 25.3 * BIT_TIME;  -- not a whole number of bits
        rx <= '1';
        wait for 2 * BIT_TIME;
        send_frame(x"5A");
        wait for BIT_TIME;
        check_equal(valid_count, 1, "bytes received after BREAK");
        check_equal(last_byte, std_logic_vector'(x"5A"), "byte after BREAK");
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 1 ms);
end architecture;
