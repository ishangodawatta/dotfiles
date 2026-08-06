# Aliases
alias c=clear
alias vim=nvim
alias ls=eza
alias cat=bat
alias srcvenv='source ./.venv/bin/activate'
alias srcenv='export $(command cat .env | xargs)'
alias claude='claude --chrome'

# Pyenv wrapper (auto-rehash after install/uninstall)
pyenv() {
  command pyenv "$@"
  if [[ "$1" == "install" || "$1" == "uninstall" ]]; then
    echo "Run 'source ~/.zprofile' or open a new shell to pick up changes."
    command pyenv rehash
  fi
}

# Bitwarden CLI helpers
bw-unlock() { export BW_SESSION=$(bw unlock --raw); }
secret() { bw get password "$1"; }

# fzf keybindings and completion (Ctrl+R = history, Ctrl+T = files)
source <(fzf --zsh)

# zoxide (use 'z' instead of 'cd', 'zi' for interactive)
eval "$(zoxide init zsh)"

# Starship prompt (must be last)
eval "$(starship init zsh)"
eval "$(/opt/homebrew/bin/brew shellenv)"

# bun completions
[ -s "/Users/ishangodawatta/.bun/_bun" ] && source "/Users/ishangodawatta/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# pyenv configuration
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"

# Android SDK
export ANDROID_HOME="$HOME/src/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

# - added by install_latest_codex.sh -
_codex_arch="$(uname -m)"
case "$_codex_arch" in
  x86_64) _codex_arch="x86_64" ;;
  aarch64|arm64) _codex_arch="aarch64" ;;
  *) _codex_arch="" ;;
esac
if [ -n "$_codex_arch" ]; then
  if [ -d "$HOME/.local/bin/$_codex_arch" ]; then
    export PATH="$HOME/.local/bin/$_codex_arch:$PATH"
  fi
fi
unset _codex_arch
