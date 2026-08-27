#!/usr/bin/env bash
# Sets up the Trans_2TB backup HDD as a stable-mounted Samba share, the same
# way the Lexar SSD is set up (see services/README.md). Idempotent -- safe
# to re-run.
#
# Usage: sudo ./setup-hdd-samba.sh

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this with sudo." >&2
  exit 1
fi

UUID="445C-BD1E"
MOUNT_POINT="/mnt/trans_2tb"
FSTAB_LINE="UUID=${UUID} ${MOUNT_POINT} exfat uid=1000,gid=1000,fmask=0022,dmask=0022,iocharset=utf8,nofail,x-systemd.automount,x-systemd.device-timeout=10 0 0"
SMB_CONF="/etc/samba/smb.conf"

echo "==> Creating mount point ${MOUNT_POINT}"
mkdir -p "$MOUNT_POINT"

if grep -qF "UUID=${UUID}" /etc/fstab; then
  echo "==> fstab entry for ${UUID} already present, skipping"
else
  echo "==> Adding fstab entry"
  echo "$FSTAB_LINE" >> /etc/fstab
fi

echo "==> Reloading systemd and starting the automount unit"
systemctl daemon-reload
systemctl start mnt-trans_2tb.automount

if grep -q "^\[hdd\]" "$SMB_CONF"; then
  echo "==> Samba [hdd] share already configured, skipping"
else
  echo "==> Adding Samba [hdd] share"
  cat >> "$SMB_CONF" << 'EOF'

[hdd]
   path = /mnt/trans_2tb
   valid users = ishan
   read only = no
   browsable = yes
   guest ok = no
EOF
fi

echo "==> Validating Samba config"
testparm -s

echo "==> Restarting smbd"
systemctl restart smbd

echo "==> Done. Verifying mount:"
findmnt "$MOUNT_POINT" || echo "WARNING: mount not showing yet, try 'ls $MOUNT_POINT' to trigger the automount"

echo "==> Verifying Samba share is configured and smbd is running:"
testparm -s 2>/dev/null | grep -A3 "^\[hdd\]" || echo "WARNING: [hdd] share not found in effective config"
systemctl is-active smbd
