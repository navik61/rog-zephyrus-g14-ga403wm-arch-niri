#!/bin/bash

# Zařízení pro jas notebooku
LAPTOP_BACKLIGHT="amdgpu_bl1"

# Funkce pro nastavení externího monitoru přes DDC/CI
# Přeskočí pokud DDC není dostupné (např. přes DisplayLink/DP)
set_external_color() {
    # $1 = jas, $2 = R, $3 = G, $4 = B (všechno 0-100)
    ddcutil detect --brief 2>/dev/null | grep -q "Display 1" || return 0
    ddcutil setvcp 14 0x0b --noverify 2>/dev/null  # User 1 preset
    ddcutil setvcp 10 "$1" --noverify 2>/dev/null
    ddcutil setvcp 16 "$2" --noverify 2>/dev/null  # Red
    ddcutil setvcp 18 "$3" --noverify 2>/dev/null  # Green
    ddcutil setvcp 1a "$4" --noverify 2>/dev/null  # Blue
}

# Funkce pro odeslání příkazu do wl-gammarelay-rs
set_gamma() {
    # $1 = Teplota (K), $2 = Jas (0.0 - 1.0)
    busctl --user set-property rs.wl-gammarelay \
        /rs/wl_gammarelay rs.wl.gammarelay Temperature q "$1"
    busctl --user set-property rs.wl-gammarelay \
        /rs/wl_gammarelay rs.wl.gammarelay Brightness d "$2"
}

case $1 in
    1) # DEN
        brightnessctl --device=$LAPTOP_BACKLIGHT set 100%
        set_external_color 100 50 49 50
        set_gamma 6500 1.0
        ;;
    2) # KANCELÁŘ
        brightnessctl --device=$LAPTOP_BACKLIGHT set 60%
        set_external_color 70 50 44 39
        set_gamma 4800 0.9
        ;;
    3) # PODVEČER
        brightnessctl --device=$LAPTOP_BACKLIGHT set 30%
        set_external_color 40 50 43 34
        set_gamma 4200 0.8
        ;;
    4) # NOC
        brightnessctl --device=$LAPTOP_BACKLIGHT set 20%
        set_external_color 20 50 41 29
        set_gamma 3700 0.8
        ;;
    5) # EXTRÉMNÍ NOC
        brightnessctl --device=$LAPTOP_BACKLIGHT set 10%
        set_external_color 5 50 39 23
        set_gamma 3200 0.7
        ;;
esac
