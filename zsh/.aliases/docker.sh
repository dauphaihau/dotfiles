# Docker runtime management (runtime-agnostic) — dr = docker runtime
if command -v colima &>/dev/null; then
  alias drs='colima start'   # docker runtime start
  alias drsp='colima stop'   # docker runtime stop
  alias drst='colima status' # docker runtime status
fi

# Docker
alias dps='docker ps'           # list running containers
alias dpsa='docker ps -a'       # list all containers
alias dcu='docker compose up'   # start services
alias dcud='docker compose up -d' # start services in background
alias dcd='docker compose down' # stop and remove services
alias dcl='docker compose logs -f' # follow logs
