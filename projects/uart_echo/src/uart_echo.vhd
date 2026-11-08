-- uart_echo: echoes every byte received on rx back out on tx.
--
-- A small FIFO decouples receiver and transmitter so back-to-back traffic
-- is not lost even if the local baud clock is slightly slower than the
-- remote one.

library ieee;
use ieee.std_logic_1164.all;

entity uart_echo is
  generic (
    CLK_FREQ_HZ : positive := 100_000_000;
    BAUD_RATE   : positive := 115_200;
    FIFO_DEPTH  : positive := 16
  );
  port (
    clk : in  std_logic;
    rst : in  std_logic;
    rx  : in  std_logic;
    tx  : out std_logic
  );
end entity;

architecture rtl of uart_echo is
  signal rx_data,  tx_data  : std_logic_vector(7 downto 0);
  signal rx_valid, tx_valid : std_logic;
  signal tx_ready           : std_logic;
begin
  rx_inst : entity work.uart_rx
    generic map (CLK_FREQ_HZ => CLK_FREQ_HZ, BAUD_RATE => BAUD_RATE)
    port map (
      clk       => clk,
      rst       => rst,
      rx        => rx,
      m_data    => rx_data,
      m_valid   => rx_valid,
      frame_err => open
    );

  fifo_inst : entity work.sync_fifo
    generic map (WIDTH => 8, DEPTH => FIFO_DEPTH)
    port map (
      clk     => clk,
      rst     => rst,
      s_data  => rx_data,
      s_valid => rx_valid,
      s_ready => open,  -- overflow drops bytes
      m_data  => tx_data,
      m_valid => tx_valid,
      m_ready => tx_ready
    );

  tx_inst : entity work.uart_tx
    generic map (CLK_FREQ_HZ => CLK_FREQ_HZ, BAUD_RATE => BAUD_RATE)
    port map (
      clk     => clk,
      rst     => rst,
      s_data  => tx_data,
      s_valid => tx_valid,
      s_ready => tx_ready,
      tx      => tx
    );
end architecture;
