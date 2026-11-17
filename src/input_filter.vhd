-- Cleans up a signal coming from outside the FPGA (switch, button, sensor):
--   1) two flip-flops synchronise it to our clock
--   2) the output only changes after the input has stayed at the new
--      value for STABLE_MS milliseconds (debouncing / noise filtering)
library ieee;
use ieee.std_logic_1164.all;

entity input_filter is
  generic (
    STABLE_MS : positive  := 20;
    INIT      : std_logic := '0'   -- value at power-up / reset
  );
  port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;
    tick_ms : in  std_logic;
    din     : in  std_logic;
    dout    : out std_logic
  );
end entity input_filter;

architecture rtl of input_filter is
  signal s1, s2 : std_logic := INIT;
  signal q      : std_logic := INIT;
  signal cnt    : integer range 0 to STABLE_MS := 0;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      s1 <= din;
      s2 <= s1;
      if rst_n = '0' then
        q   <= INIT;
        cnt <= 0;
      elsif s2 = q then
        cnt <= 0;                         -- no change: restart the wait
      elsif tick_ms = '1' then
        if cnt >= STABLE_MS - 1 then
          q   <= s2;                      -- stable long enough: accept it
          cnt <= 0;
        else
          cnt <= cnt + 1;
        end if;
      end if;
    end if;
  end process;
  dout <= q;
end architecture rtl;
