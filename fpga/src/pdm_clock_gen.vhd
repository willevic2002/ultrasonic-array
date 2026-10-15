-- pdm_clock_gen: genererar PDM-klockan till mikrofonerna från systemklockan.
--
-- Startar i en långsammare klocka (standardläge) och går över till
-- ultraljudsläge efter STARTUP_CYCLES. Mikrofonen ska inte starta direkt i
-- ultraljudsläge. Exakta frekvensintervall och starttid: VERIFIERA mot
-- databladet för SPH0641LU4H-1.
--
-- Med 100 MHz systemklocka och heltalsdelning är 3,072 MHz inte exakt
-- möjligt (100/3,072 = 32,55). Default ger 3,125 MHz, som ligger inom
-- ultraljudsintervallet 3,072-4,8 MHz. Behövs exakt 3,072 MHz: ta fram
-- 98,304 MHz med en MMCM (Clocking Wizard) och dela med 32.
--
-- sample_r / sample_f är kombinatoriska pulser under den systemcykel då
-- mic_clk växlar (stiger resp. faller). pdm_pair_capture läser sin
-- synkroniserade data just då, alltså det värde linjen hade strax före flanken.
--
-- STATUS: simulerad (fpga/sim/tb_pdm_pair_capture.vhd), OTESTAT i hårdvara.

library ieee;
use ieee.std_logic_1164.all;

entity pdm_clock_gen is
  generic (
    HALF_PERIOD_START : positive := 32;        -- 100 MHz / (2*32) = 1,5625 MHz (standardläge)
    HALF_PERIOD_RUN   : positive := 16;        -- 100 MHz / (2*16) = 3,125 MHz (ultraljudsläge)
    STARTUP_CYCLES    : natural  := 1_000_000  -- 10 ms vid 100 MHz
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;  -- synkron, aktiv hög
    mic_clk    : out std_logic;
    sample_r   : out std_logic;  -- '1' den cykel mic_clk stiger
    sample_f   : out std_logic;  -- '1' den cykel mic_clk faller
    ultrasonic : out std_logic   -- '1' när klockan gått över till ultraljudsläge
  );
end entity;

architecture rtl of pdm_clock_gen is
  signal div_cnt  : natural range 0 to HALF_PERIOD_START - 1 := 0;
  signal half     : natural range 1 to HALF_PERIOD_START;
  signal startup  : natural range 0 to STARTUP_CYCLES := 0;
  signal run_mode : std_logic := '0';
  signal clk_q    : std_logic := '0';
  signal toggle   : std_logic;
begin
  assert HALF_PERIOD_RUN >= 2 and HALF_PERIOD_RUN <= HALF_PERIOD_START
    report "kräver 2 <= HALF_PERIOD_RUN <= HALF_PERIOD_START" severity failure;

  half   <= HALF_PERIOD_RUN when run_mode = '1' else HALF_PERIOD_START;
  toggle <= '1' when div_cnt = half - 1 and rst = '0' else '0';

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        div_cnt  <= 0;
        clk_q    <= '0';
        startup  <= 0;
        run_mode <= '0';
      else
        if startup /= STARTUP_CYCLES then
          startup <= startup + 1;
        end if;

        if toggle = '1' then
          div_cnt <= 0;
          clk_q   <= not clk_q;
          -- Byt läge bara vid fallande flank, så att ingen halvperiod kortas av.
          if clk_q = '1' and startup = STARTUP_CYCLES then
            run_mode <= '1';
          end if;
        else
          div_cnt <= div_cnt + 1;
        end if;
      end if;
    end if;
  end process;

  mic_clk    <= clk_q;
  sample_r   <= toggle and not clk_q;
  sample_f   <= toggle and clk_q;
  ultrasonic <= run_mode;
end architecture;
