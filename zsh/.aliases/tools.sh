alias rl='source ~/.zshrc'


alias reapply-icons='sudo bash /Volumes/Local/dev/pj-personal/dotfiles/scripts/reapply-icons.sh'

alias c='claude'
alias cs='cursor'
alias z='zed'
alias j='just'

alias claude-mem='bun "/Users/dauphaihau/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'

# zoxide → replace cd
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh --cmd g)"
  alias cd='g'
fi

# nushell → run once and return
if command -v nu &>/dev/null; then
  alias n='nu -c'

  # Use nu for specific commands
  alias nla='nu -c "ls -al | select name type size modified created | sort-by name"'
  alias nls='nu -c "ls -l | select name type size modified created | sort-by size"'
  alias nlsd='nu -c "ls -l | select name type size modified created | sort-by size --reverse"'
  alias nln='nu -c "ls -l | select name type size modified created | sort-by name"'
  alias nlt='nu -c "ls -l | select name type size modified created | sort-by type"'
  alias nlf='nu -c "ls -l | select name type size modified created | where type == file | sort-by size --reverse"' # just files
  alias nld='nu -c "ls -l | select name type size modified created | where type == dir"' # just dirs
fi

# eza → replace ls
if command -v eza &>/dev/null; then
  alias ll='eza -lh --icons --git'
  alias la='eza -lah --icons --git'

  # Sorting
  alias lls='eza -lh --icons --git --sort=size'
  alias llm='eza -lh --icons --git --sort=modified'
  alias llnew='eza -lh --icons --git --sort=modified -r'

  # Filtering
  alias lf='eza -lh --icons --git --only-files'
  alias ld='eza -lh --icons --git --only-dirs'

  # Tree with depth control
  alias lt='eza --tree --icons -L 1'
  alias lt2='eza --tree --icons -L 2'
  alias lt3='eza --tree --icons -L 3'
  alias lt2i='eza --tree --icons -L 2 --git-ignore'
  alias lt3i='eza --tree --icons -L 3 --git-ignore'
  alias ltg='eza --tree --icons --git-ignore'

else
  alias ll='ls -lAh --color=auto'
  alias lt='ls -lAht --color=auto'
fi

# bat → replace cat
if command -v bat &>/dev/null; then
  if [[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" == "Dark" ]]; then
    alias cat='bat --paging=never --theme="ansi"'
  else
    alias cat='bat --paging=never --theme="Catppuccin Latte"'
  fi
fi

# ripgrep → replace grep
if command -v rg &>/dev/null; then
  alias grep='rg'
fi

# fd → replace find
if command -v fd &>/dev/null; then
  alias find='fd'
fi

# # xh → replace curl
# if command -v xh &>/dev/null; then
#   alias curl='xh'
# fi

# gping → replace ping
if command -v gping &>/dev/null; then
  alias ping='gping'
fi

# tlrc → replace man
if command -v tlrc &>/dev/null; then
  alias man='tlrc'
fi

# sd → replace sed
if command -v sd &>/dev/null; then
  alias sed='sd'
fi

# trash → replace rm (moves to macOS Trash, recoverable)
if [[ -x "/opt/homebrew/opt/trash/bin/trash" ]]; then
  export PATH="/opt/homebrew/opt/trash/bin:$PATH"
  alias rm='trash'
  alias d='trash'
fi

# open
alias o='open .'
alias of='open'

# duf → replace df
if command -v duf &>/dev/null; then
  alias df='duf'
fi

# doggo → replace dig
if command -v doggo &>/dev/null; then
  alias dig='doggo'
fi

# procs → replace ps
if command -v procs &>/dev/null; then
  alias ps='procs'
fi

# hyperfine → replace time
if command -v hyperfine &>/dev/null; then
  alias time='hyperfine'
fi
