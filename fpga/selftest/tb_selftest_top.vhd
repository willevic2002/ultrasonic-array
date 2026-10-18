-- Testbänk för selftest_top. En UART-BFM (2 Mbaud) spelar PC:n: STATUS tills READY
-- (ID-nibble 0xA), PING, vänta på DATA_VALID + PING_TOGGLE, READ av alla 16*N ord i två
-- ramar, kontroll att varje ord i kanal c är 2048*(c-8). Sedan avbrottstestet: en halv ram,
-- tystnad längre än TIMEOUT_CYCLES, och därefter fungerar STATUS igen.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_selftest_top is
end entity;

architecture sim of tb_selftest_top is
  constant N_SAMPLES : positive := 64;
  constant TIMEOUT   : positive := 5000;       -- 50 µs i stället för 10 ms
  constant T_BIT     : time := 500 ns;         -- 2 Mbaud

  type byte_vec is array (natural range <>) of std_logic_vector(7 downto 0);
  type buf_t is array (0 to 4095) of std_logic_vector(7 downto 0);

  signal clk     : std_logic := '0';
  signal rx_line : std_logic := '1';           -- PC -> FPGA
  signal tx_line : std_logic;                  -- FPGA -> PC
  signal led     : std_logic_vector(3 downto 0);
  signal rx_buf  : buf_t;
  signal rx_cnt  : natural := 0;
begin
  clk <= not clk after 5 ns;

  dut : entity work.selftest_top
    generic map (STARTUP_CYCLES => 2000, SETTLE_CYCLES => 2000, N_SAMPLES => N_SAMPLES,
                 TIMEOUT_CYCLES => TIMEOUT)
    port map (clk => clk, uart_rx => rx_line, uart_tx => tx_line, led => led);

  -- PC-mottagare: samlar alla bytes från FPGA:n.
  process
    variable b : std_logic_vector(7 downto 0);
  begin
    wait until falling_edge(tx_line);
    wait for T_BIT * 3 / 2;
    for i in 0 to 7 loop
      b(i) := tx_line;
      wait for T_BIT;
    end loop;
    assert tx_line = '1' report "ramfel från FPGA" severity failure;
    rx_buf(rx_cnt) <= b;
    rx_cnt <= rx_cnt + 1;
  end process;

  process
    variable base : natural := 0;

    procedure send_byte(b : std_logic_vector(7 downto 0)) is
    begin
      rx_line <= '0'; wait for T_BIT;
      for i in 0 to 7 loop rx_line <= b(i); wait for T_BIT; end loop;
      rx_line <= '1'; wait for T_BIT;
    end procedure;

    -- Skicka en ram (header + payload) och vänta in lika många svarsbytes.
    procedure frame(p : byte_vec) is
      variable n : natural := p'length;
    begin
      send_byte(std_logic_vector(to_unsigned(n / 256, 8)));
      send_byte(std_logic_vector(to_unsigned(n mod 256, 8)));
      for i in p'range loop send_byte(p(i)); end loop;
      for t in 0 to 20000 loop
        exit when rx_cnt = base + n;
        wait for 1 us;
      end loop;
      assert rx_cnt = base + n report "svar saknas, fick " & integer'image(rx_cnt - base) & " av " & integer'image(n)
        severity failure;
    end procedure;

    procedure status(s : out std_logic_vector(7 downto 0)) is
    begin
      frame((x"01", x"00"));
      s := rx_buf(base + 1);
      base := rx_cnt;
    end procedure;

    procedure read_words(addr : natural; nw : natural) is
      variable p : byte_vec(0 to 3 + 2 * nw) := (others => x"00");
      variable w : integer;
      variable v : std_logic_vector(15 downto 0);
      variable ch : natural;
    begin
      p(0) := x"03";
      p(1) := std_logic_vector(to_unsigned(addr / 256, 8));
      p(2) := std_logic_vector(to_unsigned(addr mod 256, 8));
      frame(p);
      for i in 0 to nw - 1 loop
        v := rx_buf(base + 4 + 2 * i) & rx_buf(base + 5 + 2 * i);
        w := to_integer(signed(v));
        ch := (addr + i) mod 16;
        assert w = 2048 * (integer(ch) - 8)
          report "kanal " & integer'image(ch) & " ord " & integer'image(addr + i) & " = " & integer'image(w)
          severity failure;
      end loop;
      base := rx_cnt;
    end procedure;

    variable s, s0 : std_logic_vector(7 downto 0);
  begin
    wait for 1 us;

    -- STATUS tills READY.
    status(s);
    for i in 0 to 200 loop
      exit when s(0) = '1';
      status(s);
    end loop;
    assert s(7 downto 4) = x"A" report "fel ID-nibble, status=" & to_hstring(s) severity failure;
    assert s(0) = '1' report "aldrig READY" severity failure;
    s0 := s;

    -- PING.
    frame((0 => x"02"));
    base := rx_cnt;
    status(s);
    for i in 0 to 2000 loop
      exit when s(2) = '1' and s(3) /= s0(3);
      status(s);
    end loop;
    assert s(2) = '1' and s(3) /= s0(3) report "DATA_VALID/PING_TOGGLE uteblev" severity failure;

    -- READ i två ramar, hälften av minnet var.
    read_words(0, 8 * N_SAMPLES);
    read_words(8 * N_SAMPLES, 8 * N_SAMPLES);

    -- Avbrott: halv ram (längd 5, en byte), tystnad, sedan ska STATUS fungera.
    send_byte(x"00"); send_byte(x"05"); send_byte(x"01");
    wait for 100 us;
    base := rx_cnt;
    status(s);
    assert s(7 downto 4) = x"A" report "STATUS efter avbrott fungerar inte" severity failure;
    assert s(2) = '1' report "DATA_VALID borta efter avbrott" severity failure;

    report "PASS: selftest, 16 x " & integer'image(N_SAMPLES) & " ord, avbrott OK";
    std.env.finish;
  end process;

  process
  begin
    wait for 100 ms;
    report "FAIL: watchdog" severity failure;
  end process;
end architecture;
