-- pdm_pattern: ersätter de 16 mikrofonerna med ett inbyggt mönster (selftest).
--
-- Följer mikrofontimingen i docs/pipeline.md §1: efter stigande mic_clk läggs biten för
-- kanal 2k på linje k, efter fallande mic_clk biten för kanal 2k+1.
-- Kanal c har period 32 med k_c = 8 + c ettor: bit = 1 när ramposition p < k_c.
-- CIC:ns (N=4, R=32) stationära värde blir då exakt 2048*(c-8) oavsett fas
-- (kanal 0 = -16384 ... kanal 15 = 14336). Varje flanktyp har egen positionsräknare.
--
-- STATUS: simulerad (fpga/selftest/tb_selftest_top.vhd), OTESTAT i hårdvara.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pdm_pattern is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;  -- synkron, aktiv hög
    mic_clk  : in  std_logic;  -- intern signal i klk-domänen
    pdm_data : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of pdm_pattern is
  signal prev  : std_logic := '0';
  signal pos_r : unsigned(4 downto 0) := (others => '0');  -- ramposition för r-kanalerna
  signal pos_f : unsigned(4 downto 0) := (others => '0');
begin
  process (clk)
  begin
    if rising_edge(clk) then
      prev <= mic_clk;
      if rst = '1' then
        pos_r <= (others => '0'); pos_f <= (others => '0');
        pdm_data <= (others => '0');
      elsif mic_clk /= prev then
        if mic_clk = '1' then
          for k in 0 to 7 loop
            if pos_r < 8 + 2 * k then pdm_data(k) <= '1'; else pdm_data(k) <= '0'; end if;
          end loop;
          pos_r <= pos_r + 1;
        else
          for k in 0 to 7 loop
            if pos_f < 8 + 2 * k + 1 then pdm_data(k) <= '1'; else pdm_data(k) <= '0'; end if;
          end loop;
          pos_f <= pos_f + 1;
        end if;
      end if;
    end if;
  end process;
end architecture;
