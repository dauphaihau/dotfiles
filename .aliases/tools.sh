alias reload='source ~/.zshrc'
alias dot='git --git-dir="$HOME/dotfiles" --work-tree="$HOME"'

alias c='claude'
alias cs='cursor'
alias z='zed'

alias claude-mem='bun "/Users/dauphaihau/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'

# zoxide → replace cd
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh --cmd g)"
  alias cd='g'
fi

# eza → replace ls
if command -v eza &>/dev/null; then
  alias ls='eza --icons'
  alias ll='eza -lh --icons --git'
  alias la='eza -lah --icons --git'
  alias lt='eza --tree --icons'
else
  alias ll='ls -lAh --color=auto'
  alias lt='ls -lAht --color=auto'
fi

# bat → replace cat
if command -v bat &>/dev/null; then
  alias cat='bat --paging=never'
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
