alias rl='unalias -a && for f in ~/.aliases/*.sh; do [ -f "$f" ] && source "$f"; done && source ~/.exports && echo "reloaded"'

alias reapply-icons='sudo bash /Volumes/Local/dev/pj-personal/dotfiles/scripts/reapply-icons.sh'
