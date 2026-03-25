# Status / Log
alias gs='git status -sb'
alias gl='git log --oneline --graph --decorate --all'
alias gd='git diff --word-diff'
alias gds='git diff --cached --word-diff'
gdb() { [[ -z "$1" ]] && echo "Usage: gdb <branch>" && return 1; git diff "$1"..HEAD --word-diff; }
glb() { [[ -z "$1" ]] && echo "Usage: glb <branch>" && return 1; echo "Showing log for branch: $1"; git log --oneline --graph --decorate "$1"; }

# Staging / Commit
alias ga='git add -A'
alias gc='git commit -m'
alias gca='git commit --amend --no-edit'
gcm() { [[ -z "$1" ]] && echo "Usage: gcm <message>" && return 1; git add -A && git commit -m "$1"; }
gundo() { git reset --soft HEAD~${1:-1}; }

# Checkout / Clone
alias gco='git checkout'
alias gcb='git checkout -b'
alias gcl='git clone'
alias ghcl='gh repo clone'

# Push / Pull
alias gsync='git pull --rebase --prune'
gp() { if [[ -z "$1" ]]; then git pull; else echo "Pulling branch: $1"; git fetch origin "$1:$1"; fi; }
gpu() { if [[ -z "$1" ]]; then git push -u origin HEAD; else echo "Pushing branch: $1"; git push origin "$1"; fi; }

# Branch
alias gb='git branch'
alias gba='git branch -a -vv'
alias gbr='git branch --sort=-committerdate --format="%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(color:red)%(objectname:short)%(color:reset) %(contents:subject) %(color:blue)(%(committerdate:relative)) %(color:green)%(authorname)%(color:reset)"'
gmb() { [[ -z "$1" ]] && echo "Usage: gmb <branch>" && return 1; git merge "$1" --no-ff; }
grb() { [[ -z "$1" ]] && echo "Usage: grb <branch>" && return 1; git rebase "$1"; }
gclean() { git fetch -p && git branch -vv | grep ': gone]' | awk '{print $1}' | xargs git branch -d; }

# Cherry-pick
alias gcp='git cherry-pick'
alias gcpa='git cherry-pick --abort'
alias gcpc='git cherry-pick --continue'
# navigate to repo, checkout base branch, create new branch
gwb() { [[ -z "$3" ]] && echo "Usage: gwb <repo-path> <base-branch> <new-branch>" && return 1; cd "$1" && git checkout "$2" && git checkout -b "$3"; }

# GitHub
ghprc() { [[ -z "$1" ]] && echo "Usage: ghprc <target-branch>" && return 1; gh pr create --base "$1"; }
