-- Testbench for uart_echo using VUnit's UART verification components.
--
-- uart_master drives the DUT's rx line, uart_slave decodes the DUT's tx
-- line. Both expose VUnit's generic stream interface, so the test just
-- pushes bytes in and checks the bytes coming out.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
context vunit_lib.vc_context;

library osvvm;
use osvvm.RandomPkg.all;

entity tb_uart_echo is
  generic (
    runner_cfg  : string;
    CLK_FREQ_HZ : positive := 50_000_000;
    BAUD_RATE   : positive := 115_200
  );
end entity;

architecture tb of tb_uart_echo is
  constant CLK_PERIOD : time := 1 sec / CLK_FREQ_HZ;
  constant BIT_TIME   : time := 1 sec / BAUD_RATE;
  constant MESSAGE    : string := "Hello";

  constant uart_bfm_master : uart_master_t := new_uart_master(initial_baud_rate => BAUD_RATE);
  constant uart_stream_in  : stream_master_t := as_stream(uart_bfm_master);

  constant uart_bfm_slave  : uart_slave_t := new_uart_slave(initial_baud_rate => BAUD_RATE);
  constant uart_stream_out : stream_slave_t := as_stream(uart_bfm_slave);

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal rx  : std_logic;
  signal tx  : std_logic;
begin
  clk <= not clk after CLK_PERIOD / 2;

  dut : entity work.uart_echo
    generic map (
      CLK_FREQ_HZ => CLK_FREQ_HZ,
      BAUD_RATE   => BAUD_RATE
    )
    port map (
      clk => clk,
      rst => rst,
      rx  => rx,
      tx  => tx
    );

  uart_master_bfm : entity vunit_lib.uart_master
    generic map (uart => uart_bfm_master)
    port map (tx => rx);

  uart_slave_bfm : entity vunit_lib.uart_slave
    generic map (uart => uart_bfm_slave)
    port map (rx => tx);

  main : process
    variable rnd  : RandomPType;
    variable data : std_logic_vector(7 downto 0);
  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    rst <= '1';
    wait for 10 * CLK_PERIOD;
    rst <= '0';
    wait for 10 * CLK_PERIOD;

    while test_suite loop
      if run("tx_idles_high") then
        for i in 1 to 20 loop
          wait for BIT_TIME;
          check_equal(tx, '1', "tx line must idle high");
        end loop;

      elsif run("echoes_single_byte") then
        push_stream(net, uart_stream_in, x"41");
        check_stream(net, uart_stream_out, x"41");

      elsif run("echoes_string") then
        for i in MESSAGE'range loop
          push_stream(net, uart_stream_in,
                      std_logic_vector(to_unsigned(character'pos(MESSAGE(i)), 8)));
        end loop;
        for i in MESSAGE'range loop
          check_stream(net, uart_stream_out,
                       std_logic_vector(to_unsigned(character'pos(MESSAGE(i)), 8)),
                       msg => "character " & integer'image(i));
        end loop;

      elsif run("echoes_all_byte_values_back_to_back") then
        for i in 0 to 255 loop
          push_stream(net, uart_stream_in, std_logic_vector(to_unsigned(i, 8)));
        end loop;
        for i in 0 to 255 loop
          check_stream(net, uart_stream_out, std_logic_vector(to_unsigned(i, 8)));
        end loop;

      elsif run("echoes_random_bytes") then
        for i in 1 to 32 loop
          data := rnd.RandSlv(8);
          push_stream(net, uart_stream_in, data);
          check_stream(net, uart_stream_out, data);
        end loop;
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 300 * 10 * BIT_TIME);
end architecture;
