-- uart_spi_bridge: PC (UART) -> SPI-master mot capture_spi, för selftest utan Pi.
--
-- Protokoll från PC:n: 2 byte längd L (big-endian, 1..65535), sedan L byte.
-- Bryggan drar cs_n låg, och för varje mottagen UART-byte skiftas den ut som SPI-master
-- (läge 0, MSB först, SCLK-halvperiod 12 cykler = 4,17 MHz). MISO samplas på stigande
-- SCLK och byten skickas tillbaka över UART. Efter L byte går cs_n hög (>= 1 µs paus).
-- Tystnad > TIMEOUT_CYCLES mitt i en ram (10 ms) avbryter: cs_n hög, väntar på ny header,
-- så att PC:n kan synka om. L = 0 ignoreras.
--
-- Ingen buffring behövs: UART-byte tar 5 µs, SPI-byte ca 2 µs. Svaret väntar på att
-- uart_tx blivit ledig, så ingen byte tappas.
--
-- STATUS: simulerad (fpga/selftest/tb_selftest_top.vhd), OTESTAT i hårdvara.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_spi_bridge is
  generic (
    HALF_PERIOD    : positive := 12;
    TIMEOUT_CYCLES : positive := 1_000_000  -- 10 ms
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;  -- synkron, aktiv hög
    rx_valid : in  std_logic;
    rx_data  : in  std_logic_vector(7 downto 0);
    tx_start : out std_logic;
    tx_data  : out std_logic_vector(7 downto 0);
    tx_busy  : in  std_logic;
    spi_sclk : out std_logic;
    spi_cs_n : out std_logic;
    spi_mosi : out std_logic;
    spi_miso : in  std_logic
  );
end entity;

architecture rtl of uart_spi_bridge is
  type state_t is (HDR_HI, HDR_LO, CS_SETUP, WAIT_BYTE, SHIFT, SEND, IDLE_GAP);
  signal state   : state_t := HDR_HI;
  signal len_hi  : std_logic_vector(7 downto 0) := (others => '0');
  signal remain  : unsigned(15 downto 0) := (others => '0');
  signal cnt     : natural range 0 to 255 := 0;  -- halvperiod, CS-väntan, paus
  signal bitn    : natural range 0 to 7 := 0;
  signal sclk    : std_logic := '0';
  signal sh      : std_logic_vector(7 downto 0) := (others => '0');  -- ut: MOSI, skiftas på fallande
  signal rsh     : std_logic_vector(7 downto 0) := (others => '0');  -- in: MISO, skiftas på stigande
  signal silence : natural range 0 to TIMEOUT_CYCLES := 0;
  signal cs_n    : std_logic := '1';
begin
  spi_sclk <= sclk;
  spi_cs_n <= cs_n;
  spi_mosi <= sh(7);

  process (clk)
  begin
    if rising_edge(clk) then
      tx_start <= '0';

      -- Tystnadsvakt: räknar bara mitt i en ram.
      if state = HDR_HI or rx_valid = '1' then
        silence <= 0;
      elsif silence < TIMEOUT_CYCLES then
        silence <= silence + 1;
      end if;

      case state is
        when HDR_HI =>
          if rx_valid = '1' then len_hi <= rx_data; state <= HDR_LO; end if;
        when HDR_LO =>
          if rx_valid = '1' then
            remain <= unsigned(len_hi & rx_data);
            if (len_hi & rx_data) = x"0000" then
              state <= HDR_HI;
            else
              cs_n <= '0'; cnt <= 0; state <= CS_SETUP;
            end if;
          end if;
        when CS_SETUP =>                     -- >= en SCLK-period (2*HALF_PERIOD) innan första flanken
          if cnt = 2 * HALF_PERIOD then state <= WAIT_BYTE; else cnt <= cnt + 1; end if;
        when WAIT_BYTE =>
          if rx_valid = '1' then
            sh <= rx_data; bitn <= 0; cnt <= 0; sclk <= '0'; state <= SHIFT;
          end if;
        when SHIFT =>
          if cnt = HALF_PERIOD - 1 then
            cnt <= 0;
            if sclk = '0' then
              sclk <= '1';
              rsh  <= rsh(6 downto 0) & spi_miso;
            else
              sclk <= '0';
              sh   <= sh(6 downto 0) & '0';
              if bitn = 7 then state <= SEND; else bitn <= bitn + 1; end if;
            end if;
          else
            cnt <= cnt + 1;
          end if;
        when SEND =>                         -- rsh innehåller nu MISO-byten
          if tx_busy = '0' then
            tx_start <= '1'; tx_data <= rsh;
            remain <= remain - 1;
            if remain = 1 then
              cs_n <= '1'; cnt <= 0; state <= IDLE_GAP;
            else
              state <= WAIT_BYTE;
            end if;
          end if;
        when IDLE_GAP =>                     -- >= 1 µs med cs_n hög
          if cnt = 100 then state <= HDR_HI; else cnt <= cnt + 1; end if;
      end case;

      if state /= HDR_HI and state /= HDR_LO and state /= IDLE_GAP and silence = TIMEOUT_CYCLES then
        cs_n <= '1'; sclk <= '0'; cnt <= 0; state <= IDLE_GAP;  -- avbryt, PC:n synkar om
      end if;
      if state = HDR_LO and silence = TIMEOUT_CYCLES then
        state <= HDR_HI;
      end if;

      if rst = '1' then
        state <= HDR_HI; cs_n <= '1'; sclk <= '0'; silence <= 0;
      end if;
    end if;
  end process;
end architecture;
