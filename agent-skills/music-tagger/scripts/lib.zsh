# music-tagger: shared helpers for scan.sh / lyrics.sh / apply.sh.
# Sourced by the scripts; not meant to be run directly.
#
# Proposal table columns, in order:
#   1 STATUS  2 FILE  3 TITLE  4 ARTIST  5 LYRICS  6 IMAGE  7 CONF  8 NOTE
# Change PROPOSAL_CELLS here and the parsers, the proposal spec in SKILL.md, and
# the header row examples all move together.
PROPOSAL_CELLS=8

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
# Returns 1 when the line is not a PROPOSAL_CELLS-cell Markdown table row.
# Caller should declare `local -a reply` so the array stays out of global scope.
proposal_parse_row() {
  local line=$1
  [[ $line == *\|* ]] || return 1
  line=$(trim "$line")
  [[ $line == \|* ]] || return 1
  [[ $line == *\| ]] && line=${line%\|}
  local -a cols=("${(@s:|:)line}")
  reply=("${(@)cols[2,-1]}")
  (( ${#reply[@]} == PROPOSAL_CELLS ))
}

# proposal_row_is_data <status-cell>: rejects the header row and the | --- | separator
proposal_row_is_data() {
  local state=$1
  [[ $state == STATUS ]] && return 1
  [[ ${state//[-:]/} == "" ]] && return 1
  return 0
}

# Cover convention (user's shape):
#   TITLE  "Song Name (Cover Artist cover)"
#   ARTIST "Cover Artist (Original Artist origin)"
# These helpers recover the bare identity for lookups that must not see the
# markers (LRCLIB queries, staged filenames). Tag writes use the decorated values.

# strip_cover_suffix <title> -> title without a trailing "(... cover)"
strip_cover_suffix() {
  local s=$1
  [[ $s == *')' ]] || { print -r -- "$s"; return 0 }
  local body=${s%\)}
  [[ $body == *'('* ]] || { print -r -- "$s"; return 0 }
  local tail=${body##*'('}
  [[ ${tail:l} == *[[:space:]]cover || ${tail:l} == cover ]] || { print -r -- "$s"; return 0 }
  local head=${body%'('*}
  print -r -- "${head%[[:space:]]}"
}

# strip_origin_suffix <artist> -> artist without a trailing "(... origin)"
strip_origin_suffix() {
  local s=$1
  [[ $s == *')' ]] || { print -r -- "$s"; return 0 }
  local body=${s%\)}
  [[ $body == *'('* ]] || { print -r -- "$s"; return 0 }
  local tail=${body##*'('}
  [[ ${tail:l} == *[[:space:]]origin || ${tail:l} == origin ]] || { print -r -- "$s"; return 0 }
  local head=${body%'('*}
  print -r -- "${head%[[:space:]]}"
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
