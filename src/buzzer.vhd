-- Drop warning sound for the HW-508 buzzer module.
-- beep : '1' during each beep of the repeating "beep - beep - pause"
--        pattern (we use it to power the buzzer's + pin)
-- buzz : a 2 kHz tone (square wave) during each beep (goes to the S pin)
library ieee;
use ieee.std_logic_1164.all;

entity buzzer is
  generic (
    TONE_HALF_US : positive := 250;  -- 250 us high + 250 us low = 2 kHz
    BEEP_MS      : positive := 200;
    GAP_MS       : positive := 200;
    PAUSE_MS     : positive := 600
  );
  port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;
    tick_us : in  std_logic;
    tick_ms : in  std_logic;
    en      : in  std_logic;
    beep    : out std_logic;
    buzz    : out std_logic
  );
end entity buzzer;

architecture rtl of buzzer is
  constant PATTERN_MS : integer := 2 * BEEP_MS + GAP_MS + PAUSE_MS;
  signal pat     : integer range 0 to PATTERN_MS - 1 := 0;
  signal tone_c  : integer range 0 to TONE_HALF_US - 1 := 0;
  signal tone    : std_logic := '0';
  signal beep_on : std_logic;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' or en = '0' then
        pat    <= 0;
        tone_c <= 0;
        tone   <= '0';
      else
        if tick_us = '1' then
          if tone_c = TONE_HALF_US - 1 then
            tone_c <= 0;
            tone   <= not tone;
          else
            tone_c <= tone_c + 1;
          end if;
        end if;
        if tick_ms = '1' then
          if pat = PATTERN_MS - 1 then
            pat <= 0;
          else
            pat <= pat + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  beep_on <= '1' when pat < BEEP_MS
                   or (pat >= BEEP_MS + GAP_MS and pat < 2 * BEEP_MS + GAP_MS)
             else '0';

  beep <= beep_on and en;
  buzz <= tone and beep_on and en;
end architecture rtl;
