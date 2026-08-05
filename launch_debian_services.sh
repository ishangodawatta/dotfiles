#!/bin/bash
# Starts the home-server services on this Debian machine: Tailscale, Plex
# (native systemd service), and Immich/Jellyfin (Docker Compose). Safe to
# re-run any time -- every step is idempotent, so running it against
# already-running services is a no-op.
#
# Usage:
#   ./launch_debian_services.sh          # start everything, print final status
#   ./launch_debian_services.sh --status # only print status, start nothing

set -euo pipefail

IMMICH_DIR="$HOME/src/immich-app"
JELLYFIN_DIR="$HOME/src/jellyfin-app"

status_only=false
if [[ "${1:-}" == "--status" ]]; then
  status_only=true
fi

start_systemd_service() {
  local name="$1"
  if systemctl is-active --quiet "$name"; then
    echo "$name: already active"
    return
  fi
  if [[ "$status_only" == true ]]; then
    echo "$name: inactive"
    return
  fi
  echo "$name: starting..."
  sudo systemctl start "$name"
}

start_compose_stack() {
  local name="$1"
  local dir="$2"
  if [[ ! -d "$dir" ]]; then
    echo "$name: skipped, $dir not found"
    return
  fi
  if [[ "$status_only" == true ]]; then
    (cd "$dir" && docker compose ps --status running --quiet | grep -q . \
      && echo "$name: running" || echo "$name: not running")
    return
  fi
  echo "$name: starting..."
  (cd "$dir" && docker compose up -d)
}

start_systemd_service tailscaled
start_systemd_service plexmediaserver
start_compose_stack immich "$IMMICH_DIR"
start_compose_stack jellyfin "$JELLYFIN_DIR"

echo
echo "=== Status ==="
echo "tailscaled:      $(systemctl is-active tailscaled 2>&1)"
echo "plexmediaserver: $(systemctl is-active plexmediaserver 2>&1)"
echo "immich:          $(docker ps --filter name=immich --format '{{.Names}}: {{.Status}}' 2>&1 || echo 'docker unavailable')"
echo "jellyfin:        $(docker ps --filter name=jellyfin --format '{{.Names}}: {{.Status}}' 2>&1 || echo 'docker unavailable')"
