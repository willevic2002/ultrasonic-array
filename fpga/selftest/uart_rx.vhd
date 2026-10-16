-- uart_rx: UART-mottagare 8N1, 2 Mbaud (exakt 50 klockcykler per bit vid 100 MHz).
--
-- rx synkas med två vippor och samplas i mitten av varje bit. valid ger en
-- cykels puls i mitten av stoppbiten (inte i slutet), så nästa startbit hinns med.
-- Fel stoppbit (ramfel) kastar byten.
--
-- STATUS: simulerad (fpga/selftest/tb_selftest_top.vhd), OTESTAT i hårdvara.

library ieee;
use ieee.std_logic_1164.all;

entity uart_rx is
  generic (CLKS_PER_BIT : positive := 50);
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;  -- synkron, aktiv hög
    rx    : in  std_logic;  -- asynkron
    valid : out std_logic;  -- en cykels puls per mottagen byte
    data  : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of uart_rx is
  type state_t is (IDLE, START, BITS, STOP);
  signal state : state_t := IDLE;
  signal sync  : std_logic_vector(1 downto 0) := "11";
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of sync : signal is "TRUE";
  signal cnt   : natural range 0 to CLKS_PER_BIT - 1 := 0;
  signal bitn  : natural range 0 to 7 := 0;
  signal sh    : std_logic_vector(7 downto 0) := (others => '0');
begin
  process (clk)
  begin
    if rising_edge(clk) then
      sync  <= sync(0) & rx;
      valid <= '0';
      if rst = '1' then
        state <= IDLE;
        sync  <= "11";
      else
        case state is
          when IDLE =>
            if sync(1) = '0' then cnt <= 0; state <= START; end if;
          when START =>                      -- vänta till mitten av startbiten
            if cnt = CLKS_PER_BIT / 2 - 1 then
              cnt <= 0; bitn <= 0;
              if sync(1) = '0' then state <= BITS; else state <= IDLE; end if;  -- glitch
            else
              cnt <= cnt + 1;
            end if;
          when BITS =>
            if cnt = CLKS_PER_BIT - 1 then
              cnt <= 0;
              sh  <= sync(1) & sh(7 downto 1);  -- LSB först
              if bitn = 7 then state <= STOP; else bitn <= bitn + 1; end if;
            else
              cnt <= cnt + 1;
            end if;
          when STOP =>
            if cnt = CLKS_PER_BIT - 1 then
              if sync(1) = '1' then valid <= '1'; data <= sh; end if;
              state <= IDLE;
            else
              cnt <= cnt + 1;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
