# Pyenv wrapper (auto-rehash after install/uninstall)
pyenv() {
  command pyenv "$@"
  if [[ "$1" == "install" || "$1" == "uninstall" ]]; then
    echo "Run 'source ~/.zprofile' or open a new shell to pick up changes."
    command pyenv rehash
  fi
}

# fzf keybindings and completion (Ctrl+R = history, Ctrl+T = files)
source <(fzf --zsh)

# zoxide (use 'z' instead of 'cd', 'zi' for interactive)
eval "$(zoxide init zsh)"

# Starship prompt (must be last)
eval "$(starship init zsh)"
