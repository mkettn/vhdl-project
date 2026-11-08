-- uart_tx: 8N1 UART transmitter with a valid/ready input stream.
--
-- A byte is accepted when s_valid and s_ready are both high on a rising
-- clock edge. s_ready is high while idle and in the last clock cycle of a
-- frame's stop bit, so back-to-back frames have no idle gap and the output
-- rate is exactly one frame per 10 * CLKS_PER_BIT cycles.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
  generic (
    CLK_FREQ_HZ : positive := 100_000_000;
    BAUD_RATE   : positive := 115_200
  );
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;
    s_data  : in  std_logic_vector(7 downto 0);
    s_valid : in  std_logic;
    s_ready : out std_logic;
    tx      : out std_logic
  );
end entity;

architecture rtl of uart_tx is
  -- natural (not positive) so that the assert below can report bad generics
  constant CLKS_PER_BIT : natural := CLK_FREQ_HZ / BAUD_RATE;

  type state_t is (IDLE, SENDING);
  signal state : state_t := IDLE;

  -- Frame shift register: stop & data & start, shifted out LSB first.
  signal shreg    : std_logic_vector(9 downto 0) := (others => '1');
  signal bit_cnt  : natural range 0 to 9 := 0;
  signal baud_cnt : natural range 0 to CLKS_PER_BIT := 0;

  signal last_cycle : boolean;  -- final clock cycle of the stop bit
  signal ready_i    : std_logic;
begin
  assert CLKS_PER_BIT >= 2
    report "uart_tx: CLK_FREQ_HZ must be at least 2 * BAUD_RATE"
    severity failure;

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state    <= IDLE;
        shreg    <= (others => '1');
        bit_cnt  <= 0;
        baud_cnt <= 0;
      else
        case state is
          when IDLE =>
            if s_valid = '1' then
              shreg    <= '1' & s_data & '0';
              bit_cnt  <= 0;
              baud_cnt <= 0;
              state    <= SENDING;
            end if;

          when SENDING =>
            if last_cycle then
              baud_cnt <= 0;
              bit_cnt  <= 0;
              if s_valid = '1' then
                shreg <= '1' & s_data & '0';  -- next frame, no gap
              else
                shreg <= (others => '1');
                state <= IDLE;
              end if;
            elsif baud_cnt = CLKS_PER_BIT - 1 then
              baud_cnt <= 0;
              shreg    <= '1' & shreg(9 downto 1);
              bit_cnt  <= bit_cnt + 1;
            else
              baud_cnt <= baud_cnt + 1;
            end if;
        end case;
      end if;
    end if;
  end process;

  last_cycle <= state = SENDING and bit_cnt = 9 and baud_cnt = CLKS_PER_BIT - 1;
  ready_i    <= '1' when state = IDLE or last_cycle else '0';

  tx      <= shreg(0);
  s_ready <= ready_i;
end architecture;
