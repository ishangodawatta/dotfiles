# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# uv / rye
. "$HOME/.local/bin/env"

# Pyenv (fast path -- no eval, just shims)
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/shims:$PATH"

# NVM (node/npm always in PATH, nvm command lazy-loaded)
export NVM_DIR="$HOME/.nvm"
export PATH="$NVM_DIR/versions/node/v24.10.0/bin:$PATH"
nvm() {
  unfunction nvm 2>/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  nvm "$@"
}

# Extra PATH entries
export PATH="$HOME/src:$PATH"
export PATH="/opt/homebrew/opt/mysql@8.4/bin:$PATH"
case "$(uname -s),$(uname -m)" in
  Linux,x86_64)  export PATH="$HOME/.local/bin/x86_64:$PATH" ;;
  Linux,aarch64) export PATH="$HOME/.local/bin/aarch64:$PATH" ;;
  Darwin,x86_64) export PATH="$HOME/.local/bin/x86_64:$PATH" ;;
  Darwin,arm64)  export PATH="$HOME/.local/bin/aarch64:$PATH" ;;
esac

# API keys
[ -f "$HOME/src/.keys" ] && source "$HOME/src/.keys"
