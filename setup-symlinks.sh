#!/bin/bash
# Symlink wiring for dotfiles and agent config.
#
# Two ways to use it:
#   ./setup-symlinks.sh          run standalone to (re)create every symlink
#   source setup-symlinks.sh     from setup-macos.sh / setup-debian.sh
#
# Both setup scripts previously carried byte-identical copies of the
# agent-config block, which is how the 'src' skip drifted out of sync with the
# .project-root override. This is the single copy.
#
# When sourced, the caller supplies SCRIPT_DIR, SHELL_FILES and CONFIG_DIRS.
# link_file()/link_dir() are defined here for both modes; the one platform
# difference (BSD realpath has no -m flag) is handled by _same_path.
# Platform-only links (karabiner on macOS) stay in their own script.

# realpath -m normalises .. and symlinks, but BSD realpath has no -m flag, so
# fall back to a plain string compare on macOS.
_same_path() {
  if realpath -m / >/dev/null 2>&1; then
    [[ "$(realpath -m "$1")" == "$(realpath -m "$2")" ]]
  else
    [[ "${1%/}" == "${2%/}" ]]
  fi
}

link_file() {
  local src="$1" dest="$2"
  if [[ ! -f "$src" ]]; then
    echo "  skip $(basename "$dest") (not found in dotfiles)"
    return
  fi
  if _same_path "$src" "$dest"; then
    echo "  ok $dest (already in place)"
    return
  fi
  if [[ -L "$dest" ]]; then
    rm "$dest"
  elif [[ -f "$dest" ]]; then
    mv "$dest" "$dest.bak"
    echo "  backup $dest -> $dest.bak"
  fi
  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  echo "  link $dest"
}

link_dir() {
  local src="$1" dest="$2"
  if [[ ! -d "$src" ]]; then
    echo "  skip $(basename "$dest") (not found in dotfiles)"
    return
  fi
  # Source and destination the same path (e.g. vault cloned directly to
  # ~/src/obsidian). Linking would move the source aside and leave a
  # self-referential symlink, breaking every dependent link.
  if _same_path "$src" "$dest"; then
    echo "  ok $dest (already in place)"
    return
  fi
  if [[ -L "$dest" ]]; then
    rm "$dest"
  elif [[ -d "$dest" ]]; then
    mv "$dest" "$dest.bak"
    echo "  backup $dest -> $dest.bak"
  fi
  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  echo "  link $dest"
}

# Raycast's real config (hotkeys, aliases, quicklinks, snippets, extension
# preferences) lives in SQLite databases under Library/Application Support and
# was never tracked here; only the script-commands dir ever was, and that is
# gone too. Drop the link earlier runs created so it does not dangle.
remove_legacy_raycast_scripts_link() {
  local legacy="$HOME/.config/raycast/scripts"
  local expected="$SCRIPT_DIR/.config/raycast/scripts"
  if [[ -L "$legacy" && "$(readlink "$legacy")" == "$expected" ]]; then
    rm "$legacy"
    echo "  remove legacy $legacy"
  fi
}

link_shell_files() {
  for f in "${SHELL_FILES[@]}"; do
    link_file "$SCRIPT_DIR/$f" "$HOME/$f"
  done
}

link_config_dirs() {
  mkdir -p "$HOME/.config"
  for d in "${CONFIG_DIRS[@]}"; do
    link_dir "$SCRIPT_DIR/.config/$d" "$HOME/.config/$d"
  done
  if [[ -f "$SCRIPT_DIR/.config/starship.toml" ]]; then
    link_file "$SCRIPT_DIR/.config/starship.toml" "$HOME/.config/starship.toml"
  fi
}

link_agent_config() {
  # Claude Code config (all content lives in vault)
  mkdir -p "$HOME/.claude"
  link_file "$HOME/src/obsidian/projects/agents/AGENTS.md" "$HOME/.claude/CLAUDE.md"
  link_file "$HOME/src/obsidian/projects/agents/settings.json" "$HOME/.claude/settings.json"
  link_dir "$HOME/src/obsidian/projects/agents/skills" "$HOME/.claude/skills"
  
  # Claude Code project memory + project-scoped instructions (auto-discovered from vault).
  # Default convention: vault project name matches a git repo at ~/src/<project>.
  # Override: if the vault project dir contains a .project-root file, its content is treated
  # as the actual absolute project root path (used for non-git projects like Drive folders).
  # The skill `vault-claude-memory` writes .project-root automatically when vaulting non-git projects.
  for project_path in "$HOME/src/obsidian/projects/agents"/*/; do
    project=$(basename "$project_path")
    project_path="${project_path%/}"  # strip trailing slash from glob
    # Skip non-project subdirs (skills, hidden)
    [[ "$project" == "skills" || "$project" == .* ]] && continue
    # Only treat as a project if it has a memory/ dir
    [[ -d "$project_path/memory" ]] || continue
    # 'src' collides with the ~/src/<project> convention below, which would resolve
    # it to ~/src/src. Honour it only when .project-root states the real path.
    [[ "$project" == "src" && ! -f "$project_path/.project-root" ]] && continue
    if [[ -f "$project_path/.project-root" ]]; then
      actual_project_root=$(cat "$project_path/.project-root")
      # Stored ~-relative so one vault serves hosts with different usernames.
      # Expand before deriving the key: a tilde read from a file is not expanded by the shell.
      actual_project_root="${actual_project_root/#\~/$HOME}"
      actual_project_root="${actual_project_root//\$HOME/$HOME}"
      claude_key=$(echo "$actual_project_root" | sed 's/[^a-zA-Z0-9-]/-/g')
      claude_project_dir="$HOME/.claude/projects/$claude_key"
    else
      # Derived from $HOME rather than a hardcoded /Users or /home prefix,
      # so one copy serves macOS and Linux.
      claude_project_dir="$HOME/.claude/projects/$(echo "$HOME/src/${project}" | sed 's/[^a-zA-Z0-9-]/-/g')"
    fi
    mkdir -p "$claude_project_dir"
    link_dir "$project_path/memory" "$claude_project_dir/memory"
    # Optional project-scoped instructions
    if [[ -f "$project_path/AGENTS.md" ]]; then
      link_file "$project_path/AGENTS.md" "$claude_project_dir/CLAUDE.md"
    fi
  done
  
  # OpenAI Codex config, shared helpers, and cross-agent skills.
  mkdir -p "$HOME/.codex" "$HOME/.agents"
  link_file "$HOME/src/obsidian/projects/agents/codex-config.toml" "$HOME/.codex/config.toml"
  link_file "$HOME/src/obsidian/projects/agents/AGENTS.md" "$HOME/.codex/AGENTS.md"
  link_dir "$HOME/src/obsidian/projects/agents/bin" "$HOME/.agents/bin"
  link_dir "$HOME/src/obsidian/projects/agents/skills" "$HOME/.agents/skills"
}

# ---------------------------------------------------------------------------
# Standalone mode: only runs when executed directly, not when sourced.
# ---------------------------------------------------------------------------

_symlinks_standalone_defaults() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  remove_legacy_codex_skills_link() { :; }

  case "$(uname -s)" in
    Darwin)
      SHELL_FILES=(.zprofile .zshrc .tmux.conf)
      CONFIG_DIRS=(ghostty nvim btop htop aerospace)
      ;;
    *)
      SHELL_FILES=(.bashrc .zprofile .zshrc .tmux.conf)
      CONFIG_DIRS=(ghostty nvim btop htop)
      ;;
  esac
}

_symlinks_standalone_main() {
  _symlinks_standalone_defaults
  echo "Linking dotfiles from $SCRIPT_DIR"
  link_shell_files
  link_config_dirs
  if [[ "$(uname -s)" == Darwin ]]; then
    mkdir -p "$HOME/.config/karabiner"
    link_file "$SCRIPT_DIR/.config/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
    remove_legacy_raycast_scripts_link
  fi
  if [[ -d "$HOME/src/obsidian/projects/agents" ]]; then
    echo "Linking agent config from the vault"
    link_agent_config
  else
    echo "Skipping agent config -- ~/src/obsidian/projects/agents not found."
    echo "  Run the full setup script first to link the vault."
  fi
  echo "Done."
}

# BASH_SOURCE equals $0 only when executed directly.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -e
  _symlinks_standalone_main "$@"
fi
