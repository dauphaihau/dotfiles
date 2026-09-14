#!/usr/bin/env zsh
# music-tagger: inventory audio files in a folder.
#
# usage: scan.sh <dir> [--recursive]
#
# output: comment header, then one TSV row per file:
#   FILE  EXT  TITLE  ARTIST  DURATION  SIZE
# FILE is relative to <dir>; missing tags are empty fields.

emulate -L zsh

main() {
  setopt pipe_fail

  if (( $# < 1 )); then
    print -u2 "usage: scan.sh <dir> [--recursive]"
    return 2
  fi

  local dir=$1
  local recursive=0
  [[ $2 == -r || $2 == --recursive ]] && recursive=1

  if [[ ! -d $dir ]]; then
    print -u2 "scan.sh: not a directory: $dir"
    return 2
  fi

  local cmd
  for cmd in ffprobe jq; do
    command -v $cmd >/dev/null || { print -u2 "scan.sh: $cmd not found in PATH"; return 3 }
  done

  dir=${dir:A}

  local -a files
  if (( recursive )); then
    files=("$dir"/**/*(N.))
  else
    files=("$dir"/*(N.))
  fi

  local f ext rel row title artist dur size secs size_bytes
  local -a parts
  local -a out=()
  local -a imgs=()

  for f in "${files[@]}"; do
    ext=${f:e:l}
    rel=${f#$dir/}
    case $ext in
      mp3|flac|m4a|aac|wav|ogg|opus|aiff) ;;
      jpg|jpeg|png|webp) imgs+=("$rel"); continue ;;
      *) continue ;;
    esac

    row=$(ffprobe -v quiet -print_format json -show_format -- "$f" 2>/dev/null \
          | jq -r '[.format.tags.title // "", .format.tags.artist // "", .format.duration // ""] | @tsv' 2>/dev/null)

    title=""
    artist=""
    dur=""
    if [[ -n $row ]]; then
      parts=("${(@ps:\t:)row}")
      title=${parts[1]}
      artist=${parts[2]}
      dur=${parts[3]}
    fi

    secs=${dur%%.*}
    if [[ $secs == <-> ]]; then
      dur=$(printf '%d:%02d' $(( secs / 60 )) $(( secs % 60 )))
    else
      dur=""
    fi

    size_bytes=$(stat -f %z "$f" 2>/dev/null)
    out+=("$(printf '%s\t%s\t%s\t%s\t%s\t%s' "$rel" "$ext" "$title" "$artist" "$dur" "$size_bytes")")
  done

  print "# music-tagger scan  $(date '+%Y-%m-%dT%H:%M:%S')"
  print "# dir: $dir"
  print "# columns: FILE<TAB>EXT<TAB>TITLE<TAB>ARTIST<TAB>DURATION<TAB>SIZE"
  print "# files: ${#out}"
  print "# images: ${#imgs}"
  for f in "${imgs[@]}"; do
    print "# image: $f"
  done
  print "#"
  for row in "${out[@]}"; do
    print -r -- "$row"
  done

  return 0
}

main "$@"
