#!/usr/bin/env zsh
# music-tagger: fetch plain lyrics for the OK rows of a proposal.
#
# usage: lyrics.sh <proposal.md> [--force]
#
# For every OK row with a title and an artist, query LRCLIB and, on a confident
# match, write the plain lyrics to
#   <folder>/.mtag-lyrics/<artist>-<title>.txt
# then print one machine-readable line per row:
#   LYRICS <TAB> FILE <TAB> PATH|- <TAB> STATUS <TAB> DETAIL
#
# STATUS: match | cached | ambiguous | none | error
#   match      lyrics written (or reused) at PATH; put PATH in the row's LYRICS cell
#   cached     an up-to-date file was already staged; PATH is usable
#   ambiguous  candidates matched title+duration but not exactly -- decide yourself,
#              leave the cell as '-'
#   none       nothing usable; leave the cell as '-'
#   error      network/IO failure for that row
#
# Nothing is written into the proposal: the caller patches the LYRICS cells.
# Matching: same artist (normalized substring) and duration within 3s of the file,
# preferring a normalized exact title match. Synced lyrics are ignored on purpose --
# USLT has no timing, so embedding LRC text would store literal timestamps.

emulate -L zsh
source "${0:A:h}/lib.zsh"

UA='music-tagger/0.1 (personal use)'
API='https://lrclib.net/api/search'

main() {
  setopt pipe_fail

  local usage="usage: lyrics.sh <proposal.md> [--force]"
  if (( $# < 1 )); then
    print -u2 "$usage"
    return 2
  fi

  local proposal=$1
  local force=0
  [[ $2 == --force || $2 == -f ]] && force=1

  if [[ ! -f $proposal ]]; then
    print -u2 "lyrics.sh: no such proposal: $proposal"
    return 2
  fi

  local cmd
  for cmd in ffprobe jq curl; do
    command -v $cmd >/dev/null || { print -u2 "lyrics.sh: $cmd not found in PATH"; return 3 }
  done

  local dir
  dir=$(proposal_dir "$proposal")
  if [[ -z $dir || ! -d $dir ]]; then
    print -u2 "lyrics.sh: proposal has no usable 'dir: <path>' header"
    return 2
  fi
  dir=${dir:A}

  local bad
  bad=$(proposal_bad_rows "$proposal")
  if [[ -n $bad ]]; then
    print -u2 "lyrics.sh: malformed table row (need $PROPOSAL_CELLS cells): $bad"
    return 2
  fi

  local stage="$dir/.mtag-lyrics"

  local line state file title artist lyrics verdict detail out slug src fdur json sel qtitle qartist
  local matched=0 cached=0 ambiguous=0 none=0 errored=0
  local -a reply

  while IFS= read -r line; do
    proposal_parse_row "$line" || continue
    state=$(trim "${reply[1]}")
    proposal_row_is_data "$state" || continue

    file=$(trim "${reply[2]}")
    title=$(trim "${reply[3]}")
    artist=$(trim "${reply[4]}")
    lyrics=$(trim "${reply[5]}")

    [[ $state == OK ]] || continue

    if [[ -n $lyrics && $lyrics != '-' ]]; then
      print -r -- "$(printf 'LYRICS\t%s\t%s\tcached\trow already has lyrics: %s' "$file" "$lyrics" "$lyrics")"
      (( cached++ ))
      continue
    fi

    if [[ -z $title || -z $artist ]]; then
      print -r -- "$(printf 'LYRICS\t%s\t-\tnone\trow has no title or no artist to search with' "$file")"
      (( none++ ))
      continue
    fi

    src="$dir/$file"
    if [[ ! -f $src ]]; then
      print -r -- "$(printf 'LYRICS\t%s\t-\terror\tmissing audio file: %s' "$file" "$src")"
      (( errored++ ))
      continue
    fi

    fdur=$(ffprobe -v quiet -print_format json -show_format -- "$src" 2>/dev/null \
           | jq -r '.format.duration // empty' 2>/dev/null)
    if [[ -z $fdur ]]; then
      print -r -- "$(printf 'LYRICS\t%s\t-\terror\tcannot read duration from %s' "$file" "$file")"
      (( errored++ ))
      continue
    fi

    qtitle=$(strip_cover_suffix "$title")
    qartist=$(strip_origin_suffix "$artist")

    slug=$(print -r -- "$qartist - $qtitle" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/^-//; s/-$//')
    out="$stage/${slug}.txt"

    if (( ! force )) && [[ -s $out ]]; then
      print -r -- "$(printf 'LYRICS\t%s\t%s\tcached\tstaged earlier (--force to refetch)' "$file" ".mtag-lyrics/${slug}.txt")"
      (( cached++ ))
      continue
    fi

    if ! json=$(curl -sS --max-time 20 -A "$UA" -G \
                  --data-urlencode "artist_name=$qartist" \
                  --data-urlencode "track_name=$qtitle" \
                  "$API" 2>&1); then
      print -r -- "$(printf 'LYRICS\t%s\t-\terror\tlrclib request failed: %s' "$file" "${json//$'\n'/ }")"
      (( errored++ ))
      continue
    fi
    if ! print -r -- "$json" | jq -e 'type == "array"' >/dev/null 2>&1; then
      print -r -- "$(printf 'LYRICS\t%s\t-\terror\tlrclib returned no result array' "$file")"
      (( errored++ ))
      continue
    fi

    sel=$(print -r -- "$json" | jq -c \
      --arg t "$(print -r -- "$qtitle" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')" \
      --arg a "$(print -r -- "$qartist" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')" \
      --argjson d "$fdur" '
      (. | length) as $raw
      | [ .[]
          | select((.instrumental // false) == false)
          | select(.plainLyrics != null and (.plainLyrics | length) > 0)
          | select(.duration != null)
          | select(((.duration - $d) * (.duration - $d)) <= 9)
          | select(((.artistName // "") | ascii_downcase | gsub("[^a-z0-9]"; "")) | contains($a))
        ] as $cands
      | ($cands | map(. + {tn: ((.trackName // "") | ascii_downcase | gsub("[^a-z0-9]"; ""))})) as $norm
      | ($norm | map(select(.tn == $t))) as $exact
      | if ($exact | length) > 0 then
          ($exact | sort_by((.duration - $d) * (.duration - $d)) | .[0]) as $b
          | ($b.duration - $d | if . < 0 then -. else . end) as $dd
          | {status: "match", plain: $b.plainLyrics,
             detail: "[\($raw) raw, \($cands | length) within 3s] \($b.trackName) - \($b.artistName) \($b.duration)s, diff \((($dd * 100) | round) / 100)s"}
        elif ($cands | length) > 0 then
          {status: "ambiguous", plain: null,
           detail: "\($cands | length) candidate(s) matched artist and duration but none exactly matched the title (\($raw) raw)"}
        else
          {status: "none", plain: null,
           detail: "no candidate within 3s of the file duration (\($raw) raw)"}
        end
    ' 2>/dev/null)

    if [[ -z $sel ]]; then
      print -r -- "$(printf 'LYRICS\t%s\t-\terror\tcould not parse lrclib response' "$file")"
      (( errored++ ))
      continue
    fi

    verdict=$(print -r -- "$sel" | jq -r '.status')
    detail=$(print -r -- "$sel" | jq -r '.detail')

    case $verdict in
      match)
        mkdir -p "$stage"
        if ! print -r -- "$sel" | jq -r '.plain' > "$out"; then
          print -r -- "$(printf 'LYRICS\t%s\t-\terror\tcould not write %s' "$file" "$out")"
          (( errored++ ))
          continue
        fi
        print -r -- "$(printf 'LYRICS\t%s\t%s\tmatch\t%s' "$file" ".mtag-lyrics/${slug}.txt" "$detail")"
        (( matched++ ))
        ;;
      ambiguous)
        print -r -- "$(printf 'LYRICS\t%s\t-\tambiguous\t%s' "$file" "$detail")"
        (( ambiguous++ ))
        ;;
      *)
        print -r -- "$(printf 'LYRICS\t%s\t-\tnone\t%s' "$file" "$detail")"
        (( none++ ))
        ;;
    esac
  done < "$proposal"

  print "# lyrics: $matched matched, $cached cached, $ambiguous ambiguous, $none none, $errored errors"
  (( errored > 0 )) && return 1
  return 0
}

main "$@"
