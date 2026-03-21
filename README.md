# My dotfiles
This directory contains the dotfiles for my mac system which probably won't work on yours.

Managed with a **bare git repo** — no symlinks, no stow. Files live at their real `$HOME` paths.

## Install on a new machine

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/dauphaihau/dotfiles/main/install.sh)
```

This will:
1. Clone the bare repo into `~/dotfiles`
2. Check out all dotfiles into `$HOME` (existing files are backed up to `~/.dotfiles-backup/`)
3. Install Homebrew, formulae, and casks

## How it works

```
~/dotfiles/   ← bare git repo (git dir)
~/            ← working tree
```

The `dot` alias wraps git with the correct `--git-dir` and `--work-tree`:

```bash
alias dot='git --git-dir="$HOME/dotfiles" --work-tree="$HOME"'
```

## Daily usage

```bash
dot status
dot add ~/.zshrc
dot commit -m "update zshrc"
dot push
```
