# Docker runtime management (runtime-agnostic) — dr = docker runtime
if command -v colima &>/dev/null; then
  alias drs='colima start'   # docker runtime start
  alias drsp='colima stop'   # docker runtime stop
  alias drst='colima status' # docker runtime status
fi

# Docker
dps() { if command -v nu &>/dev/null; then docker ps --format '{{json .}}' | nu -c 'open --raw /dev/stdin | lines | each { from json } | select ID Names Image Status Ports | table | to text'; else docker ps; fi; } # list running containers via Nushell table when available
dpsa() { if command -v nu &>/dev/null; then docker ps -a --format '{{json .}}' | nu -c 'open --raw /dev/stdin | lines | each { from json } | select ID Names Image Status Ports | table | to text'; else docker ps -a; fi; } # list all containers via Nushell table when available
alias dpst="docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'" # list running containers in a detailed table
dst() { [[ -z "$1" ]] && echo "Usage: dst <container>" && return 1; docker stop "$1"; } # stop a specific container
alias dex='docker exec -it'        # exec into container

# Docker Compose
alias dcu='docker compose up'   # start services
alias dcud='docker compose up -d' # start services in background
alias dcd='docker compose down' # stop and remove services
alias dcl='docker compose logs -f' # follow logs
alias dcex='docker compose exec'   # exec into a compose service
