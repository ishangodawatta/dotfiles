# Services (this machine)

What runs where, on which drive, and why -- so state doesn't get lost between
this repo, the app repos, and whatever's plugged in on a given day.

**Goal: fully remove Extreme_SSD from this machine.** Lexar is the new
primary store for all media services; Extreme_SSD is being kept as a synced
mirror only until every service (Jellyfin done, Plex in progress, Immich not
started) no longer depends on it.

## Drives

- **Extreme_SSD** (SanDisk Extreme 55AE, exFAT, 1.8TB) -- mounted at
  `/media/ishan/Extreme_SSD` (udisks2) and `/mnt/extreme_ssd` (fstab,
  `UUID=BA1E-637C`). Being phased out; kept as an exact mirror of the Lexar's
  `Movies`/`TV_Series`/`Other_Videos` structure in the meantime, so it's a
  drop-in fallback if the Lexar has problems. Any reorganisation (renames,
  new folders) should happen on Extreme_SSD first, then be copied to the
  Lexar, so the mirror never drifts.
- **Lexar** (WD Black NVMe in a Lexar M.2 USB enclosure, exFAT, 932GB) --
  primary store for Jellyfin (done) and, eventually, Immich. Stable fstab
  mount at `/mnt/lexar_ssd` (`UUID=6A59-F21F`, `x-systemd.automount`) --
  set up the same way as Extreme_SSD's `/mnt/extreme_ssd` entry. Note: the
  enclosure's USB
  bridge chip caps out at 5Gbps (USB 3.0 Gen1) regardless of which port
  it's plugged into -- confirmed by testing both physical ports on the
  20Gbps-capable Thunderbolt controller. Doesn't matter for Jellyfin
  streaming or Immich sync (both need a small fraction of that bandwidth);
  it only means bulk copies onto the drive take longer than they need to.
- **HDD (planned)** -- redundancy backup target, specifically for Immich
  (asset files + Postgres dump). Not yet attached.

## Plex

Native systemd service (`plexmediaserver.service`), installed via apt --
no Docker, no repo, no compose file. Library paths live in Plex's own
SQLite state under `/var/lib/plexmediaserver/...` (root-owned, not
readable/editable directly -- changes must go through the Plex web UI's
"Edit Library" flow to avoid orphaning metadata/watch history).
**Migration to the Lexar is in progress** as part of the Extreme_SSD
removal goal above.

## Jellyfin

- Repo: `git@github.com:ishangodawatta/jellyfin-app.git` (`~/src/jellyfin-app`)
- Docker Compose, bind-mounts (all read-only, all on the Lexar as of
  2026-08-06):
  - `/mnt/lexar_ssd/Movies` -> `/media/movies`
  - `/mnt/lexar_ssd/TV_Series` -> `/media/tv`
  - `/mnt/lexar_ssd/Other_Videos` -> `/media/other` (Sports/TV Specials --
    folder needs adding as a library in the Jellyfin web UI, e.g. as
    "Mixed content", since fight footage/TV specials won't match well
    against movie metadata providers)
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
- Asset library (`UPLOAD_LOCATION`) migrating to the Lexar.
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
- [ ] Add the `Other_Videos` (Sports/TV Specials) library in the Jellyfin web UI
- [ ] Migrate Plex's library paths to the Lexar via the Plex web UI (in progress)
- [ ] Migrate Immich's `UPLOAD_LOCATION` to the Lexar (in progress)
- [ ] Attach redundancy HDD, point it at the Lexar's `family_media/` folder
      (covers Immich assets and its built-in Postgres backups in one copy)
- [ ] Once Plex + Immich are off Extreme_SSD, disconnect it
