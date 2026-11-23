#!/bin/bash
# Notifikace při změně ASUS power/fan profilu.
# Sleduje /sys/firmware/acpi/platform_profile přes inotify - funguje
# nezávisle na tom, čím byla změna vyvolána (Fn+F5, asusctl, cokoliv jiného),
# takže nehrozí kolize s nativním cyklením klávesy.

FILE="/sys/firmware/acpi/platform_profile"
LAST=""

label_and_icon() {
    case "$1" in
        quiet)       echo "Tichý|weather-clear-night-symbolic" ;;
        balanced)    echo "Vyvážený|weather-few-clouds-symbolic" ;;
        performance) echo "Výkonnostní|weather-storm-symbolic" ;;
        *)           echo "$1|dialog-information-symbolic" ;;
    esac
}

notify_if_changed() {
    local profile
    profile=$(cat "$FILE" 2>/dev/null)
    [ -z "$profile" ] && return
    [ "$profile" = "$LAST" ] && return
    LAST="$profile"

    local label icon
    IFS='|' read -r label icon <<< "$(label_and_icon "$profile")"

    notify-send \
        --urgency=low \
        --expire-time=2500 \
        --icon="$icon" \
        --app-name="ASUS Profil" \
        --replace-id=91177 \
        "Power profil" "$label"
}

# Inicializační stav - bez notifikace hned při startu služby
LAST=$(cat "$FILE" 2>/dev/null)

inotifywait -m -e modify --format '%e' "$FILE" 2>/dev/null | while read -r _; do
    # sysfs atributy občas pošlou víc MODIFY eventů za sebou - debounce
    sleep 0.1
    notify_if_changed
done
