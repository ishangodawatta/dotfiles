#!/usr/bin/env bash
# Keeps the backup HDD's Jellyfin/Immich-relevant folders in sync with the
# Lexar (the live source), so the HDD backup doesn't drift stale over time.
# Additive only (no --delete): removes nothing, only adds/updates.
#
# Safe to run manually or via the systemd timer installed by
# setup-hdd-lexar-sync.sh. Exits cleanly (not an error) if either drive
# isn't currently connected/mounted, since both are removable.

set -euo pipefail

LEXAR="/mnt/lexar_ssd"
HDD="/mnt/trans_2tb"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# Accessing the mount point triggers the systemd automount if the drive is
# connected; if it's genuinely absent this just returns quickly.
if ! mountpoint -q "$LEXAR" 2>/dev/null && ! ls "$LEXAR" >/dev/null 2>&1; then
  log "Lexar not connected/mounted at $LEXAR -- skipping this run"
  exit 0
fi
if ! mountpoint -q "$HDD" 2>/dev/null && ! ls "$HDD" >/dev/null 2>&1; then
  log "Backup HDD not connected/mounted at $HDD -- skipping this run"
  exit 0
fi

log "Starting sync: Lexar -> HDD"

for folder in Movies TV_Series Other_Videos; do
  log "Syncing $folder"
  rsync -a "$LEXAR/$folder/" "$HDD/$folder/"
done

log "Syncing family_media/immich_library"
rsync -a "$LEXAR/family_media/immich_library/" "$HDD/family_media/immich_library/"

log "Sync complete"
