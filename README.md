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

To bootstrap on a new machine, pass the vault path to the setup script:

```
./setup-macos.sh /path/to/obsidian/vault
```

The setup script auto-discovers per-project memory directories under `agents/<project>/memory/` and wires them into `~/.claude/projects/<key>/memory/` via symlinks. Adding a new vaulted project just means creating the directory in the vault and re-running setup — no script edits required. The `vault-claude-repo` skill (in the vault's `skills/` dir) automates this from inside any repo.

If you rename or move the vault root, re-run the setup script — it detects broken symlinks at the top of the linking phase and will warn you loudly so the breakage doesn't go unnoticed.

See the vault's own `README.md` for the full layout, conventions, failure modes, and design rationale.

