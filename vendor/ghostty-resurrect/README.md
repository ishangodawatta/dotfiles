# ghostty-resurrect

Save Ghostty windows, tabs, working directories and exact Codex or Claude Code conversation IDs, then reopen them after a restart.

This local version is based on [redareda9/ghostty-resurrect](https://github.com/redareda9/ghostty-resurrect), revision a568557c72ffcd47afb1f935fb4179c4b97f7493. It replaces the original directory/title/timestamp guesses with process and open-transcript evidence, and adds protected automatic backups. The upstream npm release does not contain these changes.

## Requirements

- macOS, Ghostty 1.4 or newer, Node.js 18 or newer.
- Automation permission for the invoking terminal or background service to control Ghostty.
- Codex or Claude Code available in the shell used by Ghostty.

There are no npm dependencies. Install this checkout by linking its executable into your PATH; keep the adjacent lib directory with it. The dotfiles integration supplies the executable link and a LaunchAgent.

## Usage

```sh
ghostty-resurrect backup                 # explicit checkpoint before a planned shutdown
ghostty-resurrect status                 # check the last backup and any recovery warning
ghostty-resurrect restore --missing      # reopen saved conversations that are not running
```

Other commands are `show [name]`, `list`, `backup [name]`, `restore [name]` and `restore [name] --dry-run`. An ordinary restore refuses to duplicate a live conversation. The missing-only option also skips saved shell panes whose original terminal still exists.

An explicit `backup` accepts the current layout as the new checkpoint, including intentionally closed panes. Run it when you deliberately want to discard an older recovery layout. Named backups remain until you remove them.

## Exact conversation matching

Ghostty supplies each pane's foreground PID and TTY. The process tree handles launcher wrappers and app-server children. An agent's open main transcript supplies the exact conversation ID; Codex sub-agent transcripts are excluded. Resumed and forked main conversations can be older than the running process. Several conversations can share a directory or title without being confused.

Codex restores into the project directory recorded in its transcript, which can differ from a stale shell-reported directory. Custom session stores are retained. Claude requires an open main transcript; no timestamp or title fallback is used. A new empty agent, missing transcript, process race or ambiguous identity makes the capture fail and preserves the previous backup.

A successful restore verifies that the saved conversation IDs are open again. If startup is incomplete, it reports that fact and keeps the previous checkpoint protected; fix any prompts in the new panes and retry `restore --missing`.

## Automatic backup policy

Invoke `auto-backup` every 15 seconds from a LaunchAgent. It does not launch Ghostty when the app is closed.

- New or unchanged layouts are saved immediately when captured.
- Removing panes must remain stable for 60 seconds before replacing the checkpoint. This protects against windows closing one by one during shutdown.
- Losing all agent conversations never replaces a checkpoint containing agents automatically.
- A different Mac boot or Ghostty process cannot overwrite unrecovered conversations. Restore them or explicitly run `backup` to accept a fresh layout.
- Partially completed restores stay protected until the required conversations are running.

A newly opened session can be newer than the last scheduled capture. Run `backup` before a planned shutdown for an immediate checkpoint. Automatic backups do not guarantee preservation of changes made after the last successful capture.

Snapshots and the small current status files live in `~/.config/ghostty-resurrect/`, outside version control. The directory is private (0700), files are private (0600), writes use fsync plus atomic replacement, and macOS lockf serialises writers. Runtime status is replaced rather than accumulated as an unbounded log. `GHOSTTY_RESURRECT_DIR` selects an isolated backup store for testing. Legacy snapshots with guessed conversation identities are rejected.

## Recovery boundaries

Restoration reopens conversations and directories. It does not preserve running commands, process memory, unsaved editor buffers or terminal scrollback. Local jobs stop when the Mac shuts down. Remote jobs need their own persistence, such as tmux on the remote host.

Split panes are recreated as a left-to-right chain; nested geometry and window position/size are not preserved. Selected tabs are restored. Ghostty's own window-save-state can create additional empty windows alongside restored ones; the dotfiles setup disables that overlapping restoration.

Codex recovery was checked against live sessions and a stopped disposable conversation. Claude matching is covered by isolated tests, but has not been verified against a live Claude session on this Mac.

## Validation

```sh
npm test
```

The dependency-free Node tests cover native binaries, launcher trees, multiple sessions in one directory, old resumed sessions, sub-agents, uncertain identities, interrupted writes, private file modes, shutdown transitions, new boots, incomplete restores and duplicate prevention. Fixtures use temporary directories and are permanently removed after each test.

## Licence

MIT; see LICENSE. Original work by Reda (@redareda9).
