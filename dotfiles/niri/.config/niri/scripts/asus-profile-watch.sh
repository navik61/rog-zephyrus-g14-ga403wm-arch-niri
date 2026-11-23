#!/bin/bash
# Notification when the ASUS power/fan profile changes.
# Watches /sys/firmware/acpi/platform_profile via inotify - works
# regardless of what triggered the change (Fn+F5, asusctl, anything else),
# so it never collides with the key's native cycling.

FILE="/sys/firmware/acpi/platform_profile"
LAST=""

label_and_icon() {
    case "$1" in
        quiet)       echo "Quiet|weather-clear-night-symbolic" ;;
        balanced)    echo "Balanced|weather-few-clouds-symbolic" ;;
        performance) echo "Performance|weather-storm-symbolic" ;;
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
        --app-name="ASUS Profile" \
        --replace-id=91177 \
        "Power profile" "$label"
}

# Initial state - no notification right when the service starts
LAST=$(cat "$FILE" 2>/dev/null)

inotifywait -m -e modify --format '%e' "$FILE" 2>/dev/null | while read -r _; do
    # sysfs attributes sometimes fire several MODIFY events in a row - debounce
    sleep 0.1
    notify_if_changed
done
