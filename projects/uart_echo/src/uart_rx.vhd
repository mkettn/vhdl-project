-- uart_rx: 8N1 UART receiver.
--
-- m_valid pulses for one clock cycle when a byte with a valid stop bit has
-- been received. A frame with a bad stop bit pulses frame_err instead; the
-- receiver then waits for the line to return high before looking for the
-- next start bit, so a BREAK or stuck-low line yields a single frame_err.

library ieee;
use ieee.std_logic_1164.all;

entity uart_rx is
  generic (
    CLK_FREQ_HZ : positive := 100_000_000;
    BAUD_RATE   : positive := 115_200
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    rx        : in  std_logic;
    m_data    : out std_logic_vector(7 downto 0);
    m_valid   : out std_logic;
    frame_err : out std_logic
  );
end entity;

architecture rtl of uart_rx is
  -- natural (not positive) so that the assert below can report bad generics
  constant CLKS_PER_BIT : natural := CLK_FREQ_HZ / BAUD_RATE;

  type state_t is (IDLE, START, DATA, STOP, WAIT_IDLE);
  signal state : state_t := IDLE;

  -- Two-flop synchronizer for the asynchronous rx input.
  signal rx_meta, rx_sync : std_logic := '1';

  signal shreg    : std_logic_vector(7 downto 0) := (others => '0');
  signal bit_cnt  : natural range 0 to 7 := 0;
  signal baud_cnt : natural range 0 to CLKS_PER_BIT := 0;
begin
  assert CLKS_PER_BIT >= 4
    report "uart_rx: CLK_FREQ_HZ must be at least 4 * BAUD_RATE"
    severity failure;

  process (clk)
  begin
    if rising_edge(clk) then
      rx_meta <= rx;
      rx_sync <= rx_meta;

      m_valid   <= '0';
      frame_err <= '0';

      if rst = '1' then
        state    <= IDLE;
        bit_cnt  <= 0;
        baud_cnt <= 0;
        rx_meta  <= '1';
        rx_sync  <= '1';
      else
        case state is
          when IDLE =>
            if rx_sync = '0' then
              -- Wait half a bit to sample in the middle of the start bit.
              baud_cnt <= CLKS_PER_BIT / 2;
              state    <= START;
            end if;

          when START =>
            if baud_cnt = CLKS_PER_BIT - 1 then
              baud_cnt <= 0;
              if rx_sync = '0' then
                bit_cnt <= 0;
                state   <= DATA;
              else
                state <= IDLE;  -- glitch, not a real start bit
              end if;
            else
              baud_cnt <= baud_cnt + 1;
            end if;

          when DATA =>
            if baud_cnt = CLKS_PER_BIT - 1 then
              baud_cnt <= 0;
              shreg    <= rx_sync & shreg(7 downto 1);
              if bit_cnt = 7 then
                state <= STOP;
              else
                bit_cnt <= bit_cnt + 1;
              end if;
            else
              baud_cnt <= baud_cnt + 1;
            end if;

          when STOP =>
            if baud_cnt = CLKS_PER_BIT - 1 then
              baud_cnt <= 0;
              if rx_sync = '1' then
                m_valid <= '1';
                state   <= IDLE;
              else
                frame_err <= '1';
                state     <= WAIT_IDLE;
              end if;
            else
              baud_cnt <= baud_cnt + 1;
            end if;

          when WAIT_IDLE =>
            -- Line still low after a framing error (e.g. BREAK): wait for
            -- it to return high so its low level is not taken as a start bit.
            if rx_sync = '1' then
              state <= IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

  m_data <= shreg;
end architecture;
