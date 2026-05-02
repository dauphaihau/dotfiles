# Fig pre block. Keep at the top of this file.
[[ -f "$HOME/.fig/shell/zshrc.pre.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.pre.zsh"

# Centralized exports
source ~/.exports
source ~/.colors

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"
plugins=()
source $ZSH/oh-my-zsh.sh


# Clear all OMZ aliases, then load only custom ones
unalias -a
for f in ~/.aliases/*.sh; do [ -f "$f" ] && source "$f"; done

eval "$(starship init zsh)"

# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

# Keep Volta shims ahead of any Node version manager PATH changes.
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

# Fig post block. Keep at the bottom of this file.
[[ -f "$HOME/.fig/shell/zshrc.post.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.post.zsh"

# bun completions
[ -s "/Users/dauphaihau/.bun/_bun" ] && source "/Users/dauphaihau/.bun/_bun"

if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi

# Launch nushell as a child process (exit nu to return to zsh)
# Skipped in Warp — use Warp's startup command setting instead
if command -v nu >/dev/null 2>&1 && [ -z "$NU_VERSION" ] && [ "$TERM_PROGRAM" != "WarpTerminal" ]; then
  nu
fi

export PATH="$HOME/go/bin:$PATH"

# atlas-cli
export ATLAS_BACKEND_PATH="/Volumes/Local/dev/pj-personal/apps/atlas/apps/api"
export POSTGRES_PASSWORD="secret"
export POSTGRES_HOST="localhost"
export POSTGRES_DB="atlas"
export POSTGRES_USER="laravel"

export ATLAS_PHP_CONTAINER="atlas-php"

# zsh completions
fpath=(~/.zsh/completions $fpath)
autoload -U compinit && compinit

devcopy() {
  local tmp_file url
  local -a cmd

  tmp_file="$(mktemp)"

  if [ -f pnpm-lock.yaml ] && command -v pnpm >/dev/null 2>&1; then
    cmd=(pnpm dev)
  elif [ -f yarn.lock ] && command -v yarn >/dev/null 2>&1; then
    cmd=(yarn dev)
  else
    cmd=(npm run dev)
  fi

  "${cmd[@]}" 2>&1 | tee "$tmp_file" &
  local dev_pid=$!

  while kill -0 "$dev_pid" >/dev/null 2>&1; do
    url="$(perl -ne 'print "$1\n" if m{(http://localhost:\d+/)}' "$tmp_file" | tail -n 1)"
    if [ -n "$url" ]; then
      printf '%s' "$url" | pbcopy
      echo "Copied: $url"
      break
    fi
    sleep 0.2
  done

  wait "$dev_pid"
}
