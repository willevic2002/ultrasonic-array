-- pdm_pair_capture: läser en PDM-datalinje som delas av två mikrofoner.
--
-- Den ena mikrofonen driver linjen efter stigande flank, den andra efter
-- fallande flank. Vilken SELECT-nivå (GND/VDD) som ger vilken flank:
-- VERIFIERA mot databladet. Här heter kanalerna efter flanken de driver på:
--   bit_r: mikrofonen som driver efter stigande flank (läses strax före fallande)
--   bit_f: mikrofonen som driver efter fallande flank (läses strax före stigande)
--
-- Datalinjen synkas med två vippor. Värdet som läses är därför 2-3
-- systemcykler (20-30 ns vid 100 MHz) gammalt vid flanken. Mikrofonens
-- data-valid-tid efter flanken måste vara kortare än halvperioden minus det
-- (160 ns - 30 ns vid 3,125 MHz). Testbänken antar 40 ns. VERIFIERA tDV.
--
-- Första valid_f efter reset kommer före någon fallande flank och är skräp.
--
-- STATUS: simulerad, OTESTAT i hårdvara.

library ieee;
use ieee.std_logic_1164.all;

entity pdm_pair_capture is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;  -- synkron, aktiv hög
    pdm_data : in  std_logic;  -- asynkron, direkt från pinnen
    sample_r : in  std_logic;  -- från pdm_clock_gen
    sample_f : in  std_logic;  -- från pdm_clock_gen
    bit_r    : out std_logic;
    valid_r  : out std_logic;  -- en cykels puls per ny bit_r
    bit_f    : out std_logic;
    valid_f  : out std_logic   -- en cykels puls per ny bit_f
  );
end entity;

architecture rtl of pdm_pair_capture is
  signal sync : std_logic_vector(1 downto 0) := "00";
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of sync : signal is "TRUE";
begin
  process (clk)
  begin
    if rising_edge(clk) then
      sync    <= sync(0) & pdm_data;
      valid_r <= '0';
      valid_f <= '0';
      if rst = '1' then
        sync  <= "00";
        bit_r <= '0';
        bit_f <= '0';
      else
        if sample_f = '1' then
          bit_r   <= sync(1);
          valid_r <= '1';
        end if;
        if sample_r = '1' then
          bit_f   <= sync(1);
          valid_f <= '1';
        end if;
      end if;
    end if;
  end process;
end architecture;
