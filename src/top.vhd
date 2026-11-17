-- Smart Blind Stick - top level.
-- Connects all modules. Its ports are the real pins of the board;
-- they are mapped to FPGA pins by pins.tcl.
--
-- On the board:
--   clk          <- MAX10_CLK1_50 (50 MHz)
--   rst_n        <- KEY1 (system reset, active low)
--   key_power_n  <- KEY0 (spare ON/OFF button, active low)
--   hex0..hex5   -> HEX0..HEX5 (7-segment)
--   state_leds   -> LEDR0..LEDR4: OFF, ON, NORMAL, ALERT, DROP
--   debug_leds   -> LEDR5..LEDR9: what the FPGA sees / drives
--                   5 = hand on touch sensor   6 = IR sees obstacle
--                   7 = ON/OFF button pressed  8 = yellow LED + motor on
--                   9 = red LED on
-- On the GPIO header (header pin numbers):
--   ir_out_n     <- pin 1   IR sensor OUT (LOW = obstacle)
--   motor        -> pin 3   vibration motor transistor (via 1k)
--   led_red      -> pin 4   red LED (via 330R): DROP warning, blinks
--   led_yellow   -> pin 5   yellow LED (via 330R): ALERT warning
--   touch        <- pin 19  TTP223 touch sensor I/O (HIGH = touched)
--   buzzer_pwr   -> pin 33  buzzer + (1 = powered, only while beeping)
--   buzzer_s     -> pin 39  buzzer S (2 kHz tone, LOW = silent)
--   btn_power_n  <- pin 40  ON/OFF push button to GND (built-in pull-up)
library ieee;
use ieee.std_logic_1164.all;
use work.stick_pkg.all;

entity top is
  generic (
    CLKS_PER_US : positive := 50;
    US_PER_MS   : positive := 1000;
    ON_MS       : positive := 5000;  -- "ON" shown for 5 s
    OFF_MS      : positive := 5000;  -- "OFF" shown for 5 s
    DROP_MS     : positive := 500;   -- hand off the handle this long = dropped
    DEBOUNCE_MS : positive := 20
  );
  port (
    clk          : in  std_logic;
    rst_n        : in  std_logic;
    key_power_n  : in  std_logic;
    btn_power_n  : in  std_logic;

    ir_out_n     : in  std_logic;
    touch        : in  std_logic;

    motor        : out std_logic;
    led_red      : out std_logic;
    led_yellow   : out std_logic;
    buzzer_pwr   : out std_logic;
    buzzer_s     : out std_logic;

    state_leds   : out std_logic_vector(4 downto 0);
    debug_leds   : out std_logic_vector(4 downto 0);
    hex0, hex1, hex2, hex3, hex4, hex5 : out std_logic_vector(7 downto 0)
  );
end entity top;

architecture rtl of top is
  signal r1, r2      : std_logic := '0';   -- reset synchroniser
  signal rst_s       : std_logic;
  signal tick_us     : std_logic;
  signal tick_ms     : std_logic;

  signal pwr_raw_n   : std_logic;
  signal pwr_f       : std_logic;
  signal pwr_prev    : std_logic := '1';
  signal power_btn   : std_logic := '0';
  signal ir_f        : std_logic;
  signal touch_f     : std_logic;

  signal dropped     : std_logic;
  signal obstacle    : std_logic;

  signal msg         : integer range 0 to 5;
  signal motor_en    : std_logic;
  signal yellow_en   : std_logic;
  signal red_en      : std_logic;
  signal red_blink   : std_logic;
  signal buzzer_en   : std_logic;
  signal beep        : std_logic;
  signal buzz        : std_logic;
begin

  -- Reset: synchronise KEY1 to the clock
  process (clk)
  begin
    if rising_edge(clk) then
      r1 <= rst_n;
      r2 <= r1;
    end if;
  end process;
  rst_s <= r2;

  u_tick : entity work.tick_gen
    generic map (CLKS_PER_US => CLKS_PER_US, US_PER_MS => US_PER_MS)
    port map (clk => clk, rst_n => rst_s, tick_us => tick_us, tick_ms => tick_ms);

  -- ON/OFF: the external push button OR KEY0 (both are '0' when pressed)
  pwr_raw_n <= btn_power_n and key_power_n;

  u_pwr : entity work.input_filter
    generic map (STABLE_MS => DEBOUNCE_MS, INIT => '1')
    port map (clk => clk, rst_n => rst_s, tick_ms => tick_ms, din => pwr_raw_n, dout => pwr_f);

  u_ir : entity work.input_filter
    generic map (STABLE_MS => DEBOUNCE_MS, INIT => '1')
    port map (clk => clk, rst_n => rst_s, tick_ms => tick_ms, din => ir_out_n, dout => ir_f);

  u_touch : entity work.input_filter
    generic map (STABLE_MS => DEBOUNCE_MS, INIT => '1')
    port map (clk => clk, rst_n => rst_s, tick_ms => tick_ms, din => touch, dout => touch_f);

  -- ON/OFF button: one-cycle pulse at the moment it is pressed
  process (clk)
  begin
    if rising_edge(clk) then
      pwr_prev  <= pwr_f;
      power_btn <= pwr_prev and not pwr_f;
    end if;
  end process;

  -- Touch sensor on the handle: hand off for 0.5 s = dropped
  u_drop : entity work.drop_detect
    generic map (DROP_MS => DROP_MS)
    port map (clk => clk, rst_n => rst_s, tick_ms => tick_ms,
              holding => touch_f, dropped => dropped);

  -- Obstacle when the IR sensor output is LOW
  obstacle <= not ir_f;

  u_ctrl : entity work.controller
    generic map (ON_MS => ON_MS, OFF_MS => OFF_MS)
    port map (clk => clk, rst_n => rst_s, tick_ms => tick_ms,
              power_btn => power_btn, obstacle => obstacle, dropped => dropped,
              msg => msg, motor_en => motor_en, yellow_en => yellow_en,
              red_en => red_en, buzzer_en => buzzer_en,
              state_leds => state_leds);

  u_buzz : entity work.buzzer
    port map (clk => clk, rst_n => rst_s, tick_us => tick_us, tick_ms => tick_ms,
              en => buzzer_en, beep => beep, buzz => buzz);

  u_blink : entity work.blinker
    port map (clk => clk, rst_n => rst_s, tick_ms => tick_ms,
              en => red_en, led => red_blink);

  u_seg : entity work.seg7_msg
    port map (msg => msg,
              hex0 => hex0, hex1 => hex1, hex2 => hex2,
              hex3 => hex3, hex4 => hex4, hex5 => hex5);

  motor      <= motor_en;
  led_yellow <= yellow_en;
  led_red    <= red_blink;
  buzzer_pwr <= beep;          -- buzzer only has power during a beep
  buzzer_s   <= buzz;          -- tone on S; held LOW when silent

  -- Debug lights on the board: what the FPGA actually sees and drives
  debug_leds(0) <= touch_f;      -- LEDR5: hand on the touch sensor
  debug_leds(1) <= obstacle;     -- LEDR6: IR sensor sees something
  debug_leds(2) <= not pwr_f;    -- LEDR7: ON/OFF button pressed
  debug_leds(3) <= yellow_en;    -- LEDR8: yellow LED + motor on
  debug_leds(4) <= red_blink;    -- LEDR9: red LED on
end architecture rtl;
