# Fig pre block. Keep at the top of this file.
[[ -f "$HOME/.fig/shell/bashrc.pre.bash" ]] && builtin source "$HOME/.fig/shell/bashrc.pre.bash"
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi

# Load aliases
for f in ~/.aliases/*.sh; do [ -f "$f" ] && source "$f"; done

# Centralized exports
source ~/.exports

# Fig post block. Keep at the bottom of this file.
[[ -f "$HOME/.fig/shell/bashrc.post.bash" ]] && builtin source "$HOME/.fig/shell/bashrc.post.bash"


. "$HOME/.cargo/env"

if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init bash)"; fi
