-- uart_tx: UART-sändare 8N1, 2 Mbaud (50 klockcykler per bit vid 100 MHz).
--
-- Puls på start när busy = '0' tar emot en byte. Den går ut direkt om sändaren är ledig,
-- annars väntar den i ett hållregister och startar utan lucka efter pågående byte
-- (annars blir takten 502 i stället för 500 cykler/byte och bryggan halkar efter PC:n).
-- busy = hållregistret är fullt.
--
-- STATUS: simulerad (fpga/selftest/tb_selftest_top.vhd), OTESTAT i hårdvara.

library ieee;
use ieee.std_logic_1164.all;

entity uart_tx is
  generic (CLKS_PER_BIT : positive := 50);
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;  -- synkron, aktiv hög
    start : in  std_logic;
    data  : in  std_logic_vector(7 downto 0);
    busy  : out std_logic;
    tx    : out std_logic
  );
end entity;

architecture rtl of uart_tx is
  signal sh   : std_logic_vector(9 downto 0) := (others => '1');  -- stopp & data & start, LSB ut först
  signal cnt  : natural range 0 to CLKS_PER_BIT - 1 := 0;
  signal bitn : natural range 0 to 9 := 0;
  signal act  : std_logic := '0';
  signal pend : std_logic := '0';                                 -- byte i hållregistret
  signal hold : std_logic_vector(7 downto 0) := (others => '0');
begin
  busy <= pend;
  tx   <= sh(0) when act = '1' else '1';

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        act <= '0'; pend <= '0';
      else
        if start = '1' and pend = '0' then
          hold <= data; pend <= '1';
        end if;
        if act = '0' then
          if pend = '1' or start = '1' then  -- ledig: starta direkt
            if pend = '1' then sh <= '1' & hold & '0'; else sh <= '1' & data & '0'; end if;
            act <= '1'; cnt <= 0; bitn <= 0; pend <= '0';
          end if;
        elsif cnt = CLKS_PER_BIT - 1 then
          cnt <= 0;
          if bitn = 9 then
            if pend = '1' then               -- nästa byte direkt efter stoppbiten
              sh <= '1' & hold & '0'; bitn <= 0; pend <= '0';
            else
              act <= '0';
            end if;
          else
            sh <= '1' & sh(9 downto 1); bitn <= bitn + 1;
          end if;
        else
          cnt <= cnt + 1;
        end if;
      end if;
    end if;
  end process;
end architecture;
