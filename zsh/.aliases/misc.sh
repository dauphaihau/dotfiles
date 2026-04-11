alias j='just'

alias claude-mem='bun "/Users/dauphaihau/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'

# ccusage — Claude API cost tracking (https://ccusage.com)
alias ccu='bunx ccusage'
alias ccud='bunx ccusage daily'
alias ccum='bunx ccusage monthly'
alias ccus='bunx ccusage session'
alias ccub='bunx ccusage blocks'
alias ccusi='bunx ccusage session --id'  # usage: ccusi <session-id>

# tlrc → replace man
if command -v tlrc &>/dev/null; then
  alias man='tlrc'
fi

# open
alias o='open .'
alias of='open'

# duf → replace df
if command -v duf &>/dev/null; then
  alias df='duf'
fi

# procs → replace ps
if command -v procs &>/dev/null; then
  alias ps='procs'
fi

# hyperfine → replace time
if command -v hyperfine &>/dev/null; then
  alias time='hyperfine'
fi
