# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# uv / rye
. "$HOME/.local/bin/env"

# Pyenv (fast path -- no eval, just shims)
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
export PATH="$PYENV_ROOT/shims:$PATH"

# NVM (lazy-loaded for speed)
export NVM_DIR="$HOME/.nvm"
nvm() {
  unfunction nvm node npm npx 2>/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
  nvm "$@"
}
node() { nvm --silent; unfunction node 2>/dev/null; node "$@"; }
npm()  { nvm --silent; unfunction npm 2>/dev/null; npm "$@"; }
npx()  { nvm --silent; unfunction npx 2>/dev/null; npx "$@"; }

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
