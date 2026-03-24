alias gs='git status -sb'
alias gl='git log --oneline --graph --decorate --all'
alias gd='git diff --word-diff'
alias gds='git diff --cached --word-diff'
alias ga='git add -A'
alias gc='git commit -m'
alias gca='git commit --amend --no-edit'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gpub='git push -u origin HEAD'
alias gsync='git pull --rebase --prune'
alias gp='git pull'
gundo() { git reset --soft HEAD~${1:-1}; }
gwip() { git add -A && git commit -m "WIP"; }
ghprc() { [[ -z "$1" ]] && echo "Usage: ghprc <target-branch>" && return 1; gh pr create --base "$1"; }
gbl() {
  local path="."
  for arg in "$@"; do
    [[ "$arg" == --rp=* ]] && path="${arg#--rp=}"
  done
  git -C "$path" branch -a
}
gclean() { git fetch -p && git branch -vv | grep ': gone]' | awk '{print $1}' | xargs git branch -d; }
gfetch() { [[ -z "$1" ]] && echo "Usage: gfetch <branch>" && return 1; git fetch origin "$1"; }
