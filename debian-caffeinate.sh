#!/bin/bash
# Linux equivalent of macOS `caffeinate -i`. Ctrl-C to release.
#
# Blocks idle-sleep until the script is killed. Persists across AC/battery
# transitions. Does NOT block lid-close suspend (pass --lid to also block that)
# and does NOT block critical-battery suspend.
#
# Usage:
#   ./debian-caffeinate.sh                       # block idle-sleep only
#   ./debian-caffeinate.sh --lid                 # also block lid-close suspend
#   ./debian-caffeinate.sh "long ml run"         # custom reason (shows in systemd-inhibit --list)

set -euo pipefail

WHAT="idle"
if [[ "${1:-}" == "--lid" ]]; then
  WHAT="idle:handle-lid-switch"
  shift
fi

exec systemd-inhibit \
  --what="$WHAT" \
  --who="${USER}-caffeinate" \
  --why="${1:-keeping system awake}" \
  sleep infinity
