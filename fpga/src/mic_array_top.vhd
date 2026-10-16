-- mic_array_top: toppnivå för Boolean Board. Kopplar ihop hela kedjan i
-- docs/pipeline.md: klocka -> 8 PDM-linjer -> 16 CIC -> inspelning/SPI, och chirp ut.
--
-- Reset kommer från en power-on-räknare, så inga knappar behövs.
-- Generics finns för att simuleringen ska kunna korta tiderna.
--
-- STATUS: simulerad (fpga/sim/tb_mic_array_top.vhd), OTESTAT i hårdvara.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mic_array_pkg.all;

entity mic_array_top is
  generic (
    STARTUP_CYCLES : natural  := 2_000_000;  -- 20 ms
    SETTLE_CYCLES  : natural  := 1_000_000;  -- 10 ms
    N_SAMPLES      : positive := 2048;
    CHIRP_CYCLES   : positive := 100_000     -- 1 ms
  );
  port (
    clk      : in  std_logic;                     -- 100 MHz
    pdm_data : in  std_logic_vector(7 downto 0);
    mic_clk  : out std_logic;
    tx_p     : out std_logic;
    tx_n     : out std_logic;
    spi_sclk : in  std_logic;
    spi_cs_n : in  std_logic;
    spi_mosi : in  std_logic;
    spi_miso : out std_logic
  );
end entity;

architecture rtl of mic_array_top is
  signal por_cnt : unsigned(3 downto 0) := (others => '0');
  signal rst     : std_logic := '1';

  signal sample_r, sample_f, ultrasonic : std_logic;
  signal bits, bits_valid : std_logic_vector(N_CH - 1 downto 0);
  signal samples       : sample_array;
  signal samples_valid : std_logic_vector(N_CH - 1 downto 0);
  signal chirp_start   : std_logic;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if por_cnt /= 15 then
        por_cnt <= por_cnt + 1;
      else
        rst <= '0';
      end if;
    end if;
  end process;

  u_clk : entity work.pdm_clock_gen
    generic map (HALF_PERIOD_START => 32, HALF_PERIOD_RUN => 16, STARTUP_CYCLES => STARTUP_CYCLES)
    port map (clk => clk, rst => rst, mic_clk => mic_clk,
              sample_r => sample_r, sample_f => sample_f, ultrasonic => ultrasonic);

  g_line : for k in 0 to 7 generate
    u_cap : entity work.pdm_pair_capture
      port map (clk => clk, rst => rst, pdm_data => pdm_data(k),
                sample_r => sample_r, sample_f => sample_f,
                bit_r => bits(2 * k),     valid_r => bits_valid(2 * k),
                bit_f => bits(2 * k + 1), valid_f => bits_valid(2 * k + 1));
  end generate;

  g_cic : for ch in 0 to N_CH - 1 generate
    u_cic : entity work.cic_decimator
      port map (clk => clk, rst => rst, bit_in => bits(ch), bit_valid => bits_valid(ch),
                sample => samples(ch), sample_valid => samples_valid(ch));
  end generate;

  -- f-kanalernas bitar kommer en halv mic_clk-period efter r-kanalernas, så när
  -- kanal 1 har ett nytt sampel har alla 16 det. Värdena står still i ca 10 µs.
  u_capture : entity work.capture_spi
    generic map (N_SAMPLES => N_SAMPLES, SETTLE_CYCLES => SETTLE_CYCLES)
    port map (clk => clk, rst => rst, ultrasonic => ultrasonic,
              samples => samples, sample_valid => samples_valid(1),
              chirp_start => chirp_start,
              spi_sclk => spi_sclk, spi_cs_n => spi_cs_n, spi_mosi => spi_mosi, spi_miso => spi_miso);

  u_chirp : entity work.chirp_gen
    generic map (DURATION_CYCLES => CHIRP_CYCLES)
    port map (clk => clk, rst => rst, start => chirp_start, busy => open, tx_p => tx_p, tx_n => tx_n);
end architecture;
