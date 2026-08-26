# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# uv / rye
. "$HOME/.local/bin/env"

# Pyenv (fast path -- no eval, just shims)
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/shims:$PATH"

# NVM (node/npm always in PATH, nvm command lazy-loaded)
export NVM_DIR="$HOME/.nvm"
# Resolve the newest installed version rather than pinning one -- the pinned
# path goes stale on upgrade and silently drops node from PATH.
_nvm_node_bin=$(command ls -d "$NVM_DIR"/versions/node/*/bin 2>/dev/null | sort -V | tail -1)
[[ -n "$_nvm_node_bin" ]] && export PATH="$_nvm_node_bin:$PATH"
unset _nvm_node_bin
nvm() {
  unfunction nvm 2>/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  nvm "$@"
}

# Extra PATH entries
export PATH="$HOME/src:$PATH"
export PATH="/opt/homebrew/opt/mysql@8.4/bin:$PATH"
case "$(uname -s),$(uname -m)" in
  Linux,x86_64)  _arch_bin="$HOME/.local/bin/x86_64" ;;
  Linux,aarch64) _arch_bin="$HOME/.local/bin/aarch64" ;;
  Darwin,x86_64) _arch_bin="$HOME/.local/bin/x86_64" ;;
  Darwin,arm64)  _arch_bin="$HOME/.local/bin/aarch64" ;;
  *)             _arch_bin="" ;;
esac
# Only prepend when it exists -- absent on machines without codex installed
[[ -n "$_arch_bin" && -d "$_arch_bin" ]] && export PATH="$_arch_bin:$PATH"
unset _arch_bin

# API keys
[ -f "$HOME/src/.keys" ] && source "$HOME/src/.keys"
