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

## AI tooling (Claude Code, OpenAI Codex)

Both Claude Code and Codex CLI are configured via an Obsidian vault at `~/src/obsidian/projects/agents/`. The setup scripts symlink the vault contents into `~/.claude/` and `~/.codex/` so all AI config (instructions, settings, skills, per-project memory) lives in one private location instead of being committed to this repo.

### Bootstrap on a new machine

```
./setup-macos.sh /path/to/obsidian/vault   # or ./setup-debian.sh
```

The scripts are idempotent — re-run any time to refresh symlinks.

### Vault layout

```
agents/
├── AGENTS.md             ← global instructions (linked to ~/.claude/CLAUDE.md and ~/.codex/AGENTS.md)
├── settings.json         ← Claude Code settings (linked to ~/.claude/settings.json)
├── codex-config.toml     ← Codex CLI config (linked to ~/.codex/config.toml)
├── plugins.txt           ← Claude Code plugin manifest (read by setup script on install)
├── skills/               ← shared skills, used by both Claude and Codex
│   ├── vault-claude-memory/
│   ├── clean-worktree/
│   └── ... (one dir per skill, each with SKILL.md)
└── <project>/            ← per-project state for Claude Code
    ├── memory/           ← memory dir (linked to ~/.claude/projects/<key>/memory/)
    └── AGENTS.md         ← optional: project-scoped instructions (linked to ~/.claude/projects/<key>/CLAUDE.md)
```

### How the symlinks are wired

The setup scripts handle three layers of linking:

1. **Global config.** `AGENTS.md`, `settings.json`, `codex-config.toml`, `skills/` are linked once into `~/.claude/` and `~/.codex/`.
2. **Per-project memory.** A loop walks every immediate subdirectory of `agents/` and, for any subdir that contains a `memory/` child, creates a symlink to it under `~/.claude/projects/<key>/memory`. The `<key>` defaults to `-Users-<user>-src-<project>` (matching a git repo at `~/src/<project>/`), but if the vault subdir contains a `.project-root` file, its content is read as the actual absolute project path and the key is derived from that — used for non-git projects like Drive folders.
3. **Per-project instructions.** The same loop links `agents/<project>/AGENTS.md` → `~/.claude/projects/-Users-<user>-src-<project>/CLAUDE.md` if the file exists. Optional per-project.

The loop skips `skills/`, `src/`, and dotdirs. Adding a new vaulted project = create `agents/<newproject>/memory/` and re-run setup. No script edits required.

### Adding a new project

**Manual:** create the directory structure and re-run setup.

```bash
mkdir -p ~/src/obsidian/projects/agents/<repo>/memory
./setup-macos.sh /path/to/obsidian/vault
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

**Non-git projects (e.g. Drive folders):** the vault subdir name is the cwd basename. The `vault-claude-memory` skill writes a `.project-root` file alongside `memory/` containing the actual absolute project path, so the setup script can derive the correct destination key on a fresh machine. Caveat: `.project-root` is a literal absolute path, so cross-OS sync (macOS → Linux) requires manually editing the file.

### Per-project state: Claude vs Codex

- **Claude Code:** lives in the vault as `agents/<project>/memory/` and (optionally) `agents/<project>/AGENTS.md`. Wired by symlink.
- **Codex CLI:** does NOT live in the vault. Codex per-project state lives inside the repo itself as `.codex/config.toml` and `AGENTS.md` at the repo root, walked by Codex from repo root → cwd. The vault only hosts Codex's *global* config (`AGENTS.md`, `codex-config.toml`).

This asymmetry exists because Codex auto-writes per-project trust entries into its global config and walks the repo for instructions, while Claude maintains a separate per-project memory directory. Both designs are accommodated.

### Failure modes

**Renaming the vault root silently breaks everything.** Every symlink under `~/.claude/` and `~/.codex/` becomes a dead pointer. Active sessions keep working from cached state, masking the breakage until next session start. The setup scripts run a broken-symlink check at the top of the linking phase and warn loudly. Recovery: re-run setup. The scripts are idempotent and will replace stale symlinks.

**Vault not mounted at setup time.** If `~/src/obsidian/projects/agents/` doesn't exist when you run setup (iCloud not yet synced, Syncthing paused, external drive unmounted), the script skips the linking phase entirely. Re-run setup once the vault is available.

**Codex auto-writes can pollute vaulted config.** Codex CLI writes back to `~/.codex/config.toml` (symlinked to `agents/codex-config.toml`) when you `cd` into a new project — adding `[projects."<path>"] trust_level = "trusted"` entries. These appear in the vaulted file. That is by design and intended; the file accumulates entries over time. There is an open OpenAI issue (openai/codex#15433) asking for trust state to be separable from global config.

### Cross-machine sync

- The vault itself is synced by Obsidian / your sync provider of choice.
- The setup scripts must be re-run on each new machine to create the symlinks. The vault content is the source; symlinks are per-machine wiring.
- If a project's `memory/` already exists in the vault (synced from another machine), the auto-discovery loop adopts it without modification.

### Related references

- Claude Code memory docs: <https://code.claude.com/docs/en/memory>
- Open feature request to make memory project-local: anthropics/claude-code#25947
- Open feature request for configurable memory layout: anthropics/claude-code#28276
- Open Codex issue on separating trust state: openai/codex#15433

