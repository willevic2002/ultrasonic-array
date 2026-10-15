-- Testbänk för pdm_clock_gen + pdm_pair_capture.
--
-- Modellerar två mikrofoner på samma DATA-linje: efter varje stigande flank
-- driver mikrofon R nästa bit ur PAT_R, efter varje fallande flank driver
-- mikrofon F nästa bit ur PAT_F. Linjen är 'X' mellan flanken och T_DV, så
-- att en inläsning vid fel tidpunkt syns direkt.
--
-- Kontrollerar:
--   * mic_clk-perioden i start- och ultraljudsläge (640 ns resp. 320 ns)
--   * att N_CHECK bitar per kanal läses in korrekt, över båda lägena
--
-- Modellen är en förenkling (ingen hög-Z-övergång, fast tDV). VERIFIERA
-- tidsparametrarna mot databladet.

library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity tb_pdm_pair_capture is
end entity;

architecture sim of tb_pdm_pair_capture is
  constant T_SYS   : time := 10 ns;   -- 100 MHz
  constant T_DV    : time := 40 ns;   -- antagen data-valid-tid efter flank
  constant PAT_R   : std_logic_vector(63 downto 0) := x"DEADBEEFCAFEF00D";
  constant PAT_F   : std_logic_vector(63 downto 0) := x"0123456789ABCDEF";
  constant N_CHECK : natural := 200;

  signal clk      : std_logic := '0';
  signal rst      : std_logic := '1';
  signal pdm_data : std_logic := '0';
  signal mic_clk, sample_r, sample_f, ultrasonic : std_logic;
  signal bit_r, valid_r, bit_f, valid_f          : std_logic;
  signal n_r, n_f : natural := 0;
begin
  clk <= not clk after T_SYS / 2;
  rst <= '0' after 100 ns;

  u_clk : entity work.pdm_clock_gen
    generic map (HALF_PERIOD_START => 32, HALF_PERIOD_RUN => 16, STARTUP_CYCLES => 2000)
    port map (clk => clk, rst => rst, mic_clk => mic_clk,
              sample_r => sample_r, sample_f => sample_f, ultrasonic => ultrasonic);

  u_cap : entity work.pdm_pair_capture
    port map (clk => clk, rst => rst, pdm_data => pdm_data,
              sample_r => sample_r, sample_f => sample_f,
              bit_r => bit_r, valid_r => valid_r, bit_f => bit_f, valid_f => valid_f);

  mic_model : process
    variable k_r, k_f : natural := 0;
  begin
    loop
      wait until rising_edge(mic_clk);
      pdm_data <= 'X' after 5 ns, PAT_R(k_r mod 64) after T_DV;
      k_r := k_r + 1;
      wait until falling_edge(mic_clk);
      pdm_data <= 'X' after 5 ns, PAT_F(k_f mod 64) after T_DV;
      k_f := k_f + 1;
    end loop;
  end process;

  checker : process (clk)
  begin
    if rising_edge(clk) then
      if valid_r = '1' then
        assert bit_r = PAT_R(n_r mod 64)
          report "bit_r fel vid index " & integer'image(n_r) severity failure;
        n_r <= n_r + 1;
      end if;
      if valid_f = '1' then
        -- index 0 läses före första fallande flanken och är skräp
        if n_f > 0 then
          assert bit_f = PAT_F((n_f - 1) mod 64)
            report "bit_f fel vid index " & integer'image(n_f - 1) severity failure;
        end if;
        n_f <= n_f + 1;
      end if;
    end if;
  end process;

  ctrl : process
    variable t0 : time;
  begin
    wait until rising_edge(mic_clk);
    t0 := now;
    wait until rising_edge(mic_clk);
    assert now - t0 = 640 ns
      report "fel period i startläge: " & time'image(now - t0) severity failure;

    wait until ultrasonic = '1';
    wait until rising_edge(mic_clk);
    t0 := now;
    wait until rising_edge(mic_clk);
    assert now - t0 = 320 ns
      report "fel period i ultraljudsläge: " & time'image(now - t0) severity failure;

    wait until n_r >= N_CHECK and n_f > N_CHECK;
    report "PASS: " & integer'image(n_r) & " + " & integer'image(n_f - 1)
         & " bitar korrekt inlästa" severity note;
    finish;
  end process;

  watchdog : process
  begin
    wait for 1 ms;
    report "TIMEOUT" severity failure;
  end process;
end architecture;
