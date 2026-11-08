-- Testbench for axi_rot13 using VUnit's AXI4-Lite master verification
-- component. Register accesses are plain procedure calls; the VC handles
-- the channel handshakes and checks the response codes.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
context vunit_lib.vc_context;
use vunit_lib.axi_lite_master_pkg.all;

use work.rot13_pkg.all;
use work.rot13_ref_pkg.all;

entity tb_axi_rot13 is
  generic (runner_cfg : string);
end entity;

architecture tb of tb_axi_rot13 is
  constant CLK_PERIOD : time := 10 ns;
  constant ADDR_WIDTH : positive := 4;
  constant MESSAGE    : string(1 to 16) := "Hello, World!...";

  constant bus_handle : bus_master_t := new_bus(data_length => 32, address_length => ADDR_WIDTH);

  signal aclk    : std_logic := '0';
  signal aresetn : std_logic := '0';

  signal awaddr  : std_logic_vector(ADDR_WIDTH - 1 downto 0);
  signal awvalid : std_logic;
  signal awready : std_logic;
  signal wdata   : std_logic_vector(31 downto 0);
  signal wstrb   : std_logic_vector(3 downto 0);
  signal wvalid  : std_logic;
  signal wready  : std_logic;
  signal bresp   : std_logic_vector(1 downto 0);
  signal bvalid  : std_logic;
  signal bready  : std_logic;
  signal araddr  : std_logic_vector(ADDR_WIDTH - 1 downto 0);
  signal arvalid : std_logic;
  signal arready : std_logic;
  signal rdata   : std_logic_vector(31 downto 0);
  signal rresp   : std_logic_vector(1 downto 0);
  signal rvalid  : std_logic;
  signal rready  : std_logic;

  function addr(offset : natural) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(offset, ADDR_WIDTH));
  end function;
begin
  aclk <= not aclk after CLK_PERIOD / 2;

  dut : entity work.axi_rot13
    generic map (ADDR_WIDTH => ADDR_WIDTH)
    port map (
      aclk          => aclk,
      aresetn       => aresetn,
      s_axi_awaddr  => awaddr,
      s_axi_awvalid => awvalid,
      s_axi_awready => awready,
      s_axi_wdata   => wdata,
      s_axi_wstrb   => wstrb,
      s_axi_wvalid  => wvalid,
      s_axi_wready  => wready,
      s_axi_bresp   => bresp,
      s_axi_bvalid  => bvalid,
      s_axi_bready  => bready,
      s_axi_araddr  => araddr,
      s_axi_arvalid => arvalid,
      s_axi_arready => arready,
      s_axi_rdata   => rdata,
      s_axi_rresp   => rresp,
      s_axi_rvalid  => rvalid,
      s_axi_rready  => rready
    );

  axi_master : entity vunit_lib.axi_lite_master
    generic map (bus_handle => bus_handle)
    port map (
      aclk    => aclk,
      arready => arready,
      arvalid => arvalid,
      araddr  => araddr,
      rready  => rready,
      rvalid  => rvalid,
      rdata   => rdata,
      rresp   => rresp,
      awready => awready,
      awvalid => awvalid,
      awaddr  => awaddr,
      wready  => wready,
      wvalid  => wvalid,
      wdata   => wdata,
      wstrb   => wstrb,
      bvalid  => bvalid,
      bready  => bready,
      bresp   => bresp
    );

  main : process
    variable word : std_logic_vector(31 downto 0);
    variable text : string(1 to 4);
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      aresetn <= '0';
      wait for 5 * CLK_PERIOD;
      wait until rising_edge(aclk);
      aresetn <= '1';
      wait until rising_edge(aclk);

      if run("id_register_reads_constant") then
        check_axi_lite(net, bus_handle, addr(REG_ID), axi_resp_okay, x"524F5431");

      elsif run("registers_reset_to_zero") then
        check_axi_lite(net, bus_handle, addr(REG_DATA_IN), axi_resp_okay, x"00000000");
        check_axi_lite(net, bus_handle, addr(REG_DATA_OUT), axi_resp_okay, x"00000000");

      elsif run("data_in_reads_back") then
        write_axi_lite(net, bus_handle, addr(REG_DATA_IN), x"DEADBEEF");
        check_axi_lite(net, bus_handle, addr(REG_DATA_IN), axi_resp_okay, x"DEADBEEF");

      elsif run("data_out_is_rot13_of_data_in") then
        write_axi_lite(net, bus_handle, addr(REG_DATA_IN), to_word("Hell"));
        check_axi_lite(net, bus_handle, addr(REG_DATA_OUT), axi_resp_okay, to_word("Uryy"));

      elsif run("encodes_a_message") then
        -- Feed a message 4 characters at a time, as software would.
        for i in 0 to 3 loop
          text := MESSAGE(4 * i + 1 to 4 * i + 4);
          write_axi_lite(net, bus_handle, addr(REG_DATA_IN), to_word(text));
          check_axi_lite(net, bus_handle, addr(REG_DATA_OUT), axi_resp_okay,
                         to_word(ref_rot13(text)), "chunk " & integer'image(i));
        end loop;

      elsif run("all_byte_values_match_reference") then
        for i in 0 to 255 loop
          word := (others => '0');
          word(7 downto 0) := std_logic_vector(to_unsigned(i, 8));
          write_axi_lite(net, bus_handle, addr(REG_DATA_IN), word);
          word(7 downto 0) := std_logic_vector(to_unsigned(character'pos(ref_rot13(character'val(i))), 8));
          check_axi_lite(net, bus_handle, addr(REG_DATA_OUT), axi_resp_okay, word,
                         "byte " & integer'image(i));
        end loop;

      elsif run("byte_strobes_are_honoured") then
        write_axi_lite(net, bus_handle, addr(REG_DATA_IN), x"11223344");
        write_axi_lite(net, bus_handle, addr(REG_DATA_IN), x"AABBCCDD",
                       byte_enable => "0101");
        check_axi_lite(net, bus_handle, addr(REG_DATA_IN), axi_resp_okay, x"11BB33DD");

      elsif run("write_to_read_only_register_is_rejected") then
        write_axi_lite(net, bus_handle, addr(REG_DATA_IN), to_word("abcd"));
        write_axi_lite(net, bus_handle, addr(REG_DATA_OUT), x"FFFFFFFF", axi_resp_slverr);
        write_axi_lite(net, bus_handle, addr(REG_ID), x"FFFFFFFF", axi_resp_slverr);
        check_axi_lite(net, bus_handle, addr(REG_DATA_IN), axi_resp_okay, to_word("abcd"),
                       "DATA_IN unaffected by rejected writes");
        check_axi_lite(net, bus_handle, addr(REG_ID), axi_resp_okay, ROT13_ID);

      elsif run("unmapped_address_returns_slverr") then
        check_axi_lite(net, bus_handle, addr(16#C#), axi_resp_slverr, x"00000000");
        write_axi_lite(net, bus_handle, addr(16#C#), x"12345678", axi_resp_slverr);
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

  test_runner_watchdog(runner, 1 ms);
end architecture;
