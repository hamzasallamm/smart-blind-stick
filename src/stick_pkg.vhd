-- Shared constants for the Smart Blind Stick
library ieee;
use ieee.std_logic_1164.all;

package stick_pkg is
  -- What the 7-segment display should show
  constant MSG_BLANK  : integer := 0;
  constant MSG_ON     : integer := 1;  -- "ON"
  constant MSG_OFF    : integer := 2;  -- "OFF"
  constant MSG_ALERT  : integer := 3;  -- "ALErt"
  constant MSG_DROP   : integer := 4;  -- "drOP"
  constant MSG_NORMAL : integer := 5;  -- "NOrnAL" (normal operation)
end package stick_pkg;
