-- capture_spi: inspelning till BRAM och SPI-kommandon (PING/STATUS/READ).
-- Se docs/pipeline.md §5 och §6.
--
-- PING (när READY): chirp_start, sedan lagras de N_SAMPLES nästa sample_valid
-- till minnet på adress sampel*16 + kanal. De 16 kanalerna skrivs en per cykel
-- efter pulsen (samples är stabila mellan pulserna, ca 1024 cykler).
-- En sample_valid i samma cykel som PING godtas räknas inte med.
-- chirp_start är registrerad, dvs. synlig cykeln efter att PING togs emot.
--
-- READY = ultrasonic hög sammanhängande i SETTLE_CYCLES och ingen inspelning.
--
-- Minnet har en skrivport och en separat läsport med synkron läsning och
-- ingen reset, så Vivado lägger det i BRAM. READ hämtar nästa ord medan
-- föregående skiftas ut; dummybyten före första ordet ger >= 70 cykler slack.
-- DATA_VALID sätts en cykel innan sista skrivningen landat; första möjliga
-- READ är minst 60 cykler senare.
--
-- STATUS: simulerad, OTESTAT i hårdvara.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mic_array_pkg.all;

entity capture_spi is
  generic (
    N_SAMPLES    : positive := 2048;
    SETTLE_CYCLES : natural := 1_000_000
  );
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;  -- synkron, aktiv hög
    ultrasonic   : in  std_logic;
    samples      : in  sample_array;
    sample_valid : in  std_logic;
    chirp_start  : out std_logic;
    spi_sclk     : in  std_logic;
    spi_cs_n     : in  std_logic;
    spi_mosi     : in  std_logic;
    spi_miso     : out std_logic
  );
end entity;

architecture rtl of capture_spi is
  -- Komponent i stället för direkt entity-instans: run_xsim.sh kompilerar i
  -- alfabetisk ordning, så spi_slave är inte analyserad när denna fil läses.
  component spi_slave is
    port (
      clk       : in  std_logic;
      rst       : in  std_logic;
      spi_sclk  : in  std_logic;
      spi_cs_n  : in  std_logic;
      spi_mosi  : in  std_logic;
      spi_miso  : out std_logic;
      rx_strobe : out std_logic;
      rx_byte   : out std_logic_vector(7 downto 0);
      rx_idx    : out natural range 0 to 4;
      tx_load   : in  std_logic;
      tx_byte   : in  std_logic_vector(7 downto 0)
    );
  end component;

  constant DEPTH : positive := N_CH * N_SAMPLES;
  type mem_t is array (0 to DEPTH - 1) of std_logic_vector(15 downto 0);
  signal mem : mem_t := (others => (others => '0'));

  constant CMD_STATUS : std_logic_vector(7 downto 0) := x"01";
  constant CMD_PING   : std_logic_vector(7 downto 0) := x"02";
  constant CMD_READ   : std_logic_vector(7 downto 0) := x"03";

  signal settle_cnt : natural range 0 to SETTLE_CYCLES := 0;
  signal cap_active, data_valid, busy : std_logic := '0';
  signal ping_toggle : std_logic := '0';  -- växlar vid varje godkänd PING, så Pi:n ser om den kom fram
  signal ready  : std_logic;
  signal sidx   : natural range 0 to N_SAMPLES - 1 := 0;
  signal ch     : natural range 0 to N_CH - 1 := 0;

  signal wr_en   : std_logic := '0';
  signal wr_addr : natural range 0 to DEPTH - 1 := 0;
  signal wr_data : std_logic_vector(15 downto 0) := (others => '0');
  signal rd_data : std_logic_vector(15 downto 0) := (others => '0');

  signal rx_strobe, tx_load : std_logic;
  signal rx_byte, tx_byte   : std_logic_vector(7 downto 0);
  signal rx_idx             : natural range 0 to 4;
  signal cmd     : std_logic_vector(7 downto 0) := (others => '0');
  signal addr    : unsigned(15 downto 0) := (others => '0');
  signal lo_byte : std_logic_vector(7 downto 0) := (others => '0');
  signal hi_next : std_logic := '1';
begin
  ready <= '1' when settle_cnt = SETTLE_CYCLES and cap_active = '0' else '0';

  u_spi : spi_slave
    port map (clk => clk, rst => rst, spi_sclk => spi_sclk, spi_cs_n => spi_cs_n,
              spi_mosi => spi_mosi, spi_miso => spi_miso,
              rx_strobe => rx_strobe, rx_byte => rx_byte, rx_idx => rx_idx,
              tx_load => tx_load, tx_byte => tx_byte);

  -- Minne: skrivport + läsport, båda synkrona (BRAM-mall).
  process (clk)
  begin
    if rising_edge(clk) then
      if wr_en = '1' then mem(wr_addr) <= wr_data; end if;
      if to_integer(addr) < DEPTH then rd_data <= mem(to_integer(addr)); end if;
    end if;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then
      chirp_start <= '0';
      tx_load     <= '0';
      wr_en       <= '0';

      if ultrasonic = '0' then
        settle_cnt <= 0;
      elsif settle_cnt < SETTLE_CYCLES then
        settle_cnt <= settle_cnt + 1;
      end if;

      -- Skrivmotor: en sample_valid -> 16 skrivningar.
      if cap_active = '1' then
        if busy = '0' then
          if sample_valid = '1' then busy <= '1'; ch <= 0; end if;
        else
          wr_en   <= '1';
          wr_addr <= sidx * N_CH + ch;
          wr_data <= std_logic_vector(samples(ch));
          if ch = N_CH - 1 then
            busy <= '0';
            if sidx = N_SAMPLES - 1 then
              cap_active <= '0';
              data_valid <= '1';
            else
              sidx <= sidx + 1;
            end if;
          else
            ch <= ch + 1;
          end if;
        end if;
      end if;

      -- Kommandon.
      if rx_strobe = '1' then
        tx_load <= '1';
        tx_byte <= x"00";
        if rx_idx = 0 then
          cmd <= rx_byte;
          if rx_byte = CMD_STATUS then
            tx_byte <= x"A" & ping_toggle & data_valid & cap_active & ready;
          elsif rx_byte = CMD_PING and ready = '1' then
            chirp_start <= '1';
            ping_toggle <= not ping_toggle;
            cap_active  <= '1';
            data_valid  <= '0';
            busy        <= '0';
            sidx        <= 0;
          end if;
        elsif cmd = CMD_READ then
          if rx_idx = 1 then
            addr(15 downto 8) <= unsigned(rx_byte);
          elsif rx_idx = 2 then
            addr(7 downto 0) <= unsigned(rx_byte);
            hi_next <= '1';
          elsif hi_next = '1' then          -- rx_idx >= 3: nästa ord ut
            tx_byte <= rd_data(15 downto 8);
            lo_byte <= rd_data(7 downto 0);
            addr    <= addr + 1;
            hi_next <= '0';
          else
            tx_byte <= lo_byte;
            hi_next <= '1';
          end if;
        end if;
      end if;

      if rst = '1' then
        settle_cnt <= 0;
        cap_active <= '0'; data_valid <= '0'; busy <= '0'; ping_toggle <= '0';
        sidx <= 0; wr_en <= '0'; tx_load <= '0';
      end if;
    end if;
  end process;
end architecture;
