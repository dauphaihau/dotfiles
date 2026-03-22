#!/usr/bin/env bash
set -e

DOTFILES_DIR="/Volumes/Local/dev/pj-personal/dotfiles"

if ! git -C "$DOTFILES_DIR" status --porcelain | grep -q .; then
  exit 0
fi

git -C "$DOTFILES_DIR" add -u
git -C "$DOTFILES_DIR" commit -m "auto backup: $(date '+%Y-%m-%d %H:%M:%S')"
git -C "$DOTFILES_DIR" push
