-- spi_slave: byte-transport för SPI-läge 0 (CPOL=0, CPHA=0), MSB först.
--
-- SCLK, CS och MOSI översamplas med systemklockan (2-vippors synkare + en
-- vippa för flankdetektering), så SCLK får vara högst 10 MHz (10 klockcykler
-- per period). Ingen egen klockdomän.
--
-- Gränssnitt mot capture_spi: efter varje komplett byte kommer rx_strobe
-- (en cykel) med rx_byte och rx_idx (0 = kommandobyten, räknar upp till 4 och
-- stannar). capture_spi svarar med tx_load + tx_byte, och byten skiftas ut
-- i nästa byte. Byte 0 får alltså alltid svaret 0x00.
--
-- MISO-timing (varför det håller vid 10 MHz): nästa bit läggs ut på fallande
-- SCLK. Flanken syns i klockdomänen tidigast efter 2 vippor och utgångsvippan
-- uppdateras en cykel senare, dvs. högst 3 cykler = 30 ns efter flanken.
-- Stigande flank kommer 50 ns efter fallande (50 % duty), marginal >= 20 ns.
-- Första biten i en byte läggs ut redan strax efter 8:e stigande flanken,
-- med mer än en halv SCLK-period i marginal.
--
-- CS hög nollställer biträknare och byteräknare, så en avbruten byte
-- försvinner spårlöst. MISO är hög-Z när CS är hög.
--
-- STATUS: simulerad, OTESTAT i hårdvara.

library ieee;
use ieee.std_logic_1164.all;

entity spi_slave is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;  -- synkron, aktiv hög
    spi_sclk  : in  std_logic;  -- asynkron
    spi_cs_n  : in  std_logic;  -- asynkron
    spi_mosi  : in  std_logic;  -- asynkron
    spi_miso  : out std_logic;
    rx_strobe : out std_logic;  -- en cykels puls per mottagen byte
    rx_byte   : out std_logic_vector(7 downto 0);
    rx_idx    : out natural range 0 to 4;
    tx_load   : in  std_logic;  -- puls: tx_byte skiftas ut i nästa byte
    tx_byte   : in  std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of spi_slave is
  signal s1, s2, s3 : std_logic := '0';  -- SCLK, s3 = föregående s2
  signal c1, c2     : std_logic := '1';  -- CS
  signal m1, m2     : std_logic := '0';  -- MOSI
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of s1, s2, c1, c2, m1, m2 : signal is "TRUE";
  signal rx_sh, sh  : std_logic_vector(7 downto 0) := (others => '0');
  signal bit_cnt    : natural range 0 to 7 := 0;
  signal idx        : natural range 0 to 4 := 0;
begin
  spi_miso <= sh(7) when c2 = '0' else 'Z';

  process (clk)
  begin
    if rising_edge(clk) then
      s1 <= spi_sclk; s2 <= s1; s3 <= s2;
      c1 <= spi_cs_n; c2 <= c1;
      m1 <= spi_mosi; m2 <= m1;
      rx_strobe <= '0';

      if rst = '1' or c2 = '1' then
        bit_cnt <= 0;
        idx     <= 0;
        sh      <= (others => '0');
      else
        if s3 = '0' and s2 = '1' then          -- stigande: MOSI samplas
          rx_sh <= rx_sh(6 downto 0) & m2;
          if bit_cnt = 7 then
            bit_cnt   <= 0;
            rx_strobe <= '1';
            rx_byte   <= rx_sh(6 downto 0) & m2;
            rx_idx    <= idx;
            if idx < 4 then idx <= idx + 1; end if;
          else
            bit_cnt <= bit_cnt + 1;
          end if;
        elsif s3 = '1' and s2 = '0' then       -- fallande: nästa MISO-bit
          if bit_cnt /= 0 then                 -- bit_cnt = 0: byten är nyladdad
            sh <= sh(6 downto 0) & '0';
          end if;
        end if;
        if tx_load = '1' then sh <= tx_byte; end if;
      end if;
    end if;
  end process;
end architecture;
