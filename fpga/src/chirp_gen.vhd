-- chirp_gen: linjär fyrkants-chirp F_START -> F_END över DURATION_CYCLES (docs/pipeline.md §4).
--
-- Fasackumulator (48 bit) vars steg ökar linjärt. Steget hålls i en 64-bitars
-- register med 24 bråkbitar, annars blir sweepen för grov. Konstanterna räknas
-- ut vid elaborering med math_real (VHDL-integer är bara 32 bit).
-- tx_p = fasens MSB, tx_n = not tx_p under pulsen, båda '0' annars.
-- start under pågående puls ignoreras.
--
-- STATUS: simulerad, OTESTAT i hårdvara.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity chirp_gen is
  generic (
    CLK_HZ          : positive := 100_000_000;
    F_START         : positive := 38_000;
    F_END           : positive := 42_000;
    DURATION_CYCLES : positive := 100_000
  );
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;  -- synkron, aktiv hög
    start : in  std_logic;  -- en cykels puls
    busy  : out std_logic;
    tx_p  : out std_logic;
    tx_n  : out std_logic
  );
end entity;

architecture rtl of chirp_gen is
  constant PH_W : positive := 48;
  constant FR_W : positive := 64;
  constant FRAC : positive := 24;  -- bråkbitar i stegregistret

  -- real (< 2^64) till unsigned, 16 bitar åt gången
  function to_u(r : real; w : positive) return unsigned is
    variable res : unsigned(w - 1 downto 0);
    variable rem_r, q : real;
  begin
    rem_r := r;
    for i in w / 16 - 1 downto 0 loop
      q := floor(rem_r / (2.0 ** (16 * i)));
      res(16 * i + 15 downto 16 * i) := to_unsigned(integer(q), 16);
      rem_r := rem_r - q * (2.0 ** (16 * i));
    end loop;
    return res;
  end function;

  -- steg per cykel (fasenheter) för en frekvens, i FRAC-bråkenheter
  function step(f : positive) return real is
  begin
    return real(f) * (2.0 ** (PH_W + FRAC)) / real(CLK_HZ);
  end function;

  constant INC0 : unsigned(FR_W - 1 downto 0) := to_u(step(F_START), FR_W);
  constant DINC : unsigned(FR_W - 1 downto 0) :=
    to_u((step(F_END) - step(F_START)) / real(DURATION_CYCLES), FR_W);

  signal phase : unsigned(PH_W - 1 downto 0) := (others => '0');
  signal inc   : unsigned(FR_W - 1 downto 0) := (others => '0');
  signal cnt   : natural range 0 to DURATION_CYCLES - 1 := 0;
  signal busy_i : std_logic := '0';
begin
  busy <= busy_i;

  process (clk)
    variable nph : unsigned(PH_W - 1 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        busy_i <= '0';
        tx_p   <= '0';
        tx_n   <= '0';
        phase  <= (others => '0');
      elsif busy_i = '0' then
        if start = '1' then
          busy_i <= '1';
          phase  <= (others => '0');
          inc    <= INC0;
          cnt    <= 0;
          tx_p   <= '0';
          tx_n   <= '1';
        end if;
      else
        nph   := phase + inc(FR_W - 1 downto FRAC);
        phase <= nph;
        inc   <= inc + DINC;
        tx_p  <= nph(PH_W - 1);
        tx_n  <= not nph(PH_W - 1);
        cnt   <= cnt + 1;
        if cnt = DURATION_CYCLES - 1 then
          busy_i <= '0';
          tx_p   <= '0';
          tx_n   <= '0';
        end if;
      end if;
    end if;
  end process;
end architecture;
