-- blinky: toggles an LED at a configurable rate.
--
-- The LED toggles every CLK_FREQ_HZ / (2 * BLINK_FREQ_HZ) clock cycles,
-- yielding a square wave with frequency BLINK_FREQ_HZ.

library ieee;
use ieee.std_logic_1164.all;

entity blinky is
  generic (
    CLK_FREQ_HZ   : positive := 100_000_000;
    BLINK_FREQ_HZ : positive := 1
  );
  port (
    clk : in  std_logic;
    rst : in  std_logic;  -- synchronous, active high
    led : out std_logic
  );
end entity;

architecture rtl of blinky is
  -- natural (not positive) so that the assert below can report bad generics
  constant HALF_PERIOD : natural := CLK_FREQ_HZ / (2 * BLINK_FREQ_HZ);

  signal counter : natural range 0 to HALF_PERIOD := 0;
  signal led_i   : std_logic := '0';
begin
  assert CLK_FREQ_HZ >= 2 * BLINK_FREQ_HZ
    report "blinky: CLK_FREQ_HZ must be at least 2 * BLINK_FREQ_HZ"
    severity failure;

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        counter <= 0;
        led_i   <= '0';
      elsif counter = HALF_PERIOD - 1 then
        counter <= 0;
        led_i   <= not led_i;
      else
        counter <= counter + 1;
      end if;
    end if;
  end process;

  led <= led_i;
end architecture;
