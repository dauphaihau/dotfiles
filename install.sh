#!/usr/bin/env bash
set -e

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

echo "Done."
