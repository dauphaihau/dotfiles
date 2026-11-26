#!/usr/bin/env zsh
# music-tagger: fetch plain lyrics for the OK rows of a proposal.
#
# usage: lyrics.sh <proposal.md> [--force] [--arrangement]
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
# Lookup order per row, first match wins:
#   1. credit query      ARTIST + TITLE, duration within 3s
#   2. credit split      TITLE only, also with trailing qualifiers stripped: LRCLIB's
#                        artist field holds "T.R.I", not "T.R.I x Dangrangto x DONAL",
#                        and "Đường Tôi Chở Em Về", not "... (Lofi Ver.)"
#   3. origin fallback   covered songs: query the original artist, no duration gate
#   4. arrangement       only with --arrangement: accept a candidate outside 3s when
#                        the text is independently corroborated, or when the closest
#                        exact-title record sits within 15s and at least two LRCLIB
#                        records agree on title+artist. Lofi/extended cuts land here.
#
# Artist matching compares whole credit and every collaborator segment against
# LRCLIB's artist in two key forms -- ASCII-folded (Thuỳ -> thuy) and
# diacritic-stripped -- so a Vietnamese spelling on one side and an ASCII spelling
# on the other still line up.
#
# Synced lyrics are ignored on purpose -- USLT has no timing, so embedding LRC text
# would store literal timestamps.

emulate -L zsh
source "${0:A:h}/lib.zsh"

UA='music-tagger/0.2 (personal use)'
API='https://lrclib.net/api/search'
LYRICSHOV='https://api.lyrics.ovh/v1'
TOL_PERFORMER=3
TOL_ORIGIN=0        # 0 = no duration gate (closest exact title wins, 120s guard)
TOL_ARRANGEMENT=120 # outer bound for the arrangement pass
ARRANGEMENT_TIGHT=15
CORROBORATE_MIN=0.8

# lrclib_match fills these; plain text carries newlines, so it stays out of the array.
typeset -g match_plain=''
typeset -ga match_reply=(none - 0 0 '' '' '' '')

# --- text keys -------------------------------------------------------------

# strip_key <text> -> lowercase ASCII letters and digits, non-ASCII dropped
# ("Thùy" -> "thy"). Both sides of a comparison get the same treatment, so a value
# from the proposal lines up with LRCLIB's own spelling without re-encoding it.
strip_key() {
  local s
  s=$(print -r -- "$1" | LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C tr -cd 'a-z0-9')
  print -r -- "$s"
}

# fold_text <text> -> lowercase ASCII with spaces kept ("Thùy Chi" -> "thuy chi").
# Decomposes to NFD and drops combining marks, so "Thùy/Thuỳ/Thuy" all fold alike;
# đ is folded by hand because it has no decomposition. macOS iconv refuses Vietnamese
# (Illegal byte sequence), so perl is tried first and iconv is the fallback; without
# either, only diacritic stripping is possible and fold_key degenerates to strip_key.
fold_text() {
  local out
  if out=$(print -r -- "$1" | perl -CS -Mutf8 -MUnicode::Normalize \
             -pe '$_ = NFD($_); s/\p{Mn}//g; tr/đĐ/dD/; $_ = lc' 2>/dev/null) \
     && [[ -n $out ]]; then
    print -r -- "$out"
    return 0
  fi
  if out=$(print -r -- "$1" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null); then
    print -r -- "$out" | tr '[:upper:]' '[:lower:]'
    return 0
  fi
  print -r -- "$1" | tr '[:upper:]' '[:lower:]'
}

# fold_key <text> -> folded text with spaces and punctuation removed ("thuychi")
fold_key() {
  print -r -- "$(print -r -- "$(fold_text "$1")" | LC_ALL=C tr -cd 'a-z0-9')"
}

# unicode_fold <text> -> same as fold_text, kept as a name for text comparison
unicode_fold() { fold_text "$1" }

# credit_parts <artist> -> one as-written collaborator per line
credit_parts() {
  local s=$1
  s=${s// x /$'\n'}; s=${s// X /$'\n'}; s=${s// × /$'\n'}
  s=${s// ft. /$'\n'}; s=${s// feat. /$'\n'}
  s=${s// ft /$'\n'}; s=${s// feat /$'\n'}
  s=${s// and /$'\n'}; s=${s// & /$'\n'}
  s=${s//,/$'\n'}; s=${s//;/$'\n'}; s=${s//\//$'\n'}
  local l
  for l in "${(@f)s}"; do
    l=$(trim "$l")
    [[ -n $l ]] && print -r -- "$l"
  done
}

# credit_keys <artist> -> space-separated match keys: whole credit plus every segment,
# each ASCII-folded and diacritic-stripped, deduplicated, shorter than 3 dropped.
credit_keys() {
  local a=$1 p k
  local -a keys=()
  for p in "$a" "${(@f)$(credit_parts "$a")}"; do
    for k in "$(fold_key "$p")" "$(strip_key "$p")"; do
      (( ${#k} >= 3 )) && keys+=("$k")
    done
  done
  local -a uniq=("${(u)keys[@]}")
  print -r -- "${uniq[*]}"
}

# strip_qualifier <title> -> title without trailing (…), […], 「…」 markers
strip_qualifier() {
  local s=$1
  while [[ $s =~ '^(.*[^[:space:]])[[:space:]]*(\([^()]*\)|\[[^][]*\]|「[^」]*」)$' ]]; do
    s=$match[1]
  done
  print -r -- "$s"
}

# title_forms <title> -> the title, then the qualifier-stripped title if different
title_forms() {
  local s=$1 base
  print -r -- "$s"
  base=$(strip_qualifier "$s")
  [[ -n $base && $base != "$s" ]] && print -r -- "$base"
}

# artist_forms <artist> -> whole credit then each collaborator, one per line, max 4
artist_forms() {
  local a=$1 f
  local -a forms=("$a" "${(@f)$(credit_parts "$a")}")
  local -a uniq=("${(u)forms[@]}")
  local -i n=0
  for f in "${uniq[@]}"; do
    (( n < 4 )) || break
    print -r -- "$f"
    (( n++ ))
  done
}

# --- LRCLIB ----------------------------------------------------------------

# lrclib_get <curl --data-urlencode args...> -> JSON array on stdout; non-zero on
# network/transport failure. One retry, after a short pause, when LRCLIB answers
# 503 / ServerOverloaded -- observed in practice under bursts.
lrclib_get() {
  local out attempt=1
  while :; do
    if out=$(curl -sS --max-time 20 -A "$UA" -G "$@" "$API" 2>&1) \
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

lrclib_search() {
  lrclib_get --data-urlencode "artist_name=$1" --data-urlencode "track_name=$2"
}

lrclib_search_title() {
  lrclib_get --data-urlencode "track_name=$1"
}

# lrclib_match <json> <title> <artist-keys> <duration> <tolerance>
# Sets match_reply=(status idx diff records track artist dur detail) and match_plain.
# Artist match: a key of at least 3 chars is contained in LRCLIB's artist, stripped or
# folded, or LRCLIB's artist is contained in the key. Title match: equal after
# stripping, or equal after folding.
lrclib_match() {
  local json=$1 t=$2 keys=$3 d=$4 tol=$5
  local tkey tfold raw rows idx dur track artist akey afold tk tf art_ok k
  local diff records=0 within=0 best_diff='' best_idx='' best_track='' best_artist='' best_dur=''
  local -a kt=("${(@s: :)keys}")

  tkey=$(strip_key "$t")
  tfold=$(fold_key "$t")
  match_plain=''
  match_reply=(none - 0 0 '' '' '' '')

  raw=$(print -r -- "$json" | jq -r 'length' 2>/dev/null) || { match_reply[8]='could not parse lrclib response'; return 1 }
  rows=$(print -r -- "$json" | jq -r '
    to_entries[]
    | select((.value.instrumental // false) == false)
    | select(.value.plainLyrics != null and (.value.plainLyrics | length) > 0)
    | select(.value.duration != null)
    | [ .key, .value.duration, (.value.trackName // ""), (.value.artistName // "") ]
    | @tsv' 2>/dev/null)

  while IFS=$'\t' read -r idx dur track artist; do
    [[ -n $idx && -n $dur ]] || continue

    akey=$(strip_key "$artist")
    afold=$(fold_key "$artist")
    art_ok=0
    for k in "${kt[@]}"; do
      (( ${#k} >= 3 )) || continue
      if [[ $afold == *$k* || $akey == *$k* || $k == *$afold* || $k == *$akey* ]]; then
        art_ok=1
        break
      fi
    done
    (( art_ok )) || continue

    tk=$(strip_key "$track")
    tf=$(fold_key "$track")
    [[ $tk == $tkey || $tf == $tfold ]] || continue
    (( records++ ))

    diff=$(awk -v a="$dur" -v b="$d" 'BEGIN{d = a - b; if (d < 0) d = -d; printf "%.2f", d}')
    if [[ $tol == 0 ]] || awk -v x="$diff" -v y="$tol" 'BEGIN{exit !(x <= y)}'; then
      (( within++ ))
      if [[ -z $best_diff ]] || awk -v x="$diff" -v y="$best_diff" 'BEGIN{exit !(x < y)}'; then
        best_diff=$diff
        best_idx=$idx
        best_track=$track
        best_artist=$artist
        best_dur=$dur
      fi
    fi
  done <<< "$rows"

  if [[ -n $best_idx ]]; then
    if [[ $tol == 0 ]] && awk -v x="$best_diff" 'BEGIN{exit !(x > 120)}'; then
      match_reply=(ambiguous - "$best_diff" "$records" "$best_track" "$best_artist" "$best_dur" \
        "closest exact-title candidate is ${best_diff}s off the file duration: $best_track - $best_artist ${best_dur}s ($raw raw) -- check the version before using it")
      return 0
    fi
    match_plain=$(print -r -- "$json" | jq -r --argjson i "$best_idx" '.[$i].plainLyrics' 2>/dev/null)
    match_reply=(match "$best_idx" "$best_diff" "$records" "$best_track" "$best_artist" "$best_dur" \
      "[$raw raw, $within within ${tol}s] $best_track - $best_artist ${best_dur}s, diff ${best_diff}s")
    return 0
  fi

  if (( within > 0 )); then
    match_reply=(ambiguous - -1 "$records" '' '' '' \
      "$within candidate(s) matched artist and duration but none exactly matched the title ($raw raw)")
  else
    match_reply=(none - -1 "$records" '' '' '' \
      "no candidate within ${tol}s of the file duration ($raw raw)")
  fi
  return 0
}

# --- corroboration ---------------------------------------------------------

# urlenc <text> -> percent-encoded
urlenc() { jq -rn --arg s "$1" '$s|@uri'; }

# lyricsovh_fetch <artist> <title> -> plain text on stdout, non-zero when absent
lyricsovh_fetch() {
  local out
  out=$(curl -sS --max-time 12 -A "$UA" "$LYRICSHOV/$(urlenc "$1")/$(urlenc "$2")" 2>/dev/null) || return 1
  print -r -- "$out" | jq -e '.lyrics | strings | length > 0' >/dev/null 2>&1 || return 1
  print -r -- "$out" | jq -r '.lyrics'
}

# text_similarity <folded-a> <folded-b> -> token Jaccard, 0..1
text_similarity() {
  jq -rn --arg a "$1" --arg b "$2" '
    def toks: [scan("[a-z0-9]+")] | unique;
    ($a | toks) as $x | ($b | toks) as $y
    | (($x + $y) | unique | length) as $u
    | (($x - $y | length) + ($y - $x | length)) as $d
    | if $u == 0 then 0 else ((($u - $d) / $u) * 100 | round) / 100 end'
}

# corroborate_text <artist> <title> <lrclib-plain> -> best similarity score, or nothing.
# Lyrics text is used only to confirm which record belongs to this audio file; it is
# never merged into the staged file.
corroborate_text() {
  local artist=$1 title=$2 plain=$3 a t text score best=''
  local ref
  ref=$(unicode_fold "$plain")
  [[ -z $ref ]] && return 0
  # Collaborators first -- the full credit is the string lyrics.ovh is least likely to
  # know -- and at most 2x2 lookups, so an unreachable source cannot stall a row.
  local -a aforms=("${(@f)$(credit_parts "$artist")}" "$artist")
  local -a tforms=("${(@f)$(title_forms "$title")}")
  local -i na=0 nt=0
  for a in "${aforms[@]}"; do
    (( na < 2 )) || break
    (( na++ ))
    nt=0
    for t in "${tforms[@]}"; do
      (( nt < 2 )) || break
      (( nt++ ))
      [[ -n $a && -n $t ]] || continue
      text=$(lyricsovh_fetch "$a" "$t") || continue
      score=$(text_similarity "$ref" "$(unicode_fold "$text")")
      [[ -n $score ]] || continue
      if [[ -z $best ]] || awk -v a="$score" -v b="$best" 'BEGIN{exit !(a > b)}'; then
        best=$score
      fi
    done
  done
  [[ -n $best ]] && print -r -- "$best"
  return 0
}

# --- lookup passes ---------------------------------------------------------

# merge_json <array-a> <array-b> -> one array, duplicates by record id removed
merge_json() {
  jq -c -s 'add | unique_by(.id)' <<< "$1"$'\n'"$2" 2>/dev/null
}

typeset -g pursue_status='' pursue_detail='' pursue_plain='' pursue_diff='' pursue_records=0

# pursue_match <json> <title> <keys> <file-duration>
# Runs the 3s pass and, with --arrangement, the 120s pass. Sets pursue_status to
# match | wide (a close record outside the gate) | none | ambiguous.
pursue_match() {
  local json=$1 t=$2 keys=$3 d=$4
  pursue_status=''
  pursue_plain=''
  pursue_diff=''
  pursue_records=0
  lrclib_match "$json" "$t" "$keys" "$d" "$TOL_PERFORMER"
  pursue_status=${match_reply[1]}
  pursue_detail=${match_reply[8]}
  pursue_records=${match_reply[4]}
  if [[ $pursue_status == match ]]; then
    pursue_plain=$match_plain
    return 0
  fi
  if (( arrangement )); then
    lrclib_match "$json" "$t" "$keys" "$d" "$TOL_ARRANGEMENT"
    if [[ ${match_reply[1]} == match ]]; then
      pursue_status=wide
      pursue_detail=${match_reply[8]}
      pursue_plain=$match_plain
      pursue_diff=${match_reply[3]}
      pursue_records=${match_reply[4]}
    fi
  fi
  return 0
}

main() {
  setopt pipe_fail

  local usage="usage: lyrics.sh <proposal.md> [--force] [--arrangement]"
  local proposal='' force=0 arrangement=0 arg
  for arg in "$@"; do
    case $arg in
      --force|-f)       force=1 ;;
      --arrangement|-a) arrangement=1 ;;
      -*)               print -u2 "$usage"; return 2 ;;
      *)                [[ -z $proposal ]] && proposal=$arg ;;
    esac
  done
  if [[ -z $proposal ]]; then
    print -u2 "$usage"
    return 2
  fi

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

  local line state file title artist lyrics verdict detail out slug src fdur json json_all json_t keys
  local qt qa json_a origin score adiff arecords arr_detail arr_plain='' arr_idx='' arr_qt=''
  local matched=0 cached=0 ambiguous=0 none=0 errored=0 overridden=0
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

    artist=$(strip_origin_suffix "$artist")
    keys=$(credit_keys "$artist")
    if [[ -z $keys ]]; then
      print -r -- "$(printf 'LYRICS\t%s\t-\tnone\tartist has no key long enough to match lrclib: %s' "$file" "$artist")"
      (( none++ ))
      continue
    fi

    slug=$(print -r -- "$artist - $title" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/^-//; s/-$//')
    out="$stage/${slug}.txt"

    if (( ! force )) && [[ -s $out ]]; then
      print -r -- "$(printf 'LYRICS\t%s\t%s\tcached\tstaged earlier (--force to refetch)' "$file" ".mtag-lyrics/${slug}.txt")"
      (( cached++ ))
      continue
    fi

    if ! json=$(lrclib_search "$artist" "$title"); then
      print -r -- "$(printf 'LYRICS\t%s\t-\terror\tlrclib request failed: %s' "$file" "${json//$'\n'/ }")"
      (( errored++ ))
      continue
    fi
    json_all=$json
    lrclib_match "$json" "$title" "$keys" "$fdur" "$TOL_PERFORMER"
    verdict=${match_reply[1]}
    detail=${match_reply[8]}

    # credit split. LRCLIB indexes one artist ("T.R.I", "Thùy Chi"), the tag carries
    # the whole credit, and a title-only search is capped at 20 hits -- so common
    # titles ("Mưa") bury the right record. Phase A: title only, which is what finds
    # "(S)TRONG" and "T.R.I". Phase B: each collaborator as the artist query.
    arr_plain=''
    arr_detail=''
    adiff=''
    arecords=0
    arr_qt=''
    if [[ $verdict != match ]]; then
      for qt in "${(@f)$(title_forms "$title")}"; do
        [[ $verdict == match ]] && break
        json_t=$(lrclib_search_title "$qt") || continue
        json_all=$(merge_json "$json_all" "$json_t") || :
        pursue_match "$json_all" "$qt" "$keys" "$fdur"
        if [[ $pursue_status == match ]]; then
          verdict=match
          detail="$pursue_detail (artist credit split)"
          arr_plain=''
          break
        fi
        if [[ $pursue_status == wide ]] && { [[ -z $arr_detail ]] || awk -v a="$pursue_diff" -v b="$adiff" 'BEGIN{exit !(a < b)}'; }; then
          arr_plain=$pursue_plain
          arr_detail=$pursue_detail
          adiff=$pursue_diff
          arecords=$pursue_records
          arr_qt=$qt
        fi
      done
    fi

    if [[ $verdict != match && -z $arr_detail ]]; then
      for qa in "${(@f)$(artist_forms "$artist")}"; do
        [[ $verdict == match ]] && break
        [[ $qa == "$artist" ]] && continue
        for qt in "${(@f)$(title_forms "$title")}"; do
          [[ $verdict == match ]] && break
          json_a=$(lrclib_search "$qa" "$qt") || continue
          json_all=$(merge_json "$json_all" "$json_a") || :
          pursue_match "$json_all" "$qt" "$keys" "$fdur"
          if [[ $pursue_status == match ]]; then
            verdict=match
            detail="$pursue_detail (artist credit split, queried $qa)"
            arr_plain=''
            break
          fi
          if [[ $pursue_status == wide ]] && { [[ -z $arr_detail ]] || awk -v a="$pursue_diff" -v b="$adiff" 'BEGIN{exit !(a < b)}'; }; then
            arr_plain=$pursue_plain
            arr_detail=$pursue_detail
            adiff=$pursue_diff
            arecords=$pursue_records
            arr_qt=$qt
          fi
        done
      done
    fi

    # origin fallback for covers
    if [[ $verdict != match ]]; then
      origin=$(origin_artist "$artist")
      if [[ -n $origin ]]; then
        if json=$(lrclib_search "$origin" "$title"); then
          lrclib_match "$json" "$title" "$(credit_keys "$origin")" "$fdur" "$TOL_ORIGIN"
          if [[ ${match_reply[1]} != none ]]; then
            if [[ ${match_reply[1]} == match ]]; then
              verdict=match
              detail="${match_reply[8]} (via original $origin)"
            else
              verdict=ambiguous
              detail="${match_reply[8]} (via original $origin)"
            fi
          else
            detail="$detail (origin $origin: no exact title match)"
          fi
        else
          detail="$detail (origin lookup failed)"
        fi
      fi
    fi

    # arrangement override: lofi / extended cuts differ from the record by seconds.
    # The cheap rule runs first -- it needs no extra request -- and lyrics.ovh is only
    # asked when two LRCLIB records or a 15s bound are not enough to settle identity.
    if [[ $verdict != match ]] && (( arrangement )) && [[ -n $arr_detail ]]; then
      if awk -v a="$adiff" -v b="$ARRANGEMENT_TIGHT" 'BEGIN{exit !(a <= b)}' && (( arecords >= 2 )); then
        verdict=match
        match_plain=$arr_plain
        detail="$arr_detail (arrangement override, ${adiff}s, $arecords lrclib records)"
        (( overridden++ ))
      else
        score=$(corroborate_text "$artist" "$arr_qt" "$arr_plain")
        if [[ -n $score ]] && awk -v a="$score" -v b="$CORROBORATE_MIN" 'BEGIN{exit !(a >= b)}'; then
          verdict=match
          match_plain=$arr_plain
          detail="$arr_detail (arrangement override, lyrics.ovh agrees $score)"
          (( overridden++ ))
        elif [[ -n $score ]]; then
          verdict=ambiguous
          detail="$arr_detail -- outside the 3s gate, text not corroborated (lyrics.ovh $score)"
        else
          verdict=ambiguous
          detail="$arr_detail -- outside the 3s gate, no corroborating source; stage the text by hand if this version is right"
        fi
      fi
    fi

    case $verdict in
      match)
        mkdir -p "$stage"
        if ! print -r -- "$match_plain" > "$out"; then
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

  print "# lyrics: $matched matched, $cached cached, $ambiguous ambiguous, $none none, $errored errors, $overridden via arrangement"
  (( errored > 0 )) && return 1
  return 0
}

main "$@"
