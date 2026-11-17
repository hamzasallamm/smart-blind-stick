-- Blinks an LED while en = '1' (250 ms on, 250 ms off = 2 Hz).
library ieee;
use ieee.std_logic_1164.all;

entity blinker is
  generic (
    HALF_MS : positive := 250
  );
  port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;
    tick_ms : in  std_logic;
    en      : in  std_logic;
    led     : out std_logic
  );
end entity blinker;

architecture rtl of blinker is
  signal cnt : integer range 0 to HALF_MS - 1 := 0;
  signal q   : std_logic := '0';
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' or en = '0' then
        cnt <= 0;
        q   <= '1';                       -- LED turns on straight away
      elsif tick_ms = '1' then
        if cnt = HALF_MS - 1 then
          cnt <= 0;
          q   <= not q;
        else
          cnt <= cnt + 1;
        end if;
      end if;
    end if;
  end process;
  led <= q and en;
end architecture rtl;
