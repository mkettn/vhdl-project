-- sync_fifo: simple single-clock FIFO with valid/ready handshakes.

library ieee;
use ieee.std_logic_1164.all;

entity sync_fifo is
  generic (
    WIDTH : positive := 8;
    DEPTH : positive := 16
  );
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;
    -- write side
    s_data  : in  std_logic_vector(WIDTH - 1 downto 0);
    s_valid : in  std_logic;
    s_ready : out std_logic;
    -- read side (first-word fall-through)
    m_data  : out std_logic_vector(WIDTH - 1 downto 0);
    m_valid : out std_logic;
    m_ready : in  std_logic
  );
end entity;

architecture rtl of sync_fifo is
  type mem_t is array (0 to DEPTH - 1) of std_logic_vector(WIDTH - 1 downto 0);
  signal mem : mem_t;

  signal rd_ptr, wr_ptr : natural range 0 to DEPTH - 1 := 0;
  signal count          : natural range 0 to DEPTH := 0;

  signal full, empty : std_logic;
  signal do_wr, do_rd : boolean;

  -- Pointer values after the next increment, wrapping at DEPTH.
  signal rd_ptr_next, wr_ptr_next : natural range 0 to DEPTH - 1;
begin
  rd_ptr_next <= 0 when rd_ptr = DEPTH - 1 else rd_ptr + 1;
  wr_ptr_next <= 0 when wr_ptr = DEPTH - 1 else wr_ptr + 1;

  full  <= '1' when count = DEPTH else '0';
  empty <= '1' when count = 0 else '0';

  do_wr <= s_valid = '1' and full = '0';
  do_rd <= m_ready = '1' and empty = '0';

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        rd_ptr <= 0;
        wr_ptr <= 0;
        count  <= 0;
      else
        if do_wr then
          mem(wr_ptr) <= s_data;
          wr_ptr      <= wr_ptr_next;
        end if;
        if do_rd then
          rd_ptr <= rd_ptr_next;
        end if;
        if do_wr and not do_rd then
          count <= count + 1;
        elsif do_rd and not do_wr then
          count <= count - 1;
        end if;
      end if;
    end if;
  end process;

  s_ready <= not full;
  m_valid <= not empty;
  m_data  <= mem(rd_ptr);
end architecture;
