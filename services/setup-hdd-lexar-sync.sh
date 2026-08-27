#!/usr/bin/env bash
# Installs sync-hdd-from-lexar.sh as a daily systemd timer. Idempotent --
# safe to re-run. Portable to another Debian device/user: paths are
# derived from where this script actually lives and who invoked it, not
# hardcoded to this machine.
#
# Usage: sudo ./setup-hdd-lexar-sync.sh

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this with sudo." >&2
  exit 1
fi

RUN_AS_USER="${SUDO_USER:-}"
if [ -z "$RUN_AS_USER" ]; then
  echo "Could not determine the invoking user (run via sudo, not as root directly)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_SCRIPT="${SCRIPT_DIR}/sync-hdd-from-lexar.sh"

if [ ! -x "$SYNC_SCRIPT" ]; then
  echo "Expected an executable sync-hdd-from-lexar.sh next to this script at: $SYNC_SCRIPT" >&2
  exit 1
fi

SERVICE_FILE=/etc/systemd/system/hdd-lexar-sync.service
TIMER_FILE=/etc/systemd/system/hdd-lexar-sync.timer

echo "==> Installing ${SERVICE_FILE} (runs as ${RUN_AS_USER})"
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Sync backup HDD from Lexar SSD
Wants=network-online.target

[Service]
Type=oneshot
User=${RUN_AS_USER}
ExecStart=${SYNC_SCRIPT}
EOF

echo "==> Installing ${TIMER_FILE} (every 6h, catches up if the machine was off)"
cat > "$TIMER_FILE" << 'EOF'
[Unit]
Description=Sync backup HDD from Lexar SSD every 6 hours

[Timer]
OnCalendar=00/6:00:00
Persistent=true
RandomizedDelaySec=15m

[Install]
WantedBy=timers.target
EOF

echo "==> Reloading systemd and enabling the timer"
systemctl daemon-reload
systemctl enable --now hdd-lexar-sync.timer

echo "==> Done. Status:"
systemctl status hdd-lexar-sync.timer --no-pager
echo
echo "Next scheduled run:"
systemctl list-timers hdd-lexar-sync.timer --no-pager
echo
echo "To run a sync immediately: sudo systemctl start hdd-lexar-sync.service"
echo "To watch logs: journalctl -u hdd-lexar-sync.service -f"
