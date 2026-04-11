# ripgrep → replace grep
if command -v rg &>/dev/null; then
  alias grep='rg'
fi

# fd → replace find
if command -v fd &>/dev/null; then
  alias find='fd'
fi

# sd → replace sed
if command -v sd &>/dev/null; then
  alias sed='sd'
fi
