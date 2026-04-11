alias nd='mkdir -p' # new directory
ndc() { mkdir -p "$@" && cd "${@: -1}"; } # new directory and cd into it
alias nf='touch' # new file
alias sl='ln -s' # symlink
alias cpwd='pwd | pbcopy'  # copy current dir path

# trash → replace rm (moves to macOS Trash, recoverable)
if [[ -x "/opt/homebrew/opt/trash/bin/trash" ]]; then
  export PATH="/opt/homebrew/opt/trash/bin:$PATH"
  alias rm='trash'
  alias d='trash'
fi

alias cp='cp -ri'
alias mv='mv -i'
alias rn='mv -i'

# copy/paste/cut files via temp path store
#
# Usage:
#   copy <file|dir> [...]   stage files for copying
#   cut  <file|dir> [...]   stage files for moving
#   paste [dest]            copy/move staged files to dest (default: current dir)
#
# Examples:
#   copy report.pdf notes/          copy multiple items, then:
#   paste ~/Documents/              paste them to Documents
#
#   cut *.log src/                  stage for move, then:
#   paste /tmp/                     move them to /tmp
_COPY_TMP="$HOME/.copy_tmp"
_COPY_MODE="$HOME/.copy_mode"  # "copy" or "cut"

copy() {
  : > "$_COPY_TMP"
  for f in "$@"; do realpath "$f" >> "$_COPY_TMP"; done
  echo "copy" > "$_COPY_MODE"
  echo "Copied (${#@}):"
  cat "$_COPY_TMP"
}

cut() {
  : > "$_COPY_TMP"
  for f in "$@"; do realpath "$f" >> "$_COPY_TMP"; done
  echo "cut" > "$_COPY_MODE"
  echo "Cut (${#@}):"
  cat "$_COPY_TMP"
}

paste() {
  local dest="${1:-.}"
  local mode=$(cat "$_COPY_MODE" 2>/dev/null || echo "copy")
  while IFS= read -r src; do
    if [[ "$mode" == "cut" ]]; then
      mv "$src" "$dest" && echo "Moved: $src → $dest"
    else
      cp -r "$src" "$dest" && echo "Pasted: $src → $dest"
    fi
  done < "$_COPY_TMP"
}
