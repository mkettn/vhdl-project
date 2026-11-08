-- axi_rot13: AXI4-Lite embedding of the rot13 device.
--
-- Holds the DATA_IN register and exposes the output of the rot13 device
-- instance as DATA_OUT.
--
-- Register map (32-bit registers, byte offsets):
--   0x0 DATA_IN  RW  Input word; byte strobes are honoured.
--   0x4 DATA_OUT RO  ROT13 of each byte of DATA_IN.
--   0x8 ID       RO  Constant 0x524F5431 ("ROT1").
-- Writes to read-only registers and accesses to unmapped addresses
-- respond with SLVERR.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi_rot13_pkg.all;

entity axi_rot13 is
  generic (
    -- Must cover the register map (>= 4) and keep the word index within
    -- the integer range (<= 32).
    ADDR_WIDTH : positive range 4 to 32 := 4
  );
  port (
    aclk    : in  std_logic;
    aresetn : in  std_logic;

    -- write address channel
    s_axi_awaddr  : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;
    -- write data channel
    s_axi_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;
    -- write response channel
    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;
    -- read address channel
    s_axi_araddr  : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;
    -- read data channel
    s_axi_rdata   : out std_logic_vector(31 downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic
  );
end entity;

architecture rtl of axi_rot13 is
  constant RESP_OKAY   : std_logic_vector(1 downto 0) := "00";
  constant RESP_SLVERR : std_logic_vector(1 downto 0) := "10";

  signal data_in  : std_logic_vector(31 downto 0) := (others => '0');
  signal data_out : std_logic_vector(31 downto 0);

  -- write path: address and data may arrive in any order
  signal aw_addr  : std_logic_vector(ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal aw_valid : std_logic := '0';
  signal w_data   : std_logic_vector(31 downto 0) := (others => '0');
  signal w_strb   : std_logic_vector(3 downto 0) := (others => '0');
  signal w_valid  : std_logic := '0';
  signal bvalid   : std_logic := '0';
  signal bresp    : std_logic_vector(1 downto 0) := RESP_OKAY;

  -- read path
  signal rvalid : std_logic := '0';
  signal rdata  : std_logic_vector(31 downto 0) := (others => '0');
  signal rresp  : std_logic_vector(1 downto 0) := RESP_OKAY;

  -- Address decode: both paths reduce their address to a word index
  -- (byte offset / 4) and compare it against the register map below.
  signal wr_addr          : std_logic_vector(ADDR_WIDTH - 1 downto 0);
  signal wr_word, rd_word : natural;
begin
  rot13_inst : entity work.rot13
    generic map (NUM_BYTES => 4)
    port map (
      data_in  => data_in,
      data_out => data_out
    );

  -- The write address comes from the buffer if it arrived earlier.
  wr_addr <= aw_addr when aw_valid = '1' else s_axi_awaddr;
  wr_word <= to_integer(unsigned(wr_addr(ADDR_WIDTH - 1 downto 2)));
  rd_word <= to_integer(unsigned(s_axi_araddr(ADDR_WIDTH - 1 downto 2)));

  -- Accept a new address/data beat only while nothing is buffered for it.
  s_axi_awready <= not aw_valid;
  s_axi_wready  <= not w_valid;
  s_axi_bvalid  <= bvalid;
  s_axi_bresp   <= bresp;

  s_axi_arready <= not rvalid;
  s_axi_rvalid  <= rvalid;
  s_axi_rdata   <= rdata;
  s_axi_rresp   <= rresp;

  write_proc : process (aclk)
    variable have_aw, have_w : boolean;
    variable data            : std_logic_vector(31 downto 0);
    variable strb            : std_logic_vector(3 downto 0);
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        data_in  <= (others => '0');
        aw_valid <= '0';
        w_valid  <= '0';
        bvalid   <= '0';
        bresp    <= RESP_OKAY;
      else
        if bvalid = '1' and s_axi_bready = '1' then
          bvalid <= '0';
        end if;

        -- Combine freshly arriving beats with buffered ones.
        have_aw := aw_valid = '1' or s_axi_awvalid = '1';
        have_w  := w_valid = '1' or s_axi_wvalid = '1';
        data    := w_data  when w_valid = '1'  else s_axi_wdata;
        strb    := w_strb  when w_valid = '1'  else s_axi_wstrb;

        if have_aw and have_w and (bvalid = '0' or s_axi_bready = '1') then
          -- Perform the write and issue the response.
          aw_valid <= '0';
          w_valid  <= '0';
          bvalid   <= '1';
          case wr_word is
            when REG_DATA_IN / 4 =>
              for i in 0 to 3 loop
                if strb(i) = '1' then
                  data_in(8 * i + 7 downto 8 * i) <= data(8 * i + 7 downto 8 * i);
                end if;
              end loop;
              bresp <= RESP_OKAY;
            when others =>
              -- read-only or unmapped
              bresp <= RESP_SLVERR;
          end case;
        else
          -- Buffer whichever half has arrived.
          if aw_valid = '0' and s_axi_awvalid = '1' then
            aw_addr  <= s_axi_awaddr;
            aw_valid <= '1';
          end if;
          if w_valid = '0' and s_axi_wvalid = '1' then
            w_data  <= s_axi_wdata;
            w_strb  <= s_axi_wstrb;
            w_valid <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

  read_proc : process (aclk)
  begin
    if rising_edge(aclk) then
      if aresetn = '0' then
        rvalid <= '0';
        rdata  <= (others => '0');
        rresp  <= RESP_OKAY;
      else
        if rvalid = '1' and s_axi_rready = '1' then
          rvalid <= '0';
        end if;

        if s_axi_arvalid = '1' and rvalid = '0' then
          rvalid <= '1';
          rresp  <= RESP_OKAY;
          case rd_word is
            when REG_DATA_IN / 4  => rdata <= data_in;
            when REG_DATA_OUT / 4 => rdata <= data_out;
            when REG_ID / 4       => rdata <= ROT13_ID;
            when others =>
              rdata <= (others => '0');
              rresp <= RESP_SLVERR;
          end case;
        end if;
      end if;
    end if;
  end process;
end architecture;
