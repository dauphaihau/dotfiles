alias bri='brew install'
alias bru='brew uninstall'
alias brl='brew list'
alias broc='brew outdated'

# nr: node runtime
alias nr='volta'              # node runtime manager
alias nra='volta list'        # list all managed tools
alias nrl='volta list node'   # list node versions
alias nri='volta install'     # install/set global default, e.g. nri node@22
alias nru='volta uninstall'   # remove a node version, e.g. nru node@20
alias nrp='volta pin'         # pin/swap project version, e.g. nrp node@22
alias nrw='volta which'       # show active tool path, e.g. nrw node

alias ppd='pnpm dev'
alias ppa='pnpm add'
alias ppad='pnpm add -D'
alias ppi='pnpm install'
alias ppu='pnpm uninstall'

alias bud='bun dev'
alias bua='bun add'
alias buad='bun add -D'
alias bui='bun install'
alias buu='bun uninstall'

alias npd='npm run dev'
alias npa='npm install'
alias npad='npm install -D'
alias npi='npm install'
alias npu='npm uninstall'
