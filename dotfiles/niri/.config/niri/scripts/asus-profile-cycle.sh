#!/bin/bash
# Cycle the ASUS power/fan profile (asusctl) + desktop notification
# Usage: bind to Fn+F5 (or another key) in the niri config

set -euo pipefail

# Switch to the next profile in the cycle (Quiet -> Balanced -> Performance -> Quiet)
asusctl profile -n >/dev/null 2>&1

# Short pause so the EC/daemon can write the state before we read it
sleep 0.15

# Get the current profile (parse the output of "asusctl profile get")
RAW=$(asusctl profile get 2>/dev/null)
PROFILE=$(echo "$RAW" | grep -oiE 'quiet|balanced|performance' | head -1)

# Fallback in case parsing failed
if [ -z "$PROFILE" ]; then
    PROFILE="$RAW"
fi

# Icon and label per profile (adjust icon names to your icon set, or leave empty)
case "$(echo "$PROFILE" | tr '[:upper:]' '[:lower:]')" in
    quiet)
        ICON="weather-clear-night-symbolic"
        LABEL="Quiet"
        ;;
    balanced)
        ICON="weather-few-clouds-symbolic"
        LABEL="Balanced"
        ;;
    performance)
        ICON="weather-storm-symbolic"
        LABEL="Performance"
        ;;
    *)
        ICON="dialog-information-symbolic"
        LABEL="$PROFILE"
        ;;
esac

notify-send \
    --urgency=low \
    --expire-time=2500 \
    --icon="$ICON" \
    --app-name="ASUS Profile" \
    --replace-id=91177 \
    "Power profile" "$LABEL"
