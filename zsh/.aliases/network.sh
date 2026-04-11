alias ports='lsof -i -P -n | grep LISTEN'
alias myip='curl -s ifconfig.me'

# gping → replace ping
if command -v gping &>/dev/null; then
  alias ping='gping'
fi

# doggo → replace dig
if command -v doggo &>/dev/null; then
  alias dig='doggo'
fi
