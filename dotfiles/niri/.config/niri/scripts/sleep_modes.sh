#!/bin/bash
# Time-of-day display modes (bound to Ctrl+1..5 in niri):
# laptop panel brightness, external monitor via DDC/CI, color temperature via wl-gammarelay-rs.

# Laptop backlight device
LAPTOP_BACKLIGHT="amdgpu_bl1"

# Set the external monitor via DDC/CI
# Skipped if DDC is not available (e.g. through DisplayLink/DP)
set_external_color() {
    # $1 = brightness, $2 = R, $3 = G, $4 = B (all 0-100)
    ddcutil detect --brief 2>/dev/null | grep -q "Display 1" || return 0
    ddcutil setvcp 14 0x0b --noverify 2>/dev/null  # User 1 preset
    ddcutil setvcp 10 "$1" --noverify 2>/dev/null
    ddcutil setvcp 16 "$2" --noverify 2>/dev/null  # Red
    ddcutil setvcp 18 "$3" --noverify 2>/dev/null  # Green
    ddcutil setvcp 1a "$4" --noverify 2>/dev/null  # Blue
}

# Send a command to wl-gammarelay-rs
set_gamma() {
    # $1 = temperature (K), $2 = brightness (0.0 - 1.0)
    busctl --user set-property rs.wl-gammarelay \
        /rs/wl_gammarelay rs.wl.gammarelay Temperature q "$1"
    busctl --user set-property rs.wl-gammarelay \
        /rs/wl_gammarelay rs.wl.gammarelay Brightness d "$2"
}

case $1 in
    1) # DAY
        brightnessctl --device=$LAPTOP_BACKLIGHT set 100%
        set_external_color 100 50 49 50
        set_gamma 6500 1.0
        ;;
    2) # OFFICE
        brightnessctl --device=$LAPTOP_BACKLIGHT set 60%
        set_external_color 70 50 44 39
        set_gamma 4800 0.9
        ;;
    3) # EVENING
        brightnessctl --device=$LAPTOP_BACKLIGHT set 30%
        set_external_color 40 50 43 34
        set_gamma 4200 0.8
        ;;
    4) # NIGHT
        brightnessctl --device=$LAPTOP_BACKLIGHT set 20%
        set_external_color 20 50 41 29
        set_gamma 3700 0.8
        ;;
    5) # DEEP NIGHT
        brightnessctl --device=$LAPTOP_BACKLIGHT set 10%
        set_external_color 5 50 39 23
        set_gamma 3200 0.7
        ;;
esac
