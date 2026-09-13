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
#
# Matching: same artist (normalized substring) and duration within 3s of the file,
# preferring a normalized exact title match. When that finds nothing and the ARTIST
# cell carries an origin marker -- "Laura Benanti (Lewis Capaldi origin)" -- the
# lookup is retried against the original artist. Lyrics are identical for a cover,
# and the original's entry is usually the only one LRCLIB has. The retry requires an
# exact normalized title and exact-enough artist, but no duration gate: a cover's
# length can differ a lot, so the closest duration simply wins. Such a result is
# labelled "(via original <name>)" in DETAIL.
#
# Synced lyrics are ignored on purpose -- USLT has no timing, so embedding LRC text
# would store literal timestamps.

emulate -L zsh
source "${0:A:h}/lib.zsh"

UA='music-tagger/0.1 (personal use)'
API='https://lrclib.net/api/search'
TOL_PERFORMER=3
TOL_ORIGIN=0   # 0 = no duration gate

norm() { print -r -- "$1" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]' }

# lrclib_search <artist> <title> -> JSON array on stdout; prints raw text and
# returns non-zero on network/transport failure. One retry, after a short pause,
# when LRCLIB answers 503 / ServerOverloaded -- observed in practice under bursts.
lrclib_search() {
  local a=$1 t=$2 out attempt=1
  while :; do
    if out=$(curl -sS --max-time 20 -A "$UA" -G \
               --data-urlencode "artist_name=$a" \
               --data-urlencode "track_name=$t" \
               "$API" 2>&1) \
       && print -r -- "$out" | jq -e 'type == "array"' >/dev/null 2>&1; then
      print -r -- "$out"
      return 0
    fi
    if (( attempt < 2 )) && [[ $out == *503* || $out == *ServerOverloaded* ]]; then
      attempt=$(( attempt + 1 ))
      sleep 2
      continue
    fi
    print -r -- "$out"
    return 1
  done
}

# lrclib_match <json> <title> <artist> <duration> <tolerance>
# -> one JSON object: {status, plain, detail}
lrclib_match() {
  local json=$1 t=$2 a=$3 d=$4 tol=$5
  print -r -- "$json" | jq -c \
    --arg t "$(norm "$t")" \
    --arg a "$(norm "$a")" \
    --argjson d "$d" \
    --argjson tol "$tol" '
    (. | length) as $raw
    | [ .[]
        | select((.instrumental // false) == false)
        | select(.plainLyrics != null and (.plainLyrics | length) > 0)
        | select(.duration != null)
        | select($tol == 0 or ((.duration - $d) * (.duration - $d)) <= ($tol * $tol))
        | select(((.artistName // "") | ascii_downcase | gsub("[^a-z0-9]"; "")) | contains($a))
      ] as $cands
    | ($cands | map(. + {tn: ((.trackName // "") | ascii_downcase | gsub("[^a-z0-9]"; ""))})) as $normed
    | ($normed | map(select(.tn == $t))) as $exact
    | (if $tol > 0 then "within \($tol)s" else "any duration" end) as $scope
    | if ($exact | length) > 0 then
        ($exact | sort_by((.duration - $d) * (.duration - $d)) | .[0]) as $b
        | ($b.duration - $d | if . < 0 then -. else . end) as $dd
        | if ($tol == 0 and $dd > 120) then
            {status: "ambiguous", plain: null,
             detail: "closest exact-title candidate is \((($dd * 100) | round) / 100)s off the file duration: \($b.trackName) - \($b.artistName) \($b.duration)s (\($raw) raw) -- check the version before using it"}
          else
            {status: "match", plain: $b.plainLyrics,
             detail: "[\($raw) raw, \($cands | length) \($scope)] \($b.trackName) - \($b.artistName) \($b.duration)s, diff \((($dd * 100) | round) / 100)s"}
          end
      elif ($cands | length) > 0 then
        {status: "ambiguous", plain: null,
         detail: "\($cands | length) candidate(s) matched artist and duration but none exactly matched the title (\($raw) raw)"}
      else
        {status: "none", plain: null,
         detail: "no candidate \($scope) of the file duration (\($raw) raw)"}
      end
  ' 2>/dev/null
}

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

  local line state file title artist lyrics verdict detail out slug src fdur json sel qtitle qartist origin verdict2 detail2
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

    if ! json=$(lrclib_search "$qartist" "$qtitle"); then
      print -r -- "$(printf 'LYRICS\t%s\t-\terror\tlrclib request failed: %s' "$file" "${json//$'\n'/ }")"
      (( errored++ ))
      continue
    fi

    sel=$(lrclib_match "$json" "$qtitle" "$qartist" "$fdur" "$TOL_PERFORMER")
    if [[ -z $sel ]]; then
      print -r -- "$(printf 'LYRICS\t%s\t-\terror\tcould not parse lrclib response' "$file")"
      (( errored++ ))
      continue
    fi

    verdict=$(print -r -- "$sel" | jq -r '.status')
    detail=$(print -r -- "$sel" | jq -r '.detail')

    if [[ $verdict != match ]]; then
      origin=$(origin_artist "$artist")
      if [[ -n $origin ]]; then
        if json=$(lrclib_search "$origin" "$qtitle"); then
          sel2=$(lrclib_match "$json" "$qtitle" "$origin" "$fdur" "$TOL_ORIGIN")
          if [[ -n $sel2 ]]; then
            verdict2=$(print -r -- "$sel2" | jq -r '.status')
            detail2=$(print -r -- "$sel2" | jq -r '.detail')
            if [[ $verdict2 == match ]]; then
              sel=$sel2
              verdict=$verdict2
              detail="$detail2 (via original $origin)"
            elif [[ $verdict2 == ambiguous ]]; then
              sel=$sel2
              verdict=$verdict2
              detail="$detail2 (via original $origin)"
            else
              detail="$detail (origin $origin: no exact title match)"
            fi
          fi
        else
          detail="$detail (origin lookup failed)"
        fi
      fi
    fi

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
