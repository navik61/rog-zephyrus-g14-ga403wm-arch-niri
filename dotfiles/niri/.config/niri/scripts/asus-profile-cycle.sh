#!/bin/bash
# Cyklické přepnutí ASUS power/fan profilu (asusctl) + desktop notifikace
# Použití: bind na Fn+F5 (nebo jinou klávesu) v niri configu

set -euo pipefail

# Přepni na další profil v cyklu (Quiet -> Balanced -> Performance -> Quiet)
asusctl profile -n >/dev/null 2>&1

# Krátká pauza, aby EC/daemon stihl stav zapsat před čtením
sleep 0.15

# Zjisti aktuální profil (parsování výstupu "asusctl profile get")
RAW=$(asusctl profile get 2>/dev/null)
PROFILE=$(echo "$RAW" | grep -oiE 'quiet|balanced|performance' | head -1)

# Fallback, kdyby se parsování nepovedlo
if [ -z "$PROFILE" ]; then
    PROFILE="$RAW"
fi

# Ikona a barva podle profilu (uprav cesty/jména dle svého icon setu, nebo nech prázdné)
case "$(echo "$PROFILE" | tr '[:upper:]' '[:lower:]')" in
    quiet)
        ICON="weather-clear-night-symbolic"
        LABEL="Tichý"
        ;;
    balanced)
        ICON="weather-few-clouds-symbolic"
        LABEL="Vyvážený"
        ;;
    performance)
        ICON="weather-storm-symbolic"
        LABEL="Výkonnostní"
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
    --app-name="ASUS Profil" \
    --replace-id=91177 \
    "Power profil" "$LABEL"
