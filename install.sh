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
  # Dotfiles
  stow

  # Shell
  zsh-autosuggestions
  zsh-syntax-highlighting

  # CLI replacements
  bat        # cat
  fd         # find
  zoxide     # cd
  ripgrep    # grep
  eza        # ls
  tree       # ls (tree view)
  sd         # sed
  xh         # curl
  tlrc       # man
  duf        # df
  doggo      # dig
  procs      # ps
  gping      # ping
  trash      # rm
  coreutils
  yq         # yaml/json processor
  jd         # json diff
  btop       # top

  # Dev tools
  git
  gh
  node
  nvm
  lua
  tree-sitter
  starship
  go
  python
  php
  mkcert
  just
  hurl

  # Formatters & linters
  stylua
  swiftformat

  # Infrastructure
  colima
  mc             # minio client

  # Xcode
  xcode-build-server
  worktrunk

  # File watching
  fswatch

  # TUI
  fzf
  neovim
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
  # Editors & terminals
  cursor
  zed
  warp
  neovim
  jetbrains-toolbox

  # Browsers
  google-chrome@dev
  firefox@developer-edition
  safari-technology-preview
  sigmaos

  # AI
  chatgpt
  claude

  # Productivity
  raycast
  espanso
  numi
  contexts
  hammerspoon

  # macOS enhancements
  bartender
  hiddenbar
  alcove
  clop
  cleanmymac

  # Dev tools
  tableplus
  devutils
  cloudflare-warp

  # Utilities
  betterzip
  cleanshot
  imazing
  karabiner-elements

  # Communication
  discord

  # Fonts
  font-hack-nerd-font
  font-jetbrains-mono-nerd-font
  font-sf-pro
)

echo "Installing casks..."
for cask in "${CASKS[@]}"; do
  if brew list --cask "$cask" &>/dev/null; then
    echo "  $cask already installed — skipping."
  else
    brew install --cask "$cask"
  fi
done

# ── Mac App Store ─────────────────────────────────────────────────────────────
if ! command -v mas &>/dev/null; then
  brew install mas
fi

MAS_APPS=(
  1596283165  # rcmd
  6446206067  # Klack
   497799835  # Xcode
   775737590  # iA Writer
)

echo "Installing Mac App Store apps..."
for app_id in "${MAS_APPS[@]}"; do
  if mas list | grep -q "^$app_id"; then
    echo "  $app_id already installed — skipping."
  else
    mas install "$app_id"
  fi
done

# ── Go packages ───────────────────────────────────────────────────────────────
GO_PACKAGES=(
  github.com/neur0map/glazepkg@latest
)

echo "Installing Go packages..."
for pkg in "${GO_PACKAGES[@]}"; do
  go install "$pkg"
done

# ── Stow dotfiles ─────────────────────────────────────────────────────────────
echo "Stowing dotfiles..."
PACKAGES=(zsh vim karabiner zed nvim claude warp hammerspoon)
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
