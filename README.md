# .files 
(but also, a little bit more)

Stuff might be broken, don't hate the player, hate the game.
Shout out to [Tom Cassar](https://github.com/tcassar/dotfiles) for the configs.

## Setup
Run `./setup-macos.sh` to install essential tools and applications.

## Config files
Copy `.config` files to `~`

### Tools
- Homebrew
- Ghostty
- tmux + tmux plugin manager (press <leader> once installed)
- neovim (don't use brew mirror, it's old)
- starship (prompt)
- a nerd font
- Karabiner (to remap keys)
- Rectangle - import via Rectangle > Settings > Import

## Ghostty recovery on macOS

Run `./setup-ghostty-recovery.sh` to install the bundled recovery command and a
LaunchAgent that captures the layout and exact conversation IDs every 15 seconds
and at login. The macOS setup script also runs this when Ghostty and Node.js are
available. Setup is idempotent and requires Ghostty 1.4+ and Node.js 18+.

In a new shell:

```sh
ghostty-save                      # immediate checkpoint before a planned shutdown
ghostty-restore                   # reopen missing conversations after restarting
ghostty-resurrect status          # check backup age and any errors
```

The restore alias expands to `ghostty-resurrect restore --missing`, which avoids
duplicating conversations that are already running. A new Ghostty shell displays
a reminder when recovery is pending. Recovery is started explicitly; automatic
backups start at login. If macOS requests Automation access to Ghostty, allow it
for this recovery workflow and check `ghostty-resurrect status` afterwards.

The patched dependency is vendored in
[`vendor/ghostty-resurrect`](vendor/ghostty-resurrect/README.md), including its MIT
licence and tests, so another machine receives the tested implementation without
depending on an uncommitted neighbouring checkout or the unfixed npm release.
The shared symlink helper installs `~/.local/bin/ghostty-resurrect`. The launch
template is [`launchagents/local.ghostty-resurrect.plist`](launchagents/local.ghostty-resurrect.plist).

Only the current checkpoint and small current status files are maintained in
`~/.config/ghostty-resurrect/`; these stay local and are not committed. Partial or
uncertain captures preserve the previous checkpoint. A new boot or Ghostty
instance cannot replace unrecovered conversations. Explicitly run `ghostty-save`
to accept a deliberately fresh layout instead. Intentional pane closures settle
for 60 seconds before automatic replacement.

Ghostty's native window restoration is disabled to avoid duplicate empty windows.
The recovery command restores conversations and directories, not running commands
or process memory; local jobs stop at shutdown. Split geometry is approximate.
A newly opened session can be newer than the last periodic capture, so take an
explicit checkpoint before a planned shutdown. See the bundled README for the
full behaviour and validation boundaries.

To stop scheduling backups, run
`launchctl bootout gui/$(id -u)/local.ghostty-resurrect` and remove
`~/Library/LaunchAgents/local.ghostty-resurrect.plist`. Restore
`window-save-state = always` in the Ghostty config if returning to native layout
restoration. Existing local snapshots are left available.

## AI tooling (Claude Code, OpenAI Codex)

Both Claude Code and Codex CLI are configured via an Obsidian vault at `~/src/obsidian/projects/agents/`. The setup scripts symlink the vault contents into `~/.claude/`, `~/.codex/`, and `~/.agents/` so all AI config (instructions, settings, skills, per-project memory) lives in one private location instead of being committed to this repo.

The macOS and Debian setup scripts also offer to install zvec-grep (`zg`) globally via npm, requiring Node.js 22 or newer, and configure its Codex and Claude Code integrations after the agent configuration is linked. Their Git global excludes setup includes `.zvec-grep/` to keep local search indexes out of commits.

All three scripts can register Todoist's hosted MCP server (`https://ai.todoist.net/mcp`) with Claude Code at user scope: macOS and Debian prompt for it, Windows does it whenever the `claude` CLI is present. The registration lives in `~/.claude.json` and the OAuth grant is stored locally, neither of which syncs between machines, so after setup run `/mcp` inside Claude Code once per machine to sign in.

The macOS script can install [MCP Agent Mail](https://github.com/Dicklesworthstone/mcp_agent_mail_rust), a local coordination server for coding agents, on `127.0.0.1:8765`. It downloads a pinned release and verifies its minisign-signed checksums itself rather than running the upstream installer, which fails on macOS and rewrites every agent config it finds. Each machine gets its own bearer token in `~/.config/mcp-agent-mail/environment.sh` (mode `0600`, generated from [`agent-mail/environment.sh.in`](agent-mail/environment.sh.in)). The `com.agent-mail` LaunchAgent and [`agent-mail/http-headers.sh`](agent-mail/http-headers.sh) read the token from that file, so neither this repo nor the vault holds it: Claude Code is registered with the helper as its `headersHelper`, and the vault-shared Codex config points `http_headers_helper` at the same script through `$HOME`. Each machine runs a separate mailbox.

### Bootstrap on a new machine

```
./setup-macos.sh /path/to/existing/obsidian/vault   # or ./setup-debian.sh
```

On Windows, run the dedicated agent configuration script after syncing the vault:

```powershell
.\setup-claude-code.ps1 "C:\path\to\obsidian\vault"
```

The scripts are idempotent — re-run any time to refresh symlinks.

### Vault layout

```
agents/
├── AGENTS.md             ← global instructions (linked to ~/.claude/CLAUDE.md and ~/.codex/AGENTS.md)
├── settings.json         ← Claude Code settings (linked to ~/.claude/settings.json)
├── codex-config.toml     ← Codex CLI config (linked to ~/.codex/config.toml)
├── plugins.txt           ← Claude Code plugin manifest (read by setup script on install)
├── bin/                  ← shared helper scripts (linked to ~/.agents/bin)
│   └── agent-notify
├── skills/               ← linked to ~/.claude/skills and ~/.agents/skills
│   ├── vault-claude-memory/
│   ├── clean-worktree/
│   └── ... (one dir per skill, each with SKILL.md)
└── <project>/            ← per-project state for Claude Code
    └── memory/           ← memory dir (linked to ~/.claude/projects/<key>/memory/)
```

### How the symlinks are wired

The setup scripts handle two layers of linking:

1. **Global config.** Claude configuration is linked into `~/.claude/`, Codex configuration into `~/.codex/`, shared helper scripts into `~/.agents/bin`, and the shared skill catalogue into both `~/.claude/skills` and the cross-agent `~/.agents/skills` location.
2. **Per-project memory.** A loop walks every immediate subdirectory of `agents/` and, for any subdir that contains a `memory/` child, creates a symlink to it under `~/.claude/projects/<key>/memory`. The `<key>` defaults to `-Users-<user>-src-<project>` (matching a git repo at `~/src/<project>/`), but if the vault subdir contains a `.project-root` file, its content is read as the actual project root and the key is derived from that — used for non-git projects like Drive folders. The path may be written `~`-relative or with `$HOME`; both are expanded before the key is derived, and a plain absolute path still works.

Per-project instructions are not vaulted. They live as a committed `AGENTS.md` at the repo root, alongside the code they describe, for every agent to read.

The loop skips `skills/` and dotdirs, and skips `src/` unless it carries a `.project-root` (otherwise the convention would resolve it to `~/src/src`). Adding a new vaulted project = create `agents/<newproject>/memory/` and re-run setup. No script edits required.

### Shared skill compatibility

- Keep shared `SKILL.md` frontmatter agent-neutral: use only `name` and `description`.
- Put Claude-only invocation visibility in `agents/settings.json` under `skillOverrides`.
- Put Codex-only invocation policy in each skill's `agents/openai.yaml`.
- Claude's `/skills` menu writes project-local overrides. Those higher-precedence settings can intentionally make one project's behaviour differ from the synced global default.

### Adding a new project

**Manual:** create the directory structure and re-run setup.

```bash
mkdir -p ~/src/obsidian/projects/agents/<repo>/memory
./setup-macos.sh /path/to/existing/obsidian/vault
```

**Skill:** use `vault-claude-memory` from inside the repo.

```bash
cd ~/src/<repo>
claude
# In the session: "/vault-claude-memory" or "vault this repo's memory"
```

The skill handles six cases automatically: already-vaulted no-op, fresh init, adopt existing vault content, migrate existing local memory, refuse on conflicting symlink, refuse on collision. See `agents/skills/vault-claude-memory/SKILL.md` for the decision table.

### Project naming convention

**Git repos under `~/src/`:** the vault subdir name MUST match the repo basename. The auto-discovery loop computes `~/.claude/projects/-Users-<user>-src-<name>/` as the destination key by convention. No extra files needed.

**Non-git projects (e.g. Drive folders):** the vault subdir name is the cwd basename. The `vault-claude-memory` skill writes a `.project-root` file alongside `memory/` containing the actual project root, so the setup script can derive the correct destination key on a fresh machine. The skill records it `~`-relative, so one vault serves hosts with different usernames and cross-OS sync needs no manual edit.

### Per-project state: Claude vs Codex

- **Claude Code:** memory lives in the vault as `agents/<project>/memory/`, wired by symlink. Instructions come from the repo's own `AGENTS.md`.
- **Codex CLI:** nothing per-project lives in the vault. Codex per-project state lives inside the repo itself as `.codex/config.toml` and `AGENTS.md` at the repo root, walked by Codex from repo root → cwd. The vault only hosts Codex's *global* config (`AGENTS.md`, `codex-config.toml`).

This asymmetry exists because Codex auto-writes per-project trust entries into its global config, while Claude maintains a separate per-project memory directory that is worth syncing across machines. Per-repo instructions are the one thing both tools read from the same place: the repo root.

### Failure modes

**Renaming the vault root silently breaks everything.** Every symlink under `~/.claude/`, `~/.codex/`, and `~/.agents/` becomes a dead pointer. Active sessions keep working from cached state, masking the breakage until next session start. The setup scripts run a broken-symlink check at the top of the linking phase and warn loudly. Recovery: re-run setup. The scripts are idempotent and will replace stale symlinks.

**Vault not mounted at setup time.** If `~/src/obsidian/projects/agents/` doesn't exist when you run setup (iCloud not yet synced, Syncthing paused, external drive unmounted), the script skips the linking phase entirely. Re-run setup once the vault is available.

**Codex auto-writes can pollute vaulted config.** Codex CLI writes back to `~/.codex/config.toml` (symlinked to `agents/codex-config.toml`) when you `cd` into a new project — adding `[projects."<path>"] trust_level = "trusted"` entries. These appear in the vaulted file. That is by design and intended; the file accumulates entries over time. There is an open OpenAI issue (openai/codex#15433) asking for trust state to be separable from global config.

**Existing local Codex config is not a blocker.** If `~/.codex/config.toml` already exists as a regular file when setup runs, the setup scripts back it up to `~/.codex/config.toml.bak` and then link `agents/codex-config.toml` in its place. If Codex or a manual edit later replaces the symlink with a real file, copy any wanted changes into the vaulted config and rerun setup to restore the symlink.

### Cross-machine sync

- The vault itself is synced by Obsidian / your sync provider of choice.
- The setup scripts must be re-run on each new machine to create the symlinks. The vault content is the source; symlinks are per-machine wiring.
- If a project's `memory/` already exists in the vault (synced from another machine), the auto-discovery loop adopts it without modification.

### Related references

- Claude Code memory docs: <https://code.claude.com/docs/en/memory>
- Open feature request to make memory project-local: anthropics/claude-code#25947
- Open feature request for configurable memory layout: anthropics/claude-code#28276
- Open Codex issue on separating trust state: openai/codex#15433
