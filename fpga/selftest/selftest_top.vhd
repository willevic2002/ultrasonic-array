-- selftest_top: mic_array_top (oförändrad) pratar med PC:n över kortets USB-UART.
-- Ersätter hårdvaran som saknas: pdm_pattern ger de 16 mikrofonernas data och
-- uart_spi_bridge är SPI-master i stället för Pi:n. Inga SPI- eller PDM-pinnar används.
--
-- LED0 hjärtslag (1 Hz), LED1 UART-aktivitet (~50 ms), LED2 chirp sedd (~200 ms),
-- LED3 SPI CS aktiv (~50 ms).
--
-- STATUS: simulerad (fpga/selftest/tb_selftest_top.vhd), OTESTAT i hårdvara.

library ieee;
use ieee.std_logic_1164.all;

entity selftest_top is
  generic (
    STARTUP_CYCLES : natural  := 2_000_000;
    SETTLE_CYCLES  : natural  := 1_000_000;
    N_SAMPLES      : positive := 2048;
    TIMEOUT_CYCLES : positive := 1_000_000  -- UART-tystnad som avbryter en ram (10 ms)
  );
  port (
    clk     : in  std_logic;                     -- 100 MHz
    uart_rx : in  std_logic;                     -- från FTDI
    uart_tx : out std_logic;
    led     : out std_logic_vector(3 downto 0)
  );
end entity;

architecture rtl of selftest_top is
  signal por_cnt : natural range 0 to 15 := 0;
  signal rst     : std_logic := '1';

  signal mic_clk, tx_p, tx_n : std_logic;
  signal pdm_data : std_logic_vector(7 downto 0);
  signal spi_sclk, spi_cs_n, spi_mosi, spi_miso : std_logic;
  signal rx_valid, tx_start, tx_busy : std_logic;
  signal rx_data, tx_data : std_logic_vector(7 downto 0);
  signal uart_tx_i : std_logic;

  signal beat   : natural range 0 to 49_999_999 := 0;
  signal hb     : std_logic := '0';
  signal st_uart, st_chirp, st_cs : natural range 0 to 20_000_000 := 0;
begin
  uart_tx <= uart_tx_i;

  process (clk)
  begin
    if rising_edge(clk) then
      if por_cnt /= 15 then por_cnt <= por_cnt + 1; else rst <= '0'; end if;
    end if;
  end process;

  u_dut : entity work.mic_array_top
    generic map (STARTUP_CYCLES => STARTUP_CYCLES, SETTLE_CYCLES => SETTLE_CYCLES, N_SAMPLES => N_SAMPLES)
    port map (clk => clk, pdm_data => pdm_data, mic_clk => mic_clk, tx_p => tx_p, tx_n => tx_n,
              spi_sclk => spi_sclk, spi_cs_n => spi_cs_n, spi_mosi => spi_mosi, spi_miso => spi_miso);

  u_pat : entity work.pdm_pattern
    port map (clk => clk, rst => rst, mic_clk => mic_clk, pdm_data => pdm_data);

  u_rx : entity work.uart_rx
    port map (clk => clk, rst => rst, rx => uart_rx, valid => rx_valid, data => rx_data);

  u_tx : entity work.uart_tx
    port map (clk => clk, rst => rst, start => tx_start, data => tx_data, busy => tx_busy, tx => uart_tx_i);

  u_bridge : entity work.uart_spi_bridge
    generic map (TIMEOUT_CYCLES => TIMEOUT_CYCLES)
    port map (clk => clk, rst => rst, rx_valid => rx_valid, rx_data => rx_data,
              tx_start => tx_start, tx_data => tx_data, tx_busy => tx_busy,
              spi_sclk => spi_sclk, spi_cs_n => spi_cs_n, spi_mosi => spi_mosi, spi_miso => spi_miso);

  -- LED:er. Aktivitet håller ett räknarvärde som räknas ner (förlängning så att korta pulser syns).
  process (clk)
    procedure stretch(signal c : inout natural; ev : boolean; len : natural) is
    begin
      if ev then c <= len; elsif c > 0 then c <= c - 1; end if;
    end procedure;
  begin
    if rising_edge(clk) then
      if beat = 49_999_999 then beat <= 0; hb <= not hb; else beat <= beat + 1; end if;
      stretch(st_uart,  uart_rx = '0' or uart_tx_i = '0', 5_000_000);
      stretch(st_chirp, tx_p = '1' or tx_n = '1',         20_000_000);
      stretch(st_cs,    spi_cs_n = '0',                    5_000_000);
    end if;
  end process;

  led(0) <= hb;
  led(1) <= '1' when st_uart  > 0 else '0';
  led(2) <= '1' when st_chirp > 0 else '0';
  led(3) <= '1' when st_cs    > 0 else '0';
end architecture;
