# Services (this machine)

What runs where, on which drive, and why -- so state doesn't get lost between
this repo, the app repos, and whatever's plugged in on a given day.

**Goal: fully remove Extreme_SSD from this machine, then repurpose it as a
personal drive.** Lexar is now the primary store for all media services --
Jellyfin and Immich (Plex was migrated too, then fully removed in favour
of standardising on Jellyfin alone, see "Plex -- removed" below). Extreme_SSD is being
mirrored onto a backup HDD (see "Extreme_SSD -> HDD mirror" below) so it
can be safely disconnected -- it's not being kept as a permanent fallback,
it's on its way out once the mirror is complete.

## Drives

- **Extreme_SSD** (SanDisk Extreme 55AE, exFAT, 1.8TB) -- mounted at
  `/media/ishan/Extreme_SSD` (udisks2) and `/mnt/extreme_ssd` (fstab,
  `UUID=BA1E-637C`). Being phased out; kept as an exact mirror of the Lexar's
  `Movies`/`TV_Series`/`Other_Videos`/`family_media` structure in the
  meantime, so it's a drop-in fallback if the Lexar has problems. Any
  reorganisation (renames, new folders) should happen on Extreme_SSD first,
  then be copied to the Lexar, so the mirror never drifts. Still holds a lot
  of unrelated personal data (`work`, `projects`, `wedding_nov_2024`, etc.)
  that was never part of this migration and has no copy elsewhere -- do not
  wipe until that's backed up separately.
- **Lexar** (WD Black NVMe in a Lexar M.2 USB enclosure, exFAT, 932GB) --
  primary store for Jellyfin and Immich (Plex was migrated here too, then
  removed entirely -- see "Plex -- removed"). Stable fstab
  mount at `/mnt/lexar_ssd` (`UUID=6A59-F21F`, `x-systemd.automount`) --
  set up the same way as Extreme_SSD's `/mnt/extreme_ssd` entry. Note: the
  enclosure's USB
  bridge chip caps out at 5Gbps (USB 3.0 Gen1) regardless of which port
  it's plugged into -- confirmed by testing both physical ports on the
  20Gbps-capable Thunderbolt controller. Doesn't matter for Jellyfin
  streaming or Immich sync (both need a small fraction of that bandwidth);
  it only means bulk copies onto the drive take longer than they need to.
- **HDD** (Seagate ST2000LM007, exFAT, 1.8TB, labelled `Trans_2TB`, mounted
  at `/media/ishan/Trans_2TB`) -- redundancy backup target. Originally
  planned just for Immich; scope expanded to a full mirror of Extreme_SSD
  (see "Extreme_SSD -> HDD mirror" below), since the goal is to let
  Extreme_SSD be disconnected and repurposed once this HDD covers everything
  it held. Prone to intermittently dropping off USB during long transfers --
  if a command suddenly can't see `/media/ishan/Trans_2TB`, check `lsblk`
  and reconnect the cable rather than assuming something's broken.

## Extreme_SSD -> HDD mirror (in progress)

Goal, in order: (1) make the HDD a full mirror of Extreme_SSD's contents,
(2) disconnect Extreme_SSD and let it be repurposed as a personal drive,
(3) sync the HDD against the **Lexar** (not Extreme_SSD) to pick up
anything Jellyfin/Immich have added since the original Lexar migration,
since Extreme_SSD's snapshot is by then stale.

How the mirror was built: compared the HDD's pre-existing (old, differently
organised) content against Extreme_SSD folder by folder. Anything on the
HDD not matching something on Extreme_SSD got staged into a top-level
`to-validate/` folder on the HDD (never deleted outright -- staged for
Ishan to review and clear manually). Folders present on both got
reconciled so the HDD matches Extreme_SSD.

Non-obvious lesson learned partway through: naive matching by exact
relative path treats "the same movie/show under an old messy filename" as
missing content, causing a full re-copy from Extreme_SSD *and* leaving the
old (actually-duplicate) copy sitting in `to-validate` -- ended up staging
nearly 300GB of Movies that turned out ~95% duplicate. Fix used from then
on: fuzzy-match by normalised title/year first, and where the old HDD copy
turns out byte/size-identical to the Extreme_SSD-sourced copy, delete the
`to-validate` duplicate rather than leaving it for manual review (only
genuinely unmatched or differently-sized content stays staged).

Status as of last update:
- `Movies`: fully reconciled -- full-tree verified, 448/448 files,
  byte-identical apparent size on both drives. `to-validate/Movies` cleaned
  from 190 items/294GB down to ~8 genuinely unresolved items/~14GB (a few
  titles genuinely absent from Extreme_SSD, a few different-quality
  encodes of the same film, plus 2 items -- `Boxing Matches`, the Oprah CBS
  special -- waiting on `Other_Videos`).
- `TV_Series`: **fully reconciled and verified** -- 1756/1756 files,
  byte-identical apparent size on both drives. One important lesson from
  finishing this: a couple of shows' fork-reported "size-verified"
  checkpoints turned out to be wrong (Game of Thrones was missing 75 files
  of bonus content -- Behind The Scenes/Deleted Scenes/Featurettes -- despite
  being marked done; a whole extra show, `Pokémon Origins`, was missed
  entirely since it wasn't a rename of anything already on the HDD, so it
  never appeared in the original comparison). Caught both via a final
  full-tree `find`+diff pass across all of `TV_Series` comparing file
  counts and total apparent bytes, not by trusting per-show checkpoints.
  **Do this same full-tree verification pass on any folder before
  considering it actually done**, not just spot checks.
- Other shared folders (`asoka_soundtrack`, `chears`, `emulators`, `games`,
  `random`, `rental_accommodation`, `school.zip`, `senara`, `software`,
  `uom`, `work`): reconciled and full-tree verified, all genuinely
  byte-identical. Only `Movies` and `TV_Series` had leftover empty old-name
  "husk" folders in main after content moved out from under them -- both
  cleaned up.
- Extreme_SSD-only folders never previously on the HDD at all (small ones
  copied: `courses`, `library-followups`, `parallels`, `postage`,
  `projects`, `receipts`, `selling`; large ones still queued:
  `family_media` ~91GB, `parallels_vm` ~87GB, `wedding_nov_2024` ~35GB;
  `Other_Videos` ~6GB queued alongside them).
- Progress checkpointed to `/media/ishan/Trans_2TB/.reconcile-progress.log`
  on the HDD itself (survives a session/agent restart -- read it directly
  rather than trusting a resumed process's self-report, which has been
  wrong more than once during this work).

## Plex -- removed

Was a native systemd service (`plexmediaserver.service`), installed via apt
-- no Docker, no repo, no compose file. Fully migrated to the Lexar as of
2026-08-06 (see git history of this file for that detail), then fully
removed in favour of standardising on Jellyfin as the only media server.
`systemctl stop`/`disable`, then `apt purge plexmediaserver` + `apt
autoremove` -- confirmed clean afterward: package gone from `dpkg -l`, the
systemd unit gone, `/var/lib/plexmediaserver` (library database/watch
history) gone. Nothing left behind.

## Jellyfin

- Repo: `git@github.com:ishangodawatta/jellyfin-app.git` (`~/src/jellyfin-app`)
- Docker Compose, bind-mounts (all read-only, all on the Lexar as of
  2026-08-06):
  - `/mnt/lexar_ssd/Movies` -> `/media/movies`
  - `/mnt/lexar_ssd/TV_Series` -> `/media/tv`
  - `/mnt/lexar_ssd/Other_Videos` -> `/media/other`
- `Other Videos` library added in the Jellyfin web UI as "Mixed Movies and
  Shows" content type (Sports/TV Specials won't match well against strict
  movie metadata providers), scanned clean, shows both `Sports` and
  `TV Specials` folders.
- Container-internal paths never change even when the host source does, so
  Jellyfin's watch history/metadata matches survive drive migrations
  transparently -- no rescans or path fixups needed on our end.

## Samba (NAS / SMB share)

Native systemd service (`smbd`, via the `samba` apt package) -- no Docker.
Purpose: browse/move arbitrary files (not just media) to/from this machine
from any device, e.g. drag-and-drop from the iPhone's Files app.

- Share `[lexar]` -> `/mnt/lexar_ssd`, config in `/etc/samba/smb.conf`
  (system file, sudo-only, not tracked by this repo -- documented here
  instead).
- Auth: separate Samba password for `ishan`, set via `sudo smbpasswd -a
  ishan` (distinct from the system login password).
- Access from any device: `smb://xps-9530.tail646a3d.ts.net/lexar`
  (Tailscale MagicDNS). Confirmed working from the iPhone's Files app
  (Browse -> ... -> Connect to Server).
- **Restricted to the tailnet via `hosts allow`/`hosts deny`, not interface
  binding.** Tried `interfaces = <tailscale ip>/32` + `bind interfaces only
  = yes` first (the "obvious" way to keep smbd off the LAN/other Wi-Fi) --
  it silently broke everything, because `tailscale0` is a non-broadcast
  point-to-point interface and Samba's interface code explicitly refuses
  those (`not adding non-broadcast interface tailscale0` in the log),
  leaving smbd bound to loopback only. Fix: `smbd` listens on all
  interfaces as normal, and `[global]` has:
  ```
  hosts allow = 100.64.0.0/10 127.0.0.1
  hosts deny = 0.0.0.0/0
  ```
  (`100.64.0.0/10` is Tailscale's whole CGNAT range, so this doesn't need
  updating if the device's own Tailscale IP ever changes.) Threat model:
  this laptop only ever joins home Wi-Fi or its own phone's hotspot, both
  self-controlled, so the app-layer restriction was judged sufficient --
  an nftables rule to also drop 139/445 at the kernel level on non-Tailscale
  interfaces was considered and deliberately skipped. Revisit if that
  changes (e.g. regularly using untrusted/public networks).
- Taildrop (Tailscale's built-in peer-to-peer file send) was considered as
  an alternative/complement but not set up -- no default receive folder on
  Linux (files sit in `tailscaled`'s internal inbox until `tailscale file
  get <dir>` is run manually), and the SMB share alone covers the "move
  files around" need.

## Media folder conventions

Applies to `Movies`, `TV_Series`, and `Other_Videos` on both drives:
- One folder per title, folder name matches filename: `Title (Year)/Title (Year).ext`
- `Other_Videos/Sports/<sport>/Title (Year)/...` and
  `Other_Videos/TV Specials/Title (Year)/...` follow the same pattern
- Standalone compilations (e.g. clip compilations, "Best of" collections)
  live directly in `Movies/`, foldered the same way, rather than under
  `Other_Videos` -- they're single-file items like a movie, not episodic,
  so they fit the Movies library type better than TV

## Immich

- Repo: `git@github.com:ishangodawatta/immich-app.git` (`~/src/immich-app`)
- Docker Compose: `immich-server`, `immich-machine-learning`, `redis`, `postgres`.
- **Postgres data stays on the internal NVMe** (`DB_DATA_LOCATION=./postgres`,
  relative to the repo) -- deliberate, not an oversight. Postgres needs
  POSIX filesystem guarantees (fsync, proper journaling) that exFAT over USB
  can't reliably provide; only the asset library moves to external storage.
- Asset library (`UPLOAD_LOCATION`) **fully migrated to the Lexar** as of
  2026-08-06 (`/mnt/lexar_ssd/family_media/immich_library`). Containers
  stopped, final `rsync` confirmed byte-identical (zero files transferred),
  `.env` repointed, containers restarted clean.
- `roshani_backups` (`/mnt/lexar_ssd/family_media/roshani_backups`) added as
  a second read-only External Library alongside `ishan_backups`, same
  pattern (owner: Ishan, the only Immich user on this instance).
- **Postgres backup is already handled by Immich itself** -- it writes
  scheduled `pg_dump`-style archives to `<UPLOAD_LOCATION>/backups/`
  (`immich-db-backup-<timestamp>-<version>.sql.gz`, daily). No separate
  backup script needed; a custom one was written and then removed once this
  was discovered. The redundancy HDD copy just needs to include this
  `backups/` folder along with the rest of the asset library -- one file
  copy covers both.

## Outstanding

- [x] Set up a stable UUID-based fstab mount for the Lexar (`/mnt/lexar_ssd`)
- [x] Repoint jellyfin-app compose source paths at the Lexar mount
- [x] Samba SMB share of `/mnt/lexar_ssd`, restricted to the tailnet
- [x] Migrate Plex's library paths to the Lexar via the Plex web UI
- [x] Remove Plex entirely (`apt purge`), standardise on Jellyfin
- [x] Migrate Immich's `UPLOAD_LOCATION` to the Lexar
- [x] Add `roshani_backups` as a second Immich External Library
- [x] Add the `Other_Videos` (Sports/TV Specials) library in the Jellyfin web UI
- [x] Attach redundancy HDD (`Trans_2TB`)
- [ ] Finish HDD <-> Extreme_SSD mirror (Movies done; TV_Series in
      progress; small Extreme_SSD-only folders copied, large ones queued:
      `family_media`, `parallels_vm`, `wedding_nov_2024`, `Other_Videos`)
- [ ] Disconnect Extreme_SSD once the mirror is confirmed complete --
      nothing left depends on it being connected, but it still holds the
      only copy of `work`/`projects`/`wedding_nov_2024`/etc. until the
      mirror finishes, so don't disconnect early
- [ ] After Extreme_SSD is disconnected: sync the HDD against the **Lexar**
      (not Extreme_SSD) to catch up on anything Jellyfin/Immich have added
      since the original Lexar migration -- Extreme_SSD's snapshot will be
      stale by that point
