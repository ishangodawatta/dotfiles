#!/bin/bash
# Plex server power mode for macOS.
#
# Run this script from a terminal whilst you want the laptop to behave like a
# rock-solid Plex server: never sleeps on AC, lid-close stays on, wakes on LAN,
# auto-restarts after a power cut, and sleeps after 5 min idle on battery.
#
# Press Ctrl-C, close the terminal, or kill the process to restore your
# previous pmset settings.
#
# Usage: ~/src/dotfiles/plex-power-watcher.sh

set -euo pipefail

# Re-exec under sudo once so subsequent pmset calls don't repeatedly prompt.
if [[ $EUID -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

# Look up a pmset value for a given profile, falling back to a default if the
# key isn't present (pmset -g custom omits keys at their factory default).
get_pmset() {
  local profile="$1" key="$2" default="$3" val
  val=$(pmset -g custom | awk -v profile="$profile" -v key="$key" '
    /^[A-Z][a-zA-Z ]*:$/ { current=$0; sub(/:$/,"",current); next }
    current == profile && $1 == key { print $2; exit }
  ')
  echo "${val:-$default}"
}

ORIG_C_SLEEP=$(get_pmset       "AC Power"      sleep         1)
ORIG_C_DISABLESLEEP=$(get_pmset "AC Power"      disablesleep  0)
ORIG_C_WOMP=$(get_pmset         "AC Power"      womp          0)
ORIG_C_AUTORESTART=$(get_pmset  "AC Power"      autorestart   0)
ORIG_C_ACWAKE=$(get_pmset       "AC Power"      acwake        0)
ORIG_B_SLEEP=$(get_pmset        "Battery Power" sleep         1)
ORIG_B_DISABLESLEEP=$(get_pmset "Battery Power" disablesleep  0)

RESTORED=false
restore() {
  $RESTORED && return
  RESTORED=true
  echo
  echo "==> Restoring previous pmset config"
  pmset -c sleep "$ORIG_C_SLEEP" disablesleep "$ORIG_C_DISABLESLEEP" \
            womp "$ORIG_C_WOMP" autorestart "$ORIG_C_AUTORESTART" \
            acwake "$ORIG_C_ACWAKE" || true
  pmset -b sleep "$ORIG_B_SLEEP" disablesleep "$ORIG_B_DISABLESLEEP" || true
  echo "Done."
}
trap restore EXIT INT TERM HUP

echo "==> Applying Plex server power config"
pmset -c sleep 0 disablesleep 1 womp 1 autorestart 1 acwake 1
pmset -b sleep 5 disablesleep 0

echo
echo "Active settings:"
pmset -g | grep -E "^\s*(sleep|disablesleep|womp|autorestart|acwake)\b" || true
echo
echo "Plex server mode active. Press Ctrl-C (or close this terminal) to restore."

# Idle until interrupted; the trap handles restore.
while true; do
  sleep 3600 &
  wait $!
done
