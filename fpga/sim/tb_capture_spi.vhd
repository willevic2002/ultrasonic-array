-- Testbänk för capture_spi + spi_slave.
--
-- Källan ger en sample_valid var 1024:e cykel (97,66 kHz). Utsampel n, kanal c
-- har värdet (n*16 + c) mod 2^16, så innehållet i minnet visar exakt vilka
-- sample_valid som spelades in. SPI-mastern är en BFM vid 8 MHz, läge 0.
--
-- Kontrollerar:
--   * STATUS: ID 0xA, READY låg utan ultrasonic och under SETTLE_CYCLES, hög efter
--   * PING utan READY ignoreras (ingen chirp_start, ingen inspelning)
--   * godtagen PING: exakt en chirp_start, CAPTURING, sedan DATA_VALID
--   * blocket = N_SAMPLES på varandra följande sample_valid efter PING
--   * READ från adress 0, mitten, sista ordet, hela minnet, olika bitstorlekar
--   * CS-avbrott mitt i byte (kommando, PING, svar) stör inte nästa transaktion
--   * störpulser på 6 ns på SCLK ignoreras
--   * MISO hög-Z när CS är hög; MISO stabil minst 15 ns före varje stigande SCLK
--   * andra PING skriver över och DATA_VALID nollas direkt

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.mic_array_pkg.all;

entity tb_capture_spi is
end entity;

architecture sim of tb_capture_spi is
  constant T_SYS    : time := 10 ns;
  constant T_HALF   : time := 62.5 ns; -- SCLK 8 MHz, protokollets max
  constant T_SETUP  : time := 15 ns;   -- krävd MISO-marginal före stigande SCLK
  constant N_SAMPLES    : positive := 64;
  constant SETTLE_CYCLES : natural := 500;
  constant DEPTH    : natural := N_SAMPLES * 16;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal ultrasonic, sample_valid, chirp_start : std_logic := '0';
  signal samples : sample_array := (others => (others => '0'));
  signal sclk, mosi : std_logic := '0';
  signal cs_n : std_logic := '1';
  signal miso : std_logic;

  signal pcount   : natural := 0;   -- antal utsampel hittills
  signal n_chirp  : natural := 0;
  signal k0       : natural := 0;   -- första inspelade utsampel
  signal sv_d     : std_logic := '0';
  signal glitch   : boolean := false;  -- BFM lägger 6 ns störpulser på SCLK
  signal min_margin : time := 1 ms;

  function expected(a : natural; k : natural) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(((k + a / 16) * 16 + a mod 16) mod 65536, 16));
  end function;
begin
  clk <= not clk after T_SYS / 2;

  u_dut : entity work.capture_spi
    generic map (N_SAMPLES => N_SAMPLES, SETTLE_CYCLES => SETTLE_CYCLES)
    port map (clk => clk, rst => rst, ultrasonic => ultrasonic, samples => samples,
              sample_valid => sample_valid, chirp_start => chirp_start,
              spi_sclk => sclk, spi_cs_n => cs_n, spi_mosi => mosi, spi_miso => miso);

  -- Utsampel: ny data och sample_valid samtidigt, räknare sedan reset.
  src : process (clk)
    variable c : natural := 0;
  begin
    if rising_edge(clk) then
      sample_valid <= '0';
      if rst = '1' then
        c := 0; pcount <= 0;
      else
        c := c + 1;
        if c = 1024 then
          c := 0;
          for ch in 0 to 15 loop
            samples(ch) <= signed(to_unsigned((pcount * 16 + ch) mod 65536, 16));
          end loop;
          sample_valid <= '1';
          pcount <= pcount + 1;
        end if;
      end if;
    end if;
  end process;

  -- chirp_start: räkna och notera vilket utsampel som är nästa.
  mon : process (clk)
  begin
    if rising_edge(clk) then
      sv_d <= sample_valid;
      if chirp_start = '1' then
        assert sv_d = '1' report "FAIL: chirp_start inte i fas med sample_valid" severity failure;
        n_chirp <= n_chirp + 1;
        k0 <= pcount;
      end if;
    end if;
  end process;

  -- MISO-marginal: tid sedan senaste ändring vid varje stigande SCLK.
  margin : process (sclk)
  begin
    if rising_edge(sclk) and cs_n = '0' and not glitch and miso'last_event < min_margin then
      min_margin <= miso'last_event;
    end if;
  end process;

  watchdog : process
  begin
    wait for 30 ms;
    report "FAIL: watchdog" severity failure;
  end process;

  main : process
    variable rx : std_logic_vector(7 downto 0);
    variable st : std_logic_vector(7 downto 0);
    variable seen : natural;

    procedure cs_begin is
    begin
      assert miso = 'Z' report "FAIL: MISO inte Z med CS hög" severity failure;
      cs_n <= '0';
      wait for 100 ns;
    end procedure;

    procedure cs_end is
    begin
      wait for T_HALF;
      cs_n <= '1';
      mosi <= '0';
      wait for 100 ns;
      assert miso = 'Z' report "FAIL: MISO inte Z med CS hög" severity failure;
      wait for 100 ns;
    end procedure;

    -- Skickar nbits bitar (MSB först); MISO samplas T_SETUP före stigande flank.
    procedure xfer_bits(tx : in std_logic_vector(7 downto 0); nbits : in natural;
                        rxd : out std_logic_vector(7 downto 0)) is
    begin
      rxd := (others => '0');
      for i in 0 to nbits - 1 loop
        mosi <= tx(7 - i);
        if glitch then  -- 6 ns puls mitt i låg- och högfasen, kortare än filtret
          wait for 20 ns; sclk <= '1'; wait for 6 ns; sclk <= '0';
          wait for T_HALF - T_SETUP - 26 ns;
        else
          wait for T_HALF - T_SETUP;
        end if;
        rxd(7 - i) := miso;
        wait for T_SETUP;
        sclk <= '1';
        if glitch then
          wait for 20 ns; sclk <= '0'; wait for 6 ns; sclk <= '1';
          wait for T_HALF - 26 ns;
        else
          wait for T_HALF;
        end if;
        sclk <= '0';
      end loop;
    end procedure;

    procedure xfer(tx : in std_logic_vector(7 downto 0);
                   rxd : out std_logic_vector(7 downto 0)) is
    begin
      xfer_bits(tx, 8, rxd);
    end procedure;

    procedure status(s : out std_logic_vector(7 downto 0)) is
      variable d : std_logic_vector(7 downto 0);
    begin
      cs_begin; xfer(x"01", d); xfer(x"00", s); cs_end;
      -- bit 3 (PING_TOGGLE) växlar vid varje godkänd PING, alltså en gång per chirp_start.
      assert s(7 downto 4) = x"A" and (s(3) = '1') = (n_chirp mod 2 = 1)
        report "FAIL: statusbyte ID/PING_TOGGLE fel" severity failure;
      s(3) := '0';  -- kontrollerad ovan, så att resten kan jämföra hela byten
    end procedure;

    procedure ping is
      variable d : std_logic_vector(7 downto 0);
    begin
      cs_begin; xfer(x"02", d); cs_end;
    end procedure;

    -- READ n ord från adress a, jämförs mot inspelat block som börjar vid utsampel k.
    procedure read_check(a : in natural; n : in natural; k : in natural) is
      variable d : std_logic_vector(7 downto 0);
      variable w : std_logic_vector(15 downto 0);
    begin
      cs_begin;
      xfer(x"03", d);
      xfer(std_logic_vector(to_unsigned(a / 256, 8)), d);
      xfer(std_logic_vector(to_unsigned(a mod 256, 8)), d);
      xfer(x"00", d);
      for i in 0 to n - 1 loop
        xfer(x"00", w(15 downto 8));
        xfer(x"00", w(7 downto 0));
        assert w = expected(a + i, k)
          report "FAIL: READ adress " & integer'image(a + i) & " fick " &
                 integer'image(to_integer(unsigned(w))) & " väntade " &
                 integer'image(to_integer(unsigned(expected(a + i, k))))
          severity failure;
      end loop;
      cs_end;
    end procedure;

    procedure wait_dv is
    begin
      for i in 0 to 400 loop
        status(st);
        exit when st(2) = '1';
        wait for 10 us;
      end loop;
      assert st = x"A5" or st = x"A4"
        report "FAIL: väntade DATA_VALID, status=" & to_hstring(st) severity failure;
    end procedure;

    procedure wait_clk(n : natural) is
    begin
      for i in 1 to n loop wait until rising_edge(clk); end loop;
    end procedure;
  begin
    wait for 100 ns;
    rst <= '0';
    wait_clk(10);

    -- 1. Utan ultrasonic: READY låg, PING ignoreras.
    status(st);
    assert st = x"A0" report "FAIL: status utan ultrasonic " & to_hstring(st) severity failure;
    ping;
    wait_clk(50);
    assert n_chirp = 0 report "FAIL: chirp utan READY" severity failure;

    -- 2. Under settle: fortfarande låg, PING ignoreras.
    ultrasonic <= '1';
    wait for 100 ns;
    status(st);
    assert st = x"A0" report "FAIL: READY under settle " & to_hstring(st) severity failure;
    ping;
    assert n_chirp = 0 report "FAIL: chirp under settle" severity failure;

    -- 3. Efter settle: READY.
    wait for 10 us;
    status(st);
    assert st = x"A1" report "FAIL: READY saknas " & to_hstring(st) severity failure;

    -- 4. CS-avbrott: halv kommandobyte, och PING med 7 av 8 bitar, ska inte göra något.
    cs_begin; xfer_bits(x"03", 5, rx); cs_end;
    cs_begin; xfer_bits(x"02", 7, rx); cs_end;
    wait_clk(50);
    assert n_chirp = 0 report "FAIL: avbruten PING togs emot" severity failure;
    status(st);
    assert st = x"A1" report "FAIL: status efter avbrott " & to_hstring(st) severity failure;

    -- 5. Riktig PING: en chirp_start, CAPTURING, sedan DATA_VALID.
    ping;
    wait_clk(1100);                     -- chirpen väntar på nästa sample_valid
    assert n_chirp = 1 report "FAIL: chirp_start saknas/dubbel efter PING" severity failure;
    status(st);
    assert st = x"A2" report "FAIL: status under inspelning " & to_hstring(st) severity failure;
    ping;                               -- ignoreras: spelar redan in
    wait_clk(5);
    assert n_chirp = 1 report "FAIL: PING under inspelning godtogs" severity failure;
    seen := pcount;
    wait_dv;
    assert pcount >= seen + (N_SAMPLES - 2) report "FAIL: DATA_VALID för tidigt" severity failure;
    wait_clk(5);
    assert n_chirp = 1 report "FAIL: fler än en chirp_start" severity failure;
    -- Låt ytterligare sampel passera: blocket får inte skrivas över.
    wait for 300 us;
    status(st);
    assert st = x"A5" report "FAIL: status efter inspelning " & to_hstring(st) severity failure;

    -- 6. READ, olika adresser och storlekar.
    read_check(0, 1, k0);
    read_check(0, 16, k0);
    read_check(500, 37, k0);
    read_check(DEPTH - 1, 1, k0);
    read_check(DEPTH - 24, 24, k0);
    read_check(0, DEPTH, k0);           -- hela minnet i en transaktion
    read_check(17, 3, k0);

    -- 7. CS-avbrott mitt i svaret, sedan normal transaktion.
    cs_begin;
    xfer(x"03", rx); xfer(x"00", rx); xfer(x"10", rx); xfer(x"00", rx);
    xfer(x"00", rx); xfer(x"00", rx); xfer_bits(x"00", 3, rx);
    cs_end;
    read_check(32, 8, k0);
    status(st);
    assert st = x"A5" report "FAIL: status efter avbrutet READ " & to_hstring(st) severity failure;

    -- 8. Andra PING skriver över; DATA_VALID nollas direkt.
    seen := k0;
    ping;
    wait_clk(1100);
    assert n_chirp = 2 report "FAIL: andra chirp_start saknas" severity failure;
    status(st);
    assert st = x"A2" report "FAIL: DATA_VALID inte nollad " & to_hstring(st) severity failure;
    wait_dv;
    wait for 100 us;
    assert k0 /= seen report "FAIL: k0 oförändrad" severity failure;
    read_check(0, DEPTH, k0);

    assert min_margin >= T_SETUP
      report "FAIL: MISO-marginal " & time'image(min_margin) severity failure;
    report "min MISO-marginal före stigande SCLK: " & time'image(min_margin);

    -- 9. Störpulser på SCLK (ringning) får inte förskjuta bitarna.
    glitch <= true;
    status(st);
    assert st = x"A5" report "FAIL: status med glitchar " & to_hstring(st) severity failure;
    read_check(0, 64, k0);
    read_check(DEPTH - 16, 16, k0);
    glitch <= false;
    report "PASS: capture_spi, k0 = " & integer'image(k0);
    stop;
    wait;
  end process;
end architecture;
