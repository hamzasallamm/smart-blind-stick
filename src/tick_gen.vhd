-- Turns the 50 MHz board clock into two one-cycle pulses:
--   tick_us : once every microsecond
--   tick_ms : once every millisecond
-- Every timer in the design counts these ticks instead of raw clock cycles.
library ieee;
use ieee.std_logic_1164.all;

entity tick_gen is
  generic (
    CLKS_PER_US : positive := 50;    -- 50 MHz clock -> 50 cycles per us
    US_PER_MS   : positive := 1000   -- testbench makes this small to run faster
  );
  port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;
    tick_us : out std_logic;
    tick_ms : out std_logic
  );
end entity tick_gen;

architecture rtl of tick_gen is
  signal us_cnt : integer range 0 to CLKS_PER_US - 1 := 0;
  signal ms_cnt : integer range 0 to US_PER_MS - 1   := 0;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      tick_us <= '0';
      tick_ms <= '0';
      if rst_n = '0' then
        us_cnt <= 0;
        ms_cnt <= 0;
      elsif us_cnt = CLKS_PER_US - 1 then
        us_cnt  <= 0;
        tick_us <= '1';
        if ms_cnt = US_PER_MS - 1 then
          ms_cnt  <= 0;
          tick_ms <= '1';
        else
          ms_cnt <= ms_cnt + 1;
        end if;
      else
        us_cnt <= us_cnt + 1;
      end if;
    end if;
  end process;
end architecture rtl;
