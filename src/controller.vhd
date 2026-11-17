-- The main state machine of the Smart Blind Stick.
--   OFF     : display blank, every output off. Button -> ON_MSG
--   ON_MSG  : shows "ON" for ON_MS, then NORMAL
--   NORMAL  : hand on the handle, no obstacle -> shows "NOrnAL"
--   ALERT   : IR sees an obstacle -> "ALErt", motor + yellow LED
--   DROP    : hand off the handle -> "drOP", red LED blinks, buzzer beeps
--             (back to NORMAL as soon as the handle is touched again)
--   OFF_MSG : shows "OFF" for OFF_MS, then OFF
-- The ON/OFF button works in every state: pressing it while the stick is
-- on turns it off, pressing it while off turns it on.
-- Priority while on: DROP > ALERT > NORMAL
library ieee;
use ieee.std_logic_1164.all;
use work.stick_pkg.all;

entity controller is
  generic (
    ON_MS  : positive := 5000;
    OFF_MS : positive := 5000
  );
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;
    tick_ms    : in  std_logic;
    power_btn  : in  std_logic;   -- one-cycle pulse when the ON/OFF button is pressed
    obstacle   : in  std_logic;   -- '1' = IR sensor sees something
    dropped    : in  std_logic;   -- '1' = hand off the handle long enough
    msg        : out integer range 0 to 5;
    motor_en   : out std_logic;
    yellow_en  : out std_logic;   -- yellow LED: obstacle warning
    red_en     : out std_logic;   -- red LED: drop warning (blinks)
    buzzer_en  : out std_logic;
    state_leds : out std_logic_vector(4 downto 0)  -- OFF, ON, NORMAL, ALERT, DROP
  );
end entity controller;

architecture rtl of controller is
  type state_t is (S_OFF, S_ON_MSG, S_NORMAL, S_ALERT, S_DROP, S_OFF_MSG);
  signal state : state_t := S_OFF;

  function max(a, b : integer) return integer is
  begin
    if a > b then return a; else return b; end if;
  end function;
  constant TMAX : integer := max(ON_MS, OFF_MS);
  signal timer  : integer range 0 to TMAX := 0;
begin

  process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        state <= S_OFF;
        timer <= 0;
      else
        if tick_ms = '1' and timer < TMAX then
          timer <= timer + 1;
        end if;

        case state is
          when S_OFF =>
            if power_btn = '1' then
              state <= S_ON_MSG;
              timer <= 0;
            end if;

          when S_ON_MSG =>
            if power_btn = '1' then
              state <= S_OFF_MSG;
              timer <= 0;
            elsif timer >= ON_MS then
              state <= S_NORMAL;
            end if;

          when S_NORMAL =>
            if power_btn = '1' then
              state <= S_OFF_MSG;
              timer <= 0;
            elsif dropped = '1' then
              state <= S_DROP;
            elsif obstacle = '1' then
              state <= S_ALERT;
            end if;

          when S_ALERT =>
            if power_btn = '1' then
              state <= S_OFF_MSG;
              timer <= 0;
            elsif dropped = '1' then
              state <= S_DROP;
            elsif obstacle = '0' then
              state <= S_NORMAL;
            end if;

          when S_DROP =>
            if power_btn = '1' then
              state <= S_OFF_MSG;
              timer <= 0;
            elsif dropped = '0' then         -- handle touched again: recovered
              state <= S_NORMAL;
            end if;

          when S_OFF_MSG =>
            if power_btn = '1' then
              state <= S_ON_MSG;
              timer <= 0;
            elsif timer >= OFF_MS then
              state <= S_OFF;
            end if;
        end case;
      end if;
    end if;
  end process;

  -- Outputs depend only on the current state
  with state select msg <=
    MSG_BLANK  when S_OFF,
    MSG_ON     when S_ON_MSG,
    MSG_NORMAL when S_NORMAL,
    MSG_ALERT  when S_ALERT,
    MSG_DROP   when S_DROP,
    MSG_OFF    when S_OFF_MSG;

  motor_en  <= '1' when state = S_ALERT else '0';
  yellow_en <= '1' when state = S_ALERT else '0';
  red_en    <= '1' when state = S_DROP  else '0';
  buzzer_en <= '1' when state = S_DROP  else '0';

  with state select state_leds <=
    "00001" when S_OFF | S_OFF_MSG,
    "00010" when S_ON_MSG,
    "00100" when S_NORMAL,
    "01000" when S_ALERT,
    "10000" when S_DROP;
end architecture rtl;
