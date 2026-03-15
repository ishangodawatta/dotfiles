#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# Files that get symlinked to $HOME
home_files=(
  .zprofile
  .zshrc
  .tmux.conf
)

# Directories that get symlinked to $HOME/.config/
config_dirs=(
  ghostty
  nvim
  btop
  htop
)

# Linux-only files
if [[ "$(uname -s)" == "Linux" ]]; then
  home_files+=(.bashrc)
fi

echo "Installing dotfiles from $DOTFILES_DIR"

# Symlink home files
for f in "${home_files[@]}"; do
  src="$DOTFILES_DIR/$f"
  dest="$HOME/$f"
  if [[ ! -f "$src" ]]; then
    echo "  skip $f (not found in dotfiles)"
    continue
  fi
  if [[ -L "$dest" ]]; then
    rm "$dest"
  elif [[ -f "$dest" ]]; then
    echo "  backup $dest -> $dest.bak"
    mv "$dest" "$dest.bak"
  fi
  ln -s "$src" "$dest"
  echo "  link $f"
done

# Symlink config dirs
mkdir -p "$HOME/.config"
for d in "${config_dirs[@]}"; do
  src="$DOTFILES_DIR/.config/$d"
  dest="$HOME/.config/$d"
  if [[ ! -d "$src" ]]; then
    echo "  skip .config/$d (not found in dotfiles)"
    continue
  fi
  if [[ -L "$dest" ]]; then
    rm "$dest"
  elif [[ -d "$dest" ]]; then
    echo "  backup $dest -> $dest.bak"
    mv "$dest" "$dest.bak"
  fi
  ln -s "$src" "$dest"
  echo "  link .config/$d"
done

# SSH config (merge-friendly -- don't clobber existing keys/config)
if [[ -f "$DOTFILES_DIR/.ssh/config" ]]; then
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  src="$DOTFILES_DIR/.ssh/config"
  dest="$HOME/.ssh/config"
  if [[ -L "$dest" ]]; then
    rm "$dest"
  elif [[ -f "$dest" ]]; then
    echo "  backup $dest -> $dest.bak"
    mv "$dest" "$dest.bak"
  fi
  ln -s "$src" "$dest"
  echo "  link .ssh/config"
fi

echo "Done."
