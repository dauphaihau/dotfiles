#!/usr/bin/env bash
set -e

REPO_URL="https://github.com/dauphaihau/dotfiles.git"
BARE_DIR="$HOME/dotfiles"

# ── Dotfiles ──────────────────────────────────────────────────────────────────
if [ -d "$BARE_DIR" ]; then
  echo "Bare repo already exists at $BARE_DIR — skipping clone."
else
  git clone --bare "$REPO_URL" "$BARE_DIR"
fi

dot() {
  git --git-dir="$BARE_DIR" --work-tree="$HOME" "$@"
}

dot config --local status.showUntrackedFiles no

if ! dot checkout 2>/dev/null; then
  echo "Backing up pre-existing dotfiles to ~/.dotfiles-backup/"
  mkdir -p "$HOME/.dotfiles-backup"
  dot checkout 2>&1 \
    | grep "^\s" \
    | awk '{print $1}' \
    | xargs -I{} sh -c 'mkdir -p "$HOME/.dotfiles-backup/$(dirname "{}")" && mv "$HOME/{}" "$HOME/.dotfiles-backup/{}"'
  dot checkout
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

# ── Backup job (launchd) ──────────────────────────────────────────────────────
PLIST_SRC="$HOME/dotfiles/scripts/com.dauphaihau.dotfiles-backup.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.dauphaihau.dotfiles-backup.plist"
BACKUP_SCRIPT="$HOME/dotfiles/scripts/backup.sh"

chmod +x "$BACKUP_SCRIPT"
sed "s|DOTFILES_SCRIPTS_PATH|$BACKUP_SCRIPT|g" "$PLIST_SRC" > "$PLIST_DST"
launchctl load "$PLIST_DST"
echo "Backup job registered — runs every hour."

echo "Done. Add this to your shell profile:"
echo "  alias dot='git --git-dir=\"\$HOME/dotfiles\" --work-tree=\"\$HOME\"'"
