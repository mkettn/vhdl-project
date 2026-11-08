-- uart_tx: 8N1 UART transmitter with a valid/ready input stream.
--
-- A byte is accepted when s_valid and s_ready are both high on a rising
-- clock edge. s_ready is low while a frame is being transmitted.

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
  constant CLKS_PER_BIT : positive := CLK_FREQ_HZ / BAUD_RATE;

  type state_t is (IDLE, SENDING);
  signal state : state_t := IDLE;

  -- Frame shift register: stop & data & start, shifted out LSB first.
  signal shreg    : std_logic_vector(9 downto 0) := (others => '1');
  signal bit_cnt  : natural range 0 to 9 := 0;
  signal baud_cnt : natural range 0 to CLKS_PER_BIT - 1 := 0;
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
            if baud_cnt = CLKS_PER_BIT - 1 then
              baud_cnt <= 0;
              shreg    <= '1' & shreg(9 downto 1);
              if bit_cnt = 9 then
                state <= IDLE;
              else
                bit_cnt <= bit_cnt + 1;
              end if;
            else
              baud_cnt <= baud_cnt + 1;
            end if;
        end case;
      end if;
    end if;
  end process;

  tx      <= shreg(0);
  s_ready <= '1' when state = IDLE else '0';
end architecture;
