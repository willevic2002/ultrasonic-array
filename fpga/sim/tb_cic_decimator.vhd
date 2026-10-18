-- Testbänk för cic_decimator.
--
-- Facit är byggt annorlunda än RTL:en: direkt faltning med kärnan boxcar^4
-- (längd 125) i heltalsaritmetik, sedan var 32:a värde, >>5 (nedåtavrundning)
-- och mättning. Varje utsampel jämförs. Stimuli: bara ettor (32767), bara
-- nollor (-32768), alternerande (0) och LFSR-slump med flera ettdensiteter.
-- Bitar kommer i verklig takt (en bit_valid per 32 systemcykler).
-- Skriver cic_in.txt (en bit per rad) och cic_out.txt (ett heltal per rad)
-- i arbetskatalogen, för jämförelse mot Python-modellen.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use std.textio.all;

entity tb_cic_decimator is
end entity;

architecture sim of tb_cic_decimator is
  constant MAX_BITS : natural := 32768;
  type int_vec is array (natural range <>) of integer;

  -- boxcar(32) faltat med sig själv tre gånger = 4*31+1 = 125 tap
  function kernel return int_vec is
    variable h, t : int_vec(0 to 124) := (others => 0);
    variable len  : natural := 32;
  begin
    h(0 to 31) := (others => 1);
    for s in 1 to 3 loop
      t := (others => 0);
      for i in 0 to len - 1 loop
        for j in 0 to 31 loop
          t(i + j) := t(i + j) + h(i);
        end loop;
      end loop;
      h := t;
      len := len + 31;
    end loop;
    return h;
  end function;
  constant H : int_vec(0 to 124) := kernel;

  signal clk, rst, bit_in, bit_valid, sample_valid : std_logic := '0';
  signal sample : signed(15 downto 0);
  signal last_out : integer := 0;
  signal n_out    : natural := 0;
begin
  clk <= not clk after 5 ns;

  dut : entity work.cic_decimator
    port map (clk => clk, rst => rst, bit_in => bit_in, bit_valid => bit_valid,
              sample => sample, sample_valid => sample_valid);

  monitor : process (clk)
  begin
    if rising_edge(clk) and sample_valid = '1' then
      last_out <= to_integer(sample);
      n_out    <= n_out + 1;
    end if;
  end process;

  stim : process
    file f_in, f_out : text;
    variable ln      : line;
    variable x       : int_vec(0 to MAX_BITS - 1);  -- +-1
    variable n       : natural := 0;                -- bitar hittills
    variable n_chk   : natural := 0;
    variable lfsr    : unsigned(31 downto 0) := x"ACE1B0B5";
    variable acc, c, expct : integer;
    variable b : std_logic;

    function lfsr_bit(l : unsigned(31 downto 0)) return std_logic is
    begin
      return l(31) xor l(21) xor l(1) xor l(0);
    end function;

    procedure next_rand(variable r : out std_logic) is
    begin
      r := lfsr_bit(lfsr);
      lfsr := lfsr(30 downto 0) & lfsr_bit(lfsr);
    end procedure;

    -- kind: 0 ettor, 1 nollor, 2 alternerande, 3 p=1/2, 4 p=1/4, 5 p=3/4, 6 p=1/16, 7 p=15/16
    procedure run(kind : natural; count : natural) is
      variable r : std_logic;
      variable start : natural := n;
    begin
      for i in 0 to count - 1 loop
        case kind is
          when 0 => b := '1';
          when 1 => b := '0';
          when 2 => b := '1' when i mod 2 = 0 else '0';
          when 3 => next_rand(b);
          when 4 => next_rand(b); next_rand(r); b := b and r;
          when 5 => next_rand(b); next_rand(r); b := b or r;
          when 6 => next_rand(b);
                    for k in 1 to 3 loop next_rand(r); b := b and r; end loop;
          when others => next_rand(b);
                    for k in 1 to 3 loop next_rand(r); b := b or r; end loop;
        end case;
        x(n) := 1 when b = '1' else -1;
        write(ln, integer'image(1 when b = '1' else 0)); writeline(f_in, ln);

        wait until rising_edge(clk);
        bit_in <= b; bit_valid <= '1';
        wait until rising_edge(clk);
        bit_valid <= '0';
        for k in 1 to 30 loop wait until rising_edge(clk); end loop;

        if n mod 32 = 31 then
          acc := 0;
          for k in 0 to 124 loop
            if n - k >= 0 then acc := acc + H(k) * x(n - k); end if;
          end loop;
          if acc >= 0 then c := acc / 32; else c := -((-acc + 31) / 32); end if;
          expct := c when c <= 32767 else 32767;
          assert n_out = n_chk + 1
            report "ingen sample_valid vid bit " & integer'image(n) severity failure;
          assert last_out = expct
            report "fel vid utsampel " & integer'image(n_chk) & ": fick "
                 & integer'image(last_out) & ", väntade " & integer'image(expct)
            severity failure;
          write(ln, last_out); writeline(f_out, ln);
          n_chk := n_chk + 1;
          if kind <= 2 and i >= 160 then
            if kind = 0 then expct := 32767; elsif kind = 1 then expct := -32768; else expct := 0; end if;
            assert last_out = expct
              report "fel stationärvärde i kind " & integer'image(kind) severity failure;
          end if;
        end if;
        n := n + 1;
      end loop;
    end procedure;
  begin
    file_open(f_in, "cic_in.txt", write_mode);
    file_open(f_out, "cic_out.txt", write_mode);
    rst <= '1';
    for k in 1 to 5 loop wait until rising_edge(clk); end loop;
    rst <= '0';

    run(0, 480);
    run(1, 480);
    run(2, 480);
    for kind in 3 to 7 loop run(kind, 4000); end loop;
    run(0, 480);  -- tillbaka till full skala efter slump

    file_close(f_in);
    file_close(f_out);
    report "PASS: " & integer'image(n_chk) & " utsampel av " & integer'image(n)
         & " bitar bitexakta mot facit" severity note;
    finish;
  end process;

  watchdog : process
  begin
    wait for 50 ms;
    report "TIMEOUT" severity failure;
  end process;
end architecture;
