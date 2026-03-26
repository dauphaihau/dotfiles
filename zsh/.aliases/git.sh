# Status / Log
alias gs='git status -sb'
alias gl='git log --oneline --graph --decorate --all'
alias gd='git diff --word-diff'
alias gds='git diff --cached --word-diff'
gdb() { [[ -z "$1" ]] && echo "Usage: gdb <branch>" && return 1; git diff "$1"..HEAD --word-diff; }
glb() { [[ -z "$1" ]] && echo "Usage: glb <branch>" && return 1; echo "Showing log for branch: $1"; git log --oneline --graph --decorate "$1"; }
glg() { [[ -z "$1" ]] && echo "Usage: glg <message> [branch]" && return 1; git log --oneline --graph --decorate ${2:---all} --grep="$1"; }
gsl() { git log --oneline ${1:---all} | fzf | awk '{print $1}'; } # git search log
gshow() { git show ${1:-HEAD} | bat --style=plain; }
alias gdp='git diff | bat --style=plain'

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
gcof() { git checkout $(git branch --all | fzf | tr -d '[:space:]'); }

# Push / Pull
alias gsync='git pull --rebase --prune'
gp() { if [[ -z "$1" ]]; then git pull; else echo "Pulling branch: $1"; git fetch origin "$1:$1"; fi; }
gpu() { if [[ -z "$1" ]]; then git push -u origin HEAD; else echo "Pushing branch: $1"; git push origin "$1"; fi; }

# Branch
alias gb='git branch'
alias gba='git branch -a -vv'
alias gbr='git branch --sort=-committerdate --format="%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(color:red)%(objectname:short)%(color:reset) %(contents:subject) %(color:blue)(%(committerdate:relative)) %(color:green)%(authorname)%(color:reset)"'
gmb() { [[ -z "$1" ]] && echo "Usage: gmb <branch>" && return 1; git merge "$1" --no-ff; }
gbrn() { if [[ $# -eq 1 ]]; then git branch -m "$1"; elif [[ $# -eq 2 ]]; then git branch -m "$1" "$2"; else echo "Usage: gbrn <new-name> | gbrn <old-name> <new-name>"; return 1; fi; } # gbrn <new-name>: rename current branch | gbrn <old-name> <new-name>: rename any branch
grb() { [[ -z "$1" ]] && echo "Usage: grb <branch>" && return 1; git rebase "$1"; }
gclean() { git fetch -p && git branch -vv | grep ': gone]' | awk '{print $1}' | xargs git branch -d; }
gsf() { git stash apply $(git stash list | fzf | awk -F: '{print $1}'); }

# Cherry-pick
alias gcp='git cherry-pick'
alias gcpa='git cherry-pick --abort'
alias gcpc='git cherry-pick --continue'
gwb() { # navigate to repo, checkout base branch, create new branch
  if [[ $# -eq 2 ]]; then
    git checkout "$1" && git checkout -b "$2"
  elif [[ $# -eq 3 ]]; then
    cd "$1" && git checkout "$2" && git checkout -b "$3"
  else
    echo "Usage: gwb <base-branch> <new-branch> | gwb <repo-path> <base-branch> <new-branch>"
    return 1
  fi
}
# search + pick multiple commits
gpickm() { git cherry-pick $(git log --oneline ${1:---all} | fzf -m | awk '{print $1}'); }


# GitHub
ghprc() { [[ -z "$1" ]] && echo "Usage: ghprc <target-branch>" && return 1; gh pr create --base "$1"; }
alias ghprl='gh pr list'

# Search
gfind() { [[ -z "$1" ]] && echo "Usage: gfind <string> [branch]" && return 1; git log --oneline -S "$1" ${2:---all} | rg --color=always "$1"; }
grg() { [[ -z "$1" ]] && echo "Usage: grg <pattern>" && return 1; git ls-files | xargs rg "$1"; }
gbf() { git branch -a | rg --color=always "${1:-.}"; } # git branch find
