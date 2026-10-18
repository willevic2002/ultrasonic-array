-- Simulering av hela kedjan: mic_array_top med 16 modellerade mikrofoner och en
-- SPI-master som gör som Pi:n (STATUS, PING, READ).
--
-- Körs av fpga/sim/run_e2e.sh, som först skapar e2e_stim.txt med Python-modellen
-- (en rad per mic_clk-period, 16 tecken '0'/'1', tecken i = kanal i) och sedan
-- kontrollerar resultatet. Testbänken själv kontrollerar bara protokollet;
-- att datan är bitexakt och att ekot hamnar rätt kontrolleras i e2e.py.
--
-- Mikrofonmodell: före chirpen och efter filens slut driver alla kanaler
-- tystnad (0101...). Från första stigande mic_clk-flanken efter chirpstart läses
-- filen. Varje driven bit loggas i e2e_fed_bits.txt (samma format, från reset),
-- så att Python kan räkna CIC:en på exakt samma bitar.
--
-- Utfiler (i build/e2e_mic_array_top/): e2e_fed_bits.txt, e2e_captured.txt
-- (en rad per sampel, 16 heltal), e2e_meta.txt (start_period = perioden då filen började läsas).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

entity e2e_mic_array_top is
  generic (
    N_SAMPLES : positive := 384;
    STIM_FILE : string   := "e2e_stim.txt"
  );
end entity;

architecture sim of e2e_mic_array_top is
  constant T_SYS  : time := 10 ns;
  constant T_DV   : time := 40 ns;    -- databladets max för tDD
  constant T_SCLK : time := 125 ns;   -- 8 MHz, protokollets max
  constant CHUNK  : positive := 1024; -- ord per READ, som Pi:n

  signal clk      : std_logic := '0';
  signal pdm_data : std_logic_vector(7 downto 0) := (others => '0');
  signal mic_clk, tx_p, tx_n, spi_miso : std_logic;
  signal spi_sclk : std_logic := '0';
  signal spi_cs_n : std_logic := '1';
  signal spi_mosi : std_logic := '0';
  signal chirp_seen : boolean := false;

  function to_sl(c : character) return std_logic is
  begin
    if c = '1' then return '1'; else return '0'; end if;
  end function;
begin
  clk <= not clk after T_SYS / 2;

  dut : entity work.mic_array_top
    generic map (STARTUP_CYCLES => 2000, SETTLE_CYCLES => 2000,
                 N_SAMPLES => N_SAMPLES, CHIRP_CYCLES => 100_000)
    port map (clk => clk, pdm_data => pdm_data, mic_clk => mic_clk,
              tx_p => tx_p, tx_n => tx_n,
              spi_sclk => spi_sclk, spi_cs_n => spi_cs_n,
              spi_mosi => spi_mosi, spi_miso => spi_miso);

  -- tx_n går hög direkt när pulsen startar (tx_p först efter en halv period).
  process (tx_p, tx_n)
  begin
    if tx_p = '1' or tx_n = '1' then
      chirp_seen <= true;
    end if;
  end process;

  mic_model : process
    file stim, fed, meta : text;
    variable st        : file_open_status;
    variable lin, lout : line;
    variable bits      : string(1 to 16);
    variable started   : boolean := false;
    variable period    : natural := 0;
    variable v         : std_logic_vector(7 downto 0);
  begin
    file_open(st, stim, STIM_FILE, read_mode);
    assert st = open_ok
      report "saknar " & STIM_FILE & ", kör fpga/sim/run_e2e.sh" severity failure;
    file_open(fed, "e2e_fed_bits.txt", write_mode);
    loop
      wait until rising_edge(mic_clk);
      if not started and chirp_seen then
        started := true;
        file_open(meta, "e2e_meta.txt", write_mode);
        write(lout, string'("start_period ")); write(lout, period);
        writeline(meta, lout);
        file_close(meta);
      end if;
      if started and not endfile(stim) then
        readline(stim, lin);
        read(lin, bits);
      else
        bits := (others => character'val(character'pos('0') + period mod 2));
      end if;

      -- r-mikrofonerna (kanal 2k) driver efter stigande flank ...
      for k in 0 to 7 loop v(k) := to_sl(bits(2 * k + 1)); end loop;
      pdm_data <= (others => 'X') after 5 ns, v after T_DV;
      -- ... f-mikrofonerna (kanal 2k+1) efter fallande.
      wait until falling_edge(mic_clk);
      for k in 0 to 7 loop v(k) := to_sl(bits(2 * k + 2)); end loop;
      pdm_data <= (others => 'X') after 5 ns, v after T_DV;

      write(lout, bits);
      writeline(fed, lout);
      period := period + 1;
    end loop;
  end process;

  ctrl : process
    type word_array is array (0 to 16 * N_SAMPLES - 1) of integer;
    variable words : word_array;
    variable rx, hi, lo : std_logic_vector(7 downto 0);
    variable n, base : natural;
    file cap : text;
    variable lout : line;

    procedure xfer(tx : in std_logic_vector(7 downto 0); r : out std_logic_vector(7 downto 0)) is
    begin
      for i in 7 downto 0 loop
        spi_mosi <= tx(i);
        wait for T_SCLK / 2;
        r(i) := spi_miso;  -- mastern läser på stigande flank
        spi_sclk <= '1';
        wait for T_SCLK / 2;
        spi_sclk <= '0';
      end loop;
    end procedure;

    procedure cs(low : boolean) is
    begin
      if low then
        spi_cs_n <= '0';
        wait for T_SCLK;
      else
        wait for T_SCLK / 2;
        spi_cs_n <= '1';
        wait for T_SCLK;
      end if;
    end procedure;

    procedure status(s : out std_logic_vector(7 downto 0)) is
      variable d : std_logic_vector(7 downto 0);
    begin
      cs(true);
      xfer(x"01", d);
      xfer(x"00", s);
      cs(false);
      assert s(7 downto 4) = x"A"
        report "fel ID i statusbyte: " & to_hstring(s) severity failure;
    end procedure;
  begin
    -- Vänta på READY (ultraljudsläge + SETTLE_CYCLES).
    loop
      wait for 20 us;
      status(rx);
      exit when rx(0) = '1';
    end loop;

    cs(true); xfer(x"02", rx); cs(false);  -- PING

    loop
      wait for 100 us;
      status(rx);
      exit when rx(2) = '1';
    end loop;
    report "inspelning klar, läser " & integer'image(16 * N_SAMPLES) & " ord";

    base := 0;
    while base < 16 * N_SAMPLES loop
      n := minimum(CHUNK, 16 * N_SAMPLES - base);
      cs(true);
      xfer(x"03", rx);
      xfer(std_logic_vector(to_unsigned(base / 256, 8)), rx);
      xfer(std_logic_vector(to_unsigned(base mod 256, 8)), rx);
      xfer(x"00", rx);
      for i in 0 to n - 1 loop
        xfer(x"00", hi);
        xfer(x"00", lo);
        words(base + i) := to_integer(signed(std_logic_vector'(hi & lo)));
      end loop;
      cs(false);
      base := base + n;
    end loop;

    file_open(cap, "e2e_captured.txt", write_mode);
    for s in 0 to N_SAMPLES - 1 loop
      for ch in 0 to 15 loop
        write(lout, words(s * 16 + ch));
        if ch /= 15 then write(lout, ' '); end if;
      end loop;
      writeline(cap, lout);
    end loop;
    file_close(cap);

    report "PASS: protokollet fungerar, " & integer'image(N_SAMPLES) & " sampel sparade" severity note;
    finish;
  end process;

  watchdog : process
  begin
    wait for 60 ms;
    report "TIMEOUT" severity failure;
  end process;
end architecture;
