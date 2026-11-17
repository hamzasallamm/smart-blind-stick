# Smart Blind Stick - DE10-Lite pin assignments (GPIO header version)
# In Quartus: open the project, then
#   Assignments -> Remove Assignments -> tick "Pin, Location & Routing" -> OK
#   Tools -> Tcl Scripts... -> pins.tcl -> Run
#   Processing -> Start Compilation, then Tools -> Programmer -> Start

# ---- On the board ----
set_location_assignment PIN_P11 -to clk            ;# 50 MHz clock
set_location_assignment PIN_A7  -to rst_n          ;# KEY1 = reset
set_location_assignment PIN_B8  -to key_power_n    ;# KEY0 = spare ON/OFF button

# ---- GPIO header (JP1) ----
set_location_assignment PIN_V10  -to ir_out_n       ;# header pin 1  (GPIO 0)
set_location_assignment PIN_V9   -to motor          ;# header pin 3  (GPIO 2)
set_location_assignment PIN_W9   -to led_red        ;# header pin 4  (GPIO 3)  red LED
set_location_assignment PIN_V8   -to led_yellow     ;# header pin 5  (GPIO 4)  yellow LED
set_location_assignment PIN_AB12 -to touch          ;# header pin 19 (GPIO 16)
set_location_assignment PIN_AA6  -to buzzer_pwr     ;# header pin 33 (GPIO 28)
set_location_assignment PIN_AB2  -to buzzer_s       ;# header pin 39 (GPIO 34)
set_location_assignment PIN_AA2  -to btn_power_n    ;# header pin 40 (GPIO 35) ON/OFF button

# Push button goes to GND only: turn on the FPGA's built-in pull-up resistor.
# Same for the IR input, so an unplugged IR wire reads as "no obstacle".
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to btn_power_n
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to ir_out_n
# The buzzer's + is powered from a pin: give that pin the strongest output
set_instance_assignment -name CURRENT_STRENGTH_NEW "MAXIMUM CURRENT" -to buzzer_pwr

# ---- LEDs on the board ----
set_location_assignment PIN_A8  -to {state_leds[0]}  ;# LEDR0 = OFF
set_location_assignment PIN_A9  -to {state_leds[1]}  ;# LEDR1 = ON
set_location_assignment PIN_A10 -to {state_leds[2]}  ;# LEDR2 = NORMAL
set_location_assignment PIN_B10 -to {state_leds[3]}  ;# LEDR3 = ALERT
set_location_assignment PIN_D13 -to {state_leds[4]}  ;# LEDR4 = DROP
set_location_assignment PIN_C13 -to {debug_leds[0]}  ;# LEDR5 = hand on touch sensor
set_location_assignment PIN_E14 -to {debug_leds[1]}  ;# LEDR6 = IR sees obstacle
set_location_assignment PIN_D14 -to {debug_leds[2]}  ;# LEDR7 = ON/OFF button pressed
set_location_assignment PIN_A11 -to {debug_leds[3]}  ;# LEDR8 = yellow LED + motor on
set_location_assignment PIN_B11 -to {debug_leds[4]}  ;# LEDR9 = red LED on

# ---- 7-segment displays (bit 7 = decimal point) ----
set hex_pins {
  hex0 {C14 E15 C15 C16 E16 D17 C17 D15}
  hex1 {C18 D18 E18 B16 A17 A18 B17 A16}
  hex2 {B20 A20 B19 A21 B21 C22 B22 A19}
  hex3 {F21 E22 E21 C19 C20 D19 E17 D22}
  hex4 {F18 E20 E19 J18 H19 F19 F20 F17}
  hex5 {J20 K20 L18 N18 M20 N19 N20 L19}
}
foreach {name pins} $hex_pins {
  for {set i 0} {$i < 8} {incr i} {
    set_location_assignment PIN_[lindex $pins $i] -to ${name}\[$i\]
  }
}

# All pins use 3.3 V logic
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to *
# Pins we don't use stay as harmless inputs (never driven)
set_global_assignment -name RESERVE_ALL_UNUSED_PINS_WEAK_PULLUP "AS INPUT TRI-STATED"

puts "Pin assignments done."
