#!/usr/bin/env bash
set -e

REPO_URL="https://github.com/dauphaihau/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

# ── Dotfiles ──────────────────────────────────────────────────────────────────
if [ -d "$DOTFILES_DIR" ]; then
  echo "Dotfiles already exist at $DOTFILES_DIR — skipping clone."
else
  git clone "$REPO_URL" "$DOTFILES_DIR"
fi

# ── Homebrew ──────────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "Homebrew already installed — skipping."
fi

# ── Formulae ──────────────────────────────────────────────────────────────────
FORMULAE=(
  stow
  zsh-autosuggestions
  zsh-syntax-highlighting
  bat
  fd
  zoxide
  lua
  ripgrep
  neovim
  git
  gh
  tree
  tree-sitter
  node
  nvm
)

echo "Installing formulae..."
for pkg in "${FORMULAE[@]}"; do
  if brew list "$pkg" &>/dev/null; then
    echo "  $pkg already installed — skipping."
  else
    brew install "$pkg"
  fi
done

# ── Casks ─────────────────────────────────────────────────────────────────────
CASKS=(
  raycast
  karabiner-elements
)

echo "Installing casks..."
for cask in "${CASKS[@]}"; do
  if brew list --cask "$cask" &>/dev/null; then
    echo "  $cask already installed — skipping."
  else
    brew install --cask "$cask"
  fi
done

# ── Stow dotfiles ─────────────────────────────────────────────────────────────
echo "Stowing dotfiles..."
PACKAGES=(zsh vim karabiner zed nvim claude warp)
for pkg in "${PACKAGES[@]}"; do
  stow --target="$HOME" --dir="$DOTFILES_DIR" "$pkg"
  echo "  stowed $pkg"
done

# ── Backup job (launchd) ──────────────────────────────────────────────────────
PLIST_SRC="$DOTFILES_DIR/scripts/com.dauphaihau.dotfiles-backup.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.dauphaihau.dotfiles-backup.plist"
BACKUP_SCRIPT="$DOTFILES_DIR/scripts/backup.sh"

chmod +x "$BACKUP_SCRIPT"
/usr/bin/sed "s|DOTFILES_SCRIPTS_PATH|$BACKUP_SCRIPT|g" "$PLIST_SRC" > "$PLIST_DST"
launchctl bootstrap gui/$(id -u) "$PLIST_DST"
echo "Backup job registered — runs every hour."

echo "Done."
