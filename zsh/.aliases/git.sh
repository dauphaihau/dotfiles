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
alias gb='git branch'
alias gba='git branch -a -vv'
alias gbr='git branch --sort=-committerdate --format="%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(color:red)%(objectname:short)%(color:reset) %(contents:subject) %(color:blue)(%(committerdate:relative)) %(color:green)%(authorname)%(color:reset)"'

gundo() { git reset --soft HEAD~${1:-1}; }
gwip() { git add -A && git commit -m "WIP"; }
ghprc() { [[ -z "$1" ]] && echo "Usage: ghprc <target-branch>" && return 1; gh pr create --base "$1"; }
gclean() { git fetch -p && git branch -vv | grep ': gone]' | awk '{print $1}' | xargs git branch -d; }
gfetch() { [[ -z "$1" ]] && echo "Usage: gfetch <branch>" && return 1; git fetch origin "$1"; }

gpull() { [[ -z "$1" ]] && echo "Usage: gpull <branch>" && return 1; git fetch origin "$1:$1"; }
gpush() { [[ -z "$1" ]] && echo "Usage: gpush <branch>" && return 1; git push origin "$1"; }
gdb() { [[ -z "$1" ]] && echo "Usage: gdb <branch>" && return 1; git diff "$1"..HEAD --word-diff; }
glb() { [[ -z "$1" ]] && echo "Usage: glb <branch>" && return 1; git log --oneline --graph --decorate "$1"; }
gmb() { [[ -z "$1" ]] && echo "Usage: gmb <branch>" && return 1; git merge "$1" --no-ff; }
grb() { [[ -z "$1" ]] && echo "Usage: grb <branch>" && return 1; git rebase "$1"; }
