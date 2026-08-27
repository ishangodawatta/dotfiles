#!/bin/bash
# Shared symlink wiring, sourced by setup-macos.sh and setup-debian.sh.
#
# Both scripts previously carried byte-identical copies of the agent-config
# block, which is how the 'src' skip drifted out of sync with .project-root.
#
# Callers must define link_file() and link_dir() before sourcing -- those stay
# per-script because the self-referential-symlink guard differs (BSD realpath
# has no -m flag) -- and set:
#   SCRIPT_DIR   dotfiles checkout root
#   SHELL_FILES  shell rc files to link into $HOME
#   CONFIG_DIRS  ~/.config subdirectories to link
#
# Platform-only links (karabiner and raycast on macOS) stay in their own script.

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
