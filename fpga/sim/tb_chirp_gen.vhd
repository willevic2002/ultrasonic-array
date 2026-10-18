-- Testbänk för chirp_gen (standardgenerics: 38 -> 42 kHz, 100 000 cykler).
--
-- Kontrollerar per puls: busy exakt DURATION_CYCLES cykler, tx_n = not tx_p
-- under busy, båda '0' i vila, tx_p-period nära start ≈ 1/38 kHz och nära slut
-- ≈ 1/42 kHz (±1 %). Första pulsen får en start mitt i pulsen (ska ignoreras),
-- andra pulsen startas efter att den första är klar.

library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity tb_chirp_gen is
end entity;

architecture sim of tb_chirp_gen is
  constant CLK_HZ   : positive := 100_000_000;
  constant DURATION : positive := 100_000;

  signal clk   : std_logic := '0';
  signal rst   : std_logic := '1';
  signal start : std_logic := '0';
  signal busy, tx_p, tx_n : std_logic;
begin
  clk <= not clk after 5 ns;

  dut : entity work.chirp_gen
    port map (clk => clk, rst => rst, start => start, busy => busy, tx_p => tx_p, tx_n => tx_n);

  stim : process
    procedure pulse(inject : boolean) is
      variable n_busy, cyc, prev_rise, last_rise, first_per, last_per, n_rise : integer := 0;
      variable prev_p : std_logic := '0';
      variable idle_after : integer := 0;
      variable first_rise : integer := 0;
    begin
      wait until rising_edge(clk);
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      -- loopen samplar värden från föregående cykel
      loop
        wait until rising_edge(clk);
        cyc := cyc + 1;
        assert cyc < DURATION + 100 report "busy gick aldrig låg" severity failure;
        start <= '1' when (inject and n_busy = 1000) else '0';
        if busy = '1' then
          n_busy := n_busy + 1;
          assert tx_n = not tx_p report "tx_n /= not tx_p under busy" severity failure;
          if tx_p = '1' and prev_p = '0' then
            n_rise := n_rise + 1;
            if n_rise = 2 then first_per := n_busy - prev_rise; end if;
            last_per := n_busy - last_rise;
            prev_rise := last_rise;
            last_rise := n_busy;
            if n_rise = 1 then prev_rise := n_busy; end if;
          end if;
          prev_p := tx_p;
        else
          assert tx_p = '0' and tx_n = '0' report "tx ej 0 i vila" severity failure;
          exit when n_busy > 0;
        end if;
      end loop;
      assert n_busy = DURATION
        report "busy " & integer'image(n_busy) & " cykler, väntade " & integer'image(DURATION)
        severity failure;
      -- period i cykler: 100 MHz / 38 kHz = 2631.6, / 42 kHz = 2381.0
      assert abs(first_per - 2632) <= 26
        report "startperiod " & integer'image(first_per) severity failure;
      assert abs(last_per - 2381) <= 24
        report "slutperiod " & integer'image(last_per) severity failure;
      report "puls: busy=" & integer'image(n_busy) & " period start/slut = "
           & integer'image(first_per) & "/" & integer'image(last_per) & " cykler";
      -- ingen omstart av ignorerad start
      for k in 1 to 300 loop
        wait until rising_edge(clk);
        assert busy = '0' and tx_p = '0' and tx_n = '0' report "oväntad aktivitet efter puls" severity failure;
      end loop;
    end procedure;
  begin
    for k in 1 to 5 loop wait until rising_edge(clk); end loop;
    rst <= '0';
    for k in 1 to 20 loop
      wait until rising_edge(clk);
      assert busy = '0' and tx_p = '0' and tx_n = '0' report "ej tyst efter reset" severity failure;
    end loop;
    pulse(true);
    pulse(false);
    report "PASS: 2 pulser, busy = " & integer'image(DURATION) & " cykler, period och tx_n ok"
      severity note;
    finish;
  end process;

  watchdog : process
  begin
    wait for 10 ms;
    report "TIMEOUT" severity failure;
  end process;
end architecture;
