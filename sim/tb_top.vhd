-- Full-scenario testbench for the Smart Blind Stick.
-- To keep the simulation short, 1 "millisecond" is shrunk to 10 us
-- (US_PER_MS = 10), so 5 s on the display = 50 ms of simulation.
-- Microsecond timing (buzzer tone) stays real.
--
-- Scenario:
--   OFF (nothing happens) -> button -> "ON" 5 s -> "NOrnAL"
--   -> IR obstacle -> "ALErt", motor + yellow LED -> clear -> "NOrnAL"
--   -> short slip of the finger (ignored) -> hand off -> "drOP",
--      red LED blinks + buzzer beeps -> IR during DROP (stays DROP)
--   -> hand back on -> "NOrnAL" -> button -> "OFF" 5 s -> blank
--   -> button + button again during "ON" -> "OFF" -> KEY0 also works
--
-- ModelSim:  vsim -t ns work.tb_top ; add wave /tb_top/* ; run -all
library ieee;
use ieee.std_logic_1164.all;

entity tb_top is
end entity tb_top;

architecture sim of tb_top is
  constant CLK_PERIOD : time := 20 ns;   -- 50 MHz
  constant MS         : time := 10 us;   -- one scaled "millisecond"

  signal clk         : std_logic := '0';
  signal rst_n       : std_logic := '0';
  signal key_power_n : std_logic := '1';   -- KEY0, '1' = not pressed
  signal btn_power_n : std_logic := '1';   -- push button, '1' = not pressed
  signal ir_out_n    : std_logic := '1';   -- '1' = no obstacle
  signal touch       : std_logic := '1';   -- '1' = hand on the handle
  signal motor, led_red, led_yellow, buzzer_pwr, buzzer_s : std_logic;
  signal state_leds, debug_leds : std_logic_vector(4 downto 0);
  signal hex0, hex1, hex2, hex3, hex4, hex5 : std_logic_vector(7 downto 0);

  signal sim_done    : boolean := false;
  signal tone_edges  : natural := 0;      -- counts buzzer S pulses
  signal beep_edges  : natural := 0;      -- counts beeps (buzzer power on)
  signal blink_edges : natural := 0;      -- counts red LED flashes

  -- state_leds: 0 OFF, 1 ON, 2 NORMAL, 3 ALERT, 4 DROP
  constant ST_OFF    : std_logic_vector(4 downto 0) := "00001";
  constant ST_ON     : std_logic_vector(4 downto 0) := "00010";
  constant ST_NORMAL : std_logic_vector(4 downto 0) := "00100";
  constant ST_ALERT  : std_logic_vector(4 downto 0) := "01000";
  constant ST_DROP   : std_logic_vector(4 downto 0) := "10000";

  -- 7-segment patterns as the board sees them (active low, DP off)
  constant H_BLANK : std_logic_vector(7 downto 0) := x"FF";
  constant H_O : std_logic_vector(7 downto 0) := x"C0";
  constant H_BIG_N : std_logic_vector(7 downto 0) := x"C8";
  constant H_SMALL_N : std_logic_vector(7 downto 0) := x"AB";
  constant H_F : std_logic_vector(7 downto 0) := x"8E";
  constant H_A : std_logic_vector(7 downto 0) := x"88";
  constant H_L : std_logic_vector(7 downto 0) := x"C7";
  constant H_E : std_logic_vector(7 downto 0) := x"86";
  constant H_r : std_logic_vector(7 downto 0) := x"AF";
  constant H_t : std_logic_vector(7 downto 0) := x"87";
  constant H_d : std_logic_vector(7 downto 0) := x"A1";
  constant H_P : std_logic_vector(7 downto 0) := x"8C";
begin

  dut : entity work.top
    generic map (
      US_PER_MS => 10
    )
    port map (
      clk => clk, rst_n => rst_n, key_power_n => key_power_n, btn_power_n => btn_power_n,
      ir_out_n => ir_out_n, touch => touch,
      motor => motor, led_red => led_red, led_yellow => led_yellow,
      buzzer_pwr => buzzer_pwr, buzzer_s => buzzer_s,
      state_leds => state_leds, debug_leds => debug_leds,
      hex0 => hex0, hex1 => hex1, hex2 => hex2, hex3 => hex3, hex4 => hex4, hex5 => hex5
    );

  clk <= not clk after CLK_PERIOD / 2 when not sim_done else '0';

  count_tone  : process (buzzer_s)   begin if rising_edge(buzzer_s)   then tone_edges  <= tone_edges + 1;  end if; end process;
  count_beep  : process (buzzer_pwr) begin if rising_edge(buzzer_pwr) then beep_edges  <= beep_edges + 1;  end if; end process;
  count_blink : process (led_red)    begin if rising_edge(led_red)    then blink_edges <= blink_edges + 1; end if; end process;

  stimulus : process
    procedure press(signal b : out std_logic) is
    begin
      b <= '0';
      wait for 100 * MS;
      b <= '1';
      wait for 100 * MS;
    end procedure;

    procedure all_quiet(msg : string) is
    begin
      assert buzzer_pwr = '0' and buzzer_s = '0' report msg & ": buzzer must be silent" severity error;
      assert motor = '0' and led_red = '0' and led_yellow = '0'
        report msg & ": motor and LEDs must be off" severity error;
    end procedure;
  begin
    rst_n <= '0';
    wait for 1 us;
    rst_n <= '1';
    wait for 10 * MS;

    -- 1) Nothing happens until the button is pressed
    assert state_leds = ST_OFF report "Should start OFF" severity error;
    assert hex5 = H_BLANK and hex0 = H_BLANK report "Display blank when OFF" severity error;
    all_quiet("Start");
    touch <= '0'; ir_out_n <= '0';          -- sensors are ignored while OFF
    wait for 1000 * MS;
    assert state_leds = ST_OFF report "Sensors must do nothing while OFF" severity error;
    all_quiet("OFF with sensors active");
    touch <= '1'; ir_out_n <= '1';
    wait for 100 * MS;

    -- 2) Button -> "ON" for 5 s -> normal operation
    press(btn_power_n);
    assert state_leds = ST_ON report "Button should turn it ON" severity error;
    assert hex5 = H_O and hex4 = H_BIG_N report "Display should read ON" severity error;
    all_quiet("ON message");
    wait for 4500 * MS;
    assert state_leds = ST_ON report "ON must last 5 s" severity error;
    wait for 600 * MS;
    assert state_leds = ST_NORMAL report "Should be NORMAL after 5 s" severity error;

    -- 5) Hand on the handle -> "NOrnAL"
    assert hex5 = H_BIG_N and hex4 = H_O and hex3 = H_r and hex2 = H_SMALL_N and hex1 = H_A and hex0 = H_L
      report "Display should read NOrnAL" severity error;
    all_quiet("NORMAL");

    -- 3) IR obstacle -> "ALErt", motor + yellow LED (no red, no buzzer)
    ir_out_n <= '0';
    wait for 100 * MS;
    assert state_leds = ST_ALERT report "IR should give ALERT" severity error;
    assert hex5 = H_A and hex4 = H_L and hex3 = H_E and hex2 = H_r and hex1 = H_t
      report "Display should read ALErt" severity error;
    assert motor = '1' and led_yellow = '1' report "Motor + yellow LED should be on" severity error;
    assert led_red = '0' and buzzer_pwr = '0' and buzzer_s = '0'
      report "No red LED / buzzer in ALERT" severity error;

    -- obstacle gone -> back to NORMAL
    ir_out_n <= '1';
    wait for 100 * MS;
    assert state_leds = ST_NORMAL report "Clear path should be NORMAL" severity error;
    all_quiet("Back to NORMAL");

    -- tiny slip of the finger (0.2 s) -> ignored
    touch <= '0';
    wait for 200 * MS;
    touch <= '1';
    wait for 100 * MS;
    assert state_leds = ST_NORMAL report "Short slip must be ignored" severity error;

    -- 4) Hand off the touch sensor -> "drOP", red LED + buzzer
    touch <= '0';
    wait for 700 * MS;
    assert state_leds = ST_DROP report "Hand off should give DROP" severity error;
    wait for 1500 * MS;                     -- let the beep pattern play
    assert hex5 = H_d and hex4 = H_r and hex3 = H_O and hex2 = H_P
      report "Display should read drOP" severity error;
    assert beep_edges >= 2 report "Buzzer should be beeping" severity error;
    assert tone_edges > 10 report "Buzzer tone should be playing" severity error;
    assert blink_edges >= 3 report "Red LED should be blinking" severity error;
    assert motor = '0' and led_yellow = '0' report "No motor / yellow LED in DROP" severity error;

    -- IR during DROP -> stays DROP (drop has priority)
    ir_out_n <= '0';
    wait for 100 * MS;
    assert state_leds = ST_DROP report "DROP must stay above ALERT" severity error;
    ir_out_n <= '1';
    wait for 100 * MS;

    -- 5) Hand back on the handle -> "NOrnAL" straight away, buzzer stops
    touch <= '1';
    wait for 50 * MS;
    assert state_leds = ST_NORMAL report "Touching again should give NORMAL" severity error;
    assert hex5 = H_BIG_N and hex4 = H_O and hex3 = H_r report "Display should read NOrnAL again" severity error;
    all_quiet("After recovery");

    -- 1) + 2) Button again -> "OFF" for 5 s -> blank, everything off
    press(btn_power_n);
    assert state_leds = ST_OFF report "Second press should turn it OFF" severity error;
    assert hex5 = H_O and hex4 = H_F and hex3 = H_F report "Display should read OFF" severity error;
    all_quiet("OFF message");
    touch <= '0'; ir_out_n <= '0';          -- sensors ignored while switching off
    wait for 4500 * MS;
    assert hex5 = H_O and hex4 = H_F report "OFF must last 5 s" severity error;
    wait for 600 * MS;
    assert hex5 = H_BLANK and hex0 = H_BLANK report "Display blank after OFF" severity error;
    all_quiet("OFF");
    touch <= '1'; ir_out_n <= '1';
    wait for 100 * MS;

    -- Pressing during the "ON" message turns it straight back off
    press(btn_power_n);
    assert state_leds = ST_ON report "Should be ON again" severity error;
    press(btn_power_n);
    assert state_leds = ST_OFF report "Press during ON should turn it OFF" severity error;
    wait for 5100 * MS;

    -- KEY0 on the board works as a spare ON/OFF button
    press(key_power_n);
    assert state_leds = ST_ON report "KEY0 should turn it ON" severity error;
    press(key_power_n);
    assert state_leds = ST_OFF report "KEY0 should turn it OFF" severity error;

    report "Beeps: " & integer'image(beep_edges) & ", tone pulses: " &
           integer'image(tone_edges) & ", red LED blinks: " & integer'image(blink_edges);
    report "SIMULATION FINISHED - all checks done" severity note;
    sim_done <= true;
    wait;
  end process;
end architecture sim;
