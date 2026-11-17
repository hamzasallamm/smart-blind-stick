-- Drives the six 7-segment displays (HEX5 is the leftmost).
-- DE10-Lite displays are ACTIVE LOW: '0' turns a segment on.
-- Bit order: 7 = DP, 6 = g, 5 = f, 4 = e, 3 = d, 2 = c, 1 = b, 0 = a
library ieee;
use ieee.std_logic_1164.all;
use work.stick_pkg.all;

entity seg7_msg is
  port (
    msg : in  integer range 0 to 5;
    hex0, hex1, hex2, hex3, hex4, hex5 : out std_logic_vector(7 downto 0)
  );
end entity seg7_msg;

architecture rtl of seg7_msg is
  -- Segment patterns, active HIGH here (gfedcba); inverted at the output
  constant C_BLANK : std_logic_vector(6 downto 0) := "0000000";
  constant C_A     : std_logic_vector(6 downto 0) := "1110111";
  constant C_d     : std_logic_vector(6 downto 0) := "1011110";
  constant C_E     : std_logic_vector(6 downto 0) := "1111001";
  constant C_F     : std_logic_vector(6 downto 0) := "1110001";
  constant C_L     : std_logic_vector(6 downto 0) := "0111000";
  constant C_BIG_N   : std_logic_vector(6 downto 0) := "0110111";  -- capital-style N
  constant C_SMALL_N : std_logic_vector(6 downto 0) := "1010100";  -- small n
  constant C_O     : std_logic_vector(6 downto 0) := "0111111";
  constant C_P     : std_logic_vector(6 downto 0) := "1110011";
  constant C_r     : std_logic_vector(6 downto 0) := "1010000";
  constant C_t     : std_logic_vector(6 downto 0) := "1111000";

  signal s5, s4, s3, s2, s1, s0 : std_logic_vector(6 downto 0);
begin

  process (msg)
  begin
    s5 <= C_BLANK; s4 <= C_BLANK; s3 <= C_BLANK;
    s2 <= C_BLANK; s1 <= C_BLANK; s0 <= C_BLANK;

    case msg is
      when MSG_ON =>
        s5 <= C_O; s4 <= C_BIG_N;
      when MSG_OFF =>
        s5 <= C_O; s4 <= C_F; s3 <= C_F;
      when MSG_ALERT =>
        s5 <= C_A; s4 <= C_L; s3 <= C_E; s2 <= C_r; s1 <= C_t;
      when MSG_DROP =>
        s5 <= C_d; s4 <= C_r; s3 <= C_O; s2 <= C_P;
      when MSG_NORMAL =>                   -- "NOrnAL" ("rn" reads as m)
        s5 <= C_BIG_N; s4 <= C_O; s3 <= C_r; s2 <= C_SMALL_N; s1 <= C_A; s0 <= C_L;
      when others =>
        null;                              -- blank
    end case;
  end process;

  -- Invert for the active-low hardware; DP ('1') stays off
  hex5 <= '1' & not s5;
  hex4 <= '1' & not s4;
  hex3 <= '1' & not s3;
  hex2 <= '1' & not s2;
  hex1 <= '1' & not s1;
  hex0 <= '1' & not s0;
end architecture rtl;
