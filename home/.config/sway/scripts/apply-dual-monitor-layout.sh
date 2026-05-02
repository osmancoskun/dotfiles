#!/usr/bin/env bash
# 4K (3840x2160) @ 1.5 left, 2K (2560x1440 or 2560x1600) @ 1.25 right.
# Must run AFTER Sway finishes loading config (spawn deferred from exec_always + sleep).
# Log: ~/.local/state/sway-dual-monitor.log

set -uo pipefail
PATH="/usr/bin:/bin:$PATH"

STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
LOG="$STATE/sway-dual-monitor.log"
mkdir -p "$STATE"
exec 200>"$STATE/sway-dual-monitor.lock"
flock -n 200 || exit 0

log() {
  echo "$(date -Iseconds) $*" >>"$LOG"
}

log "start pid=$$"

if ! command -v jq >/dev/null 2>&1; then
  log "ERROR: jq not installed (sudo dnf install -y jq)"
  exit 0
fi
if ! command -v swaymsg >/dev/null 2>&1; then
  log "ERROR: swaymsg not in PATH"
  exit 0
fi

SCALE_4K="1.5"
SCALE_2K="1.25"
LEFT_LOGICAL_W=2560

mode_str() {
  local json=$1 name=$2
  echo "$json" | jq -r --arg n "$name" \
    '.[] | select(.name == $n) | "\(.current_mode.width)x\(.current_mode.height)"'
}

# Any output with a current_mode (do not require .active — field varies / timing)
pick_name() {
  local json=$1 k=$2
  echo "$json" | jq -r --arg k "$k" '
    if $k == "fourk" then
      ( [.[] | select(.current_mode != null)
              | select(.current_mode.width == 3840 and .current_mode.height == 2160)
              | select(.name | test("^eDP") | not) ][0]
      // [.[] | select(.current_mode != null)
              | select(.current_mode.width == 3840 and .current_mode.height == 2160) ][0]
      ) | .name // empty
    elif $k == "twok" then
      ( [.[] | select(.current_mode != null)
              | select((.current_mode.width == 2560 and .current_mode.height == 1440)
                    or (.current_mode.width == 2560 and .current_mode.height == 1600))
              | select(.name | test("^eDP") | not) ][0]
      // [.[] | select(.current_mode != null)
              | select((.current_mode.width == 2560 and .current_mode.height == 1440)
                    or (.current_mode.width == 2560 and .current_mode.height == 1600)) ][0]
      ) | .name // empty
    else empty end
  '
}

# Wait until swaymsg talks to this session (SWAYSOCK set after session ready)
for _warm in $(seq 1 50); do
  if out=$(swaymsg -t get_outputs -r 2>/dev/null) && [[ -n "$out" ]] && [[ "$out" != "[]" ]]; then
    log "swaymsg ok (warm try $_warm)"
    break
  fi
  log "swaymsg not ready yet (try $_warm)"
  sleep 0.15
done

for _try in $(seq 1 40); do
  json=$(swaymsg -t get_outputs -r 2>/dev/null) || json=""
  if [[ -z "$json" || "$json" == "[]" ]]; then
    log "empty get_outputs (try $_try)"
    sleep 0.25
    continue
  fi

  echo "$json" | jq -r '.[] | "\(.name) \(.current_mode.width // "?")x\(.current_mode.height // "?")"' >>"$LOG" || true

  fourk=$(pick_name "$json" fourk)
  twok=$(pick_name "$json" twok)

  if [[ -n "$fourk" && -n "$twok" && "$fourk" != "$twok" ]]; then
    m4=$(mode_str "$json" "$fourk")
    m2=$(mode_str "$json" "$twok")
    if [[ -z "$m4" || "$m4" == "nullxnull" || -z "$m2" || "$m2" == "nullxnull" ]]; then
      sleep 0.25
      continue
    fi
    log "applying fourk=$fourk ($m4) twok=$twok ($m2)"
    swaymsg output "$fourk" mode "$m4" scale "$SCALE_4K" position 0 0 >>"$LOG" 2>&1 || log "swaymsg fourk failed $?"
    swaymsg output "$twok" mode "$m2" scale "$SCALE_2K" position "$LEFT_LOGICAL_W" 0 >>"$LOG" 2>&1 || log "swaymsg twok failed $?"
    # Treat 4K as primary: workspace 1 lives there + input focus (no X11-style PRIMARY flag in sway).
    swaymsg workspace number 1 output "$fourk" >>"$LOG" 2>&1 || log "workspace assign failed $?"
    swaymsg focus output "$fourk" >>"$LOG" 2>&1 || log "focus output failed $?"
    log "done"
    exit 0
  fi

  log "no pair matched yet (try $_try) fourk=[$fourk] twok=[$twok]"
  sleep 0.25
done

log "give up: no 3840x2160 + 2560x1440/1600 pair seen — edit script if your modes differ"
exit 0
