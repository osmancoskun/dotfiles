#!/usr/bin/env bash
# Apply the Waybar blue-light percentage as a fixed color temperature.
# 0% exits without touching gamma. 100% is WLSUNSET_LOW.
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/wlsunset/wlsunset.env"
PERCENT_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/wlsunset/percent"

WLSUNSET_LOW=4000
WLSUNSET_HIGH=6500
WLSUNSET_SUNRISE=06:30
WLSUNSET_SUNSET=19:30
WLSUNSET_DURATION=1800
WLSUNSET_LAT=
WLSUNSET_LON=

if [[ -f "$CONFIG" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$CONFIG"
    set +a
fi

percent=0
if [[ -f "$PERCENT_FILE" ]]; then
    percent=$(tr -cd '0-9' <"$PERCENT_FILE" || true)
fi
[[ -n "$percent" ]] || percent=0
if ((percent <= 0)); then
    exit 0
fi
if ((percent > 100)); then
    percent=100
fi

# wlsunset requires the high temperature to be strictly above the low one.
# One Kelvin apart keeps the chosen strength fixed across day and night.
temp=$((WLSUNSET_HIGH - (WLSUNSET_HIGH - WLSUNSET_LOW) * percent / 100))
args=(-t "$temp" -T "$((temp + 1))")
if [[ -n "$WLSUNSET_LAT" && -n "$WLSUNSET_LON" ]]; then
    args+=(-l "$WLSUNSET_LAT" -L "$WLSUNSET_LON")
else
    args+=(-S "$WLSUNSET_SUNRISE" -s "$WLSUNSET_SUNSET" -d "$WLSUNSET_DURATION")
fi

exec /usr/bin/wlsunset "${args[@]}"
