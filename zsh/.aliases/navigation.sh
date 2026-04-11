# zoxide → replace cd
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh --cmd g)"
  alias cd='g'
fi

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias home='cd ~'
alias root='cd /'
