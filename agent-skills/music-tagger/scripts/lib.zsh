# music-tagger: shared helpers for scan.sh / lyrics.sh / apply.sh.
# Sourced by the scripts; not meant to be run directly.

# trim <string> -> string without leading/trailing whitespace
trim() {
  local s=$1
  s=${s#"${s%%[![:space:]]*}"}
  s=${s%"${s##*[![:space:]]}"}
  print -r -- "$s"
}

# proposal_dir <proposal> -> absolute folder from the 'dir:' header, or nothing
proposal_dir() {
  awk '
    /^[-*]+[ \t]+dir:[ \t]/ { sub(/^[-*]+[ \t]+dir:[ \t]+/, ""); sub(/[ \t]+$/, ""); print; exit }
    /^dir:[ \t]/            { sub(/^dir:[ \t]+/, ""); sub(/[ \t]+$/, ""); print; exit }
    /^#+[ \t]*dir:[ \t]/    { sub(/^#+[ \t]*dir:[ \t]+/, ""); sub(/[ \t]+$/, ""); print; exit }
  ' "$1"
}

# proposal_parse_row <line>: fills $reply with the row's cells (untrimmed).
# Returns 1 when the line is not a 7-cell Markdown table row.
# Caller should declare `local -a reply` so the array stays out of global scope.
proposal_parse_row() {
  local line=$1
  [[ $line == *\|* ]] || return 1
  line=$(trim "$line")
  [[ $line == \|* ]] || return 1
  [[ $line == *\| ]] && line=${line%\|}
  local -a cols=("${(@s:|:)line}")
  reply=("${(@)cols[2,-1]}")
  (( ${#reply[@]} == 7 ))
}

# proposal_row_is_data <status-cell>: rejects the header row and the | --- | separator
proposal_row_is_data() {
  local state=$1
  [[ $state == STATUS ]] && return 1
  [[ ${state//[-:]/} == "" ]] && return 1
  return 0
}

# proposal_bad_rows <proposal>: print rows that look like table rows but do not
# have 7 cells, so callers can fail loudly instead of misreading a hand edit.
proposal_bad_rows() {
  local line t
  local -a reply
  while IFS= read -r line; do
    t=$(trim "$line")
    [[ $t == \|* ]] || continue
    proposal_parse_row "$line" && continue
    print -r -- "$t"
  done < "$1"
}
