-- cic_decimator: CIC-filter, ordning 4, decimering 32 (docs/pipeline.md §3).
--
-- Bitexakt mot spec: 22-bitars tvåkomplement som får slå runt, fyra
-- integratorer i kedja (nya värden, bit x[n] ingår i y[n]), d[k] = y[32k+31],
-- fyra kammar, ut = mättning(c >> 5). Instansieras 16 gånger, så kammarna
-- delar EN subtraherare och körs sekventiellt (4 cykler per utsampel; det
-- finns minst 32 systemcykler mellan ingående bitar). Integratorerna uppdateras
-- också en per cykel (4 cykler per bit), så att den längsta vägen är en
-- adderare i stället för fyra i följd. Resultatet blir detsamma.
--
-- STATUS: simulerad, OTESTAT i hårdvara.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cic_decimator is
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;  -- synkron, aktiv hög
    bit_in       : in  std_logic;
    bit_valid    : in  std_logic;  -- en cykels puls per PDM-bit (högst 3,125 MHz)
    sample       : out signed(15 downto 0);  -- stabil mellan pulserna
    sample_valid : out std_logic             -- en cykels puls per utsampel
  );
end entity;

architecture rtl of cic_decimator is
  constant W : positive := 22;
  type reg_array is array (0 to 3) of signed(W - 1 downto 0);
  signal integ : reg_array := (others => (others => '0'));
  signal z     : reg_array := (others => (others => '0'));  -- kamfördröjningar
  signal v     : signed(W - 1 downto 0) := (others => '0');  -- värde genom kammarna
  signal cnt   : unsigned(4 downto 0) := (others => '0');
  signal busy  : std_logic := '0';
  signal stage : unsigned(1 downto 0) := (others => '0');
  signal ip    : natural range 0 to 3 := 0;  -- integrator som uppdateras nästa cykel (0 = vilar)
  signal outp  : std_logic := '0';  -- v har kamutvärdet, mätta och lägg ut nästa cykel
begin
  process (clk)
    variable x    : signed(W - 1 downto 0);
    variable c    : signed(W - 1 downto 0);
    variable sh   : signed(W - 1 downto 0);
  begin
    if rising_edge(clk) then
      sample_valid <= '0';
      if rst = '1' then
        integ <= (others => (others => '0'));
        z     <= (others => (others => '0'));
        cnt   <= (others => '0');
        busy  <= '0';
        stage <= (others => '0');
        ip    <= 0;
        outp  <= '0';
        sample <= (others => '0');
      else
        if bit_valid = '1' then
          if bit_in = '1' then x := to_signed(1, W); else x := to_signed(-1, W); end if;
          integ(0) <= integ(0) + x;
          ip <= 1;
        elsif ip /= 0 then
          -- integ(ip - 1) har redan sitt nya värde, precis som i en kedja i samma cykel.
          integ(ip) <= integ(ip) + integ(ip - 1);
          if ip = 3 then
            ip  <= 0;
            cnt <= cnt + 1;
            if cnt = 31 then
              v     <= integ(3) + integ(2);
              busy  <= '1';
              stage <= (others => '0');
            end if;
          else
            ip <= ip + 1;
          end if;
        end if;

        if busy = '1' then
          c := v - z(to_integer(stage));
          z(to_integer(stage)) <= v;
          v     <= c;
          stage <= stage + 1;
          if stage = 3 then
            busy <= '0';
            outp <= '1';
          end if;
        end if;

        -- Mättningen får en egen cykel, så att subtraktion och jämförelse inte ligger i följd.
        if outp = '1' then
          outp <= '0';
          sh := shift_right(v, 5);  -- aritmetiskt, avrundning nedåt
          if sh > 32767 then
            sample <= to_signed(32767, 16);
          else
            sample <= resize(sh, 16);
          end if;
          sample_valid <= '1';
        end if;
      end if;
    end if;
  end process;
end architecture;
