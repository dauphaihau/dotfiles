# My dotfiles
This directory contains the dotfiles for my mac system which probably won't work on yours.

Managed with **GNU Stow** — symlinks files from the repo to their real `$HOME` paths.

## Install on a new machine

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/dauphaihau/dotfiles/main/install.sh)
```

This will:
1. Clone the repo into `~/dotfiles`
2. Install Homebrew, formulae, and casks (including `stow`)
3. Stow all packages — creating symlinks in `$HOME`
4. Register the auto-backup launchd job

## Structure

```
dotfiles/
├── zsh/
│   └── .zshrc
├── bash/
│   └── .bashrc
├── vim/
│   └── .vimrc
├── aliases/
│   └── .aliases/
├── scripts/
│   ├── backup.sh
│   └── com.dauphaihau.dotfiles-backup.plist
└── install.sh
```

## Daily usage

```bash
cd ~/dotfiles
git add zsh/.zshrc
git commit -m "update zshrc"
git push
```

## Adding a new package

```bash
mkdir -p ~/dotfiles/tmux
cp ~/.tmux.conf ~/dotfiles/tmux/.tmux.conf
stow --target="$HOME" --dir=~/dotfiles tmux
```
