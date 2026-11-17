-- Watches the touch sensor on the handle.
-- dropped = '1' once the hand has been OFF the handle for DROP_MS
-- without interruption (so a tiny slip of the finger is ignored).
-- It goes back to '0' as soon as the handle is touched again.
library ieee;
use ieee.std_logic_1164.all;

entity drop_detect is
  generic (
    DROP_MS : positive := 500
  );
  port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;
    tick_ms : in  std_logic;
    holding : in  std_logic;   -- '1' while a hand is on the handle
    dropped : out std_logic
  );
end entity drop_detect;

architecture rtl of drop_detect is
  signal cnt : integer range 0 to DROP_MS := 0;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' or holding = '1' then
        cnt <= 0;                         -- hand on the handle: not dropped
      elsif tick_ms = '1' and cnt < DROP_MS then
        cnt <= cnt + 1;
      end if;
    end if;
  end process;
  dropped <= '1' when cnt = DROP_MS else '0';
end architecture rtl;
