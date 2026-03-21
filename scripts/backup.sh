#!/usr/bin/env bash
set -e

dot() {
  git --git-dir="$HOME/dotfiles" --work-tree="$HOME" "$@"
}

if ! dot status --porcelain | grep -q .; then
  exit 0
fi

dot add -u
dot commit -m "auto backup: $(date '+%Y-%m-%d %H:%M:%S')"
dot push
