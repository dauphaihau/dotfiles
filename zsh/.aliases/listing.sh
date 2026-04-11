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

# nushell → run once and return
if command -v nu &>/dev/null; then
  alias nla='nu -c "ls -al | select name type size modified created | sort-by name"'
  alias nls='nu -c "ls -l | select name type size modified created | sort-by size"'
  alias nlsd='nu -c "ls -l | select name type size modified created | sort-by size --reverse"'
  alias nln='nu -c "ls -l | select name type size modified created | sort-by name"'
  alias nlt='nu -c "ls -l | select name type size modified created | sort-by type"'
  alias nlf='nu -c "ls -l | select name type size modified created | where type == file | sort-by size --reverse"' # just files
  alias nld='nu -c "ls -l | select name type size modified created | where type == dir"' # just dirs
fi

# bat → replace cat
if command -v bat &>/dev/null; then
  if [[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" == "Dark" ]]; then
    alias cat='bat --paging=never --theme="ansi"'
  else
    alias cat='bat --paging=never --theme="Catppuccin Latte"'
  fi
fi
