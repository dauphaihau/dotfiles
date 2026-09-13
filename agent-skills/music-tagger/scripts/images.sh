#!/usr/bin/env zsh
# music-tagger: fill the IMAGE cells of a proposal from a folder of images.
#
# usage: images.sh <proposal.md> <image-dir> [--yes]
#   default is a dry run: prints the proposed mapping, writes nothing.
#
# Why this exists: naming every cover after its track is tedious, so you can dump
# numbered images in a folder and let this fill the table. The proposal itself
# still ends up with explicit paths per row -- a number is never stored in the
# table, because a positional value would silently re-point every cover as soon
# as a row is added, removed, reordered, or flipped to SKIP.
#
# Ordering of the images in <image-dir> (non-hidden files, jpg/jpeg/png/webp):
#   * names that are entirely digits sort first, numerically: 1.jpg, 2.jpg, ... 10.jpg
#   * everything else sorts after them, lexicographically
# Targets are the OK rows whose IMAGE cell is empty or '-', in table order.
# The image count must equal the target count: a mismatch is an error, never a
# guess. No image is downloaded, fuzzily matched, renamed, or deleted.

emulate -L zsh
source "${0:A:h}/lib.zsh"

main() {
  setopt pipe_fail

  if (( $# < 2 )); then
    print -u2 "usage: images.sh <proposal.md> <image-dir> [--yes]"
    return 2
  fi

  local proposal=$1 imagedir=$2
  local write=0
  [[ $3 == --yes || $3 == -y ]] && write=1

  if [[ ! -f $proposal ]]; then
    print -u2 "images.sh: no such proposal: $proposal"
    return 2
  fi
  if [[ ! -d $imagedir ]]; then
    print -u2 "images.sh: not a directory: $imagedir"
    return 2
  fi
  imagedir=${imagedir:A}

  local dir
  dir=$(proposal_dir "$proposal")
  if [[ -z $dir || ! -d $dir ]]; then
    print -u2 "images.sh: proposal has no usable 'dir: <path>' header"
    return 2
  fi
  dir=${dir:A}

  local bad
  bad=$(proposal_bad_rows "$proposal")
  if [[ -n $bad ]]; then
    print -u2 "images.sh: malformed table row (need $PROPOSAL_CELLS cells): $bad"
    return 2
  fi

  local f base stem key
  local -a keys=()
  for f in "$imagedir"/*(N.); do
    case ${f:e:l} in
      jpg|jpeg|png|webp) ;;
      *) continue ;;
    esac
    base=${f:t}
    stem=${base:r}
    if [[ $stem == <-> ]]; then
      key=$(printf '0 %010d' "$stem")
    else
      key="1 $stem"
    fi
    keys+=("${key}"$'\t'"${f}")
  done

  local -a images=()
  if (( ${#keys} )); then
    images=("${(@f)$(print -rl -- "${keys[@]}" | LC_ALL=C sort | cut -f2-)}")
  fi

  local -a lines=("${(@f)$(<"$proposal")}")
  local -a targets=()
  local i state file title image
  local -a reply
  for (( i = 1; i <= $#lines; i++ )); do
    proposal_parse_row "${lines[i]}" || continue
    state=$(trim "${reply[1]}")
    proposal_row_is_data "$state" || continue
    [[ $state == OK ]] || continue
    image=$(trim "${reply[6]}")
    [[ -n $image && $image != '-' ]] && continue
    targets+=("$i")
  done

  if (( ${#targets} == 0 )); then
    print "# images: every OK row already has an IMAGE cell, nothing to fill"
    return 0
  fi

  if (( ${#images} != ${#targets} )); then
    print -u2 "images.sh: refusing to guess: ${#images} image(s) in $imagedir, ${#targets} OK row(s) to fill"
    print -u2 "images.sh: rows waiting:"
    for i in "${targets[@]}"; do
      proposal_parse_row "${lines[i]}"
      print -u2 "  $(trim "${reply[2]}")  <- $(trim "${reply[3]}")"
    done
    print -u2 "images.sh: images found:"
    for f in "${images[@]}"; do
      print -u2 "  ${f:t}"
    done
    return 2
  fi

  local rel c
  local -a cells
  for (( i = 1; i <= ${#targets}; i++ )); do
    proposal_parse_row "${lines[${targets[i]}]}"
    file=$(trim "${reply[2]}")
    title=$(trim "${reply[3]}")
    f=${images[i]}
    if [[ $f == "$dir/"* ]]; then
      rel=${f#$dir/}
    else
      rel=$f
    fi
    print -r -- "$(printf 'IMAGE\t%s\t%s\t%s' "$file" "$rel" "$title")"

    reply[6]=$rel
    cells=()
    for c in "${reply[@]}"; do
      cells+=("$(trim "$c")")
    done
    lines[${targets[i]}]="| ${(j: | :)cells[@]} |"
  done

  if (( write )); then
    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/music-tagger-images.XXXXXX") || { print -u2 "images.sh: cannot create temp file"; return 3 }
    print -rl -- "${lines[@]}" > "$tmp" || { rm -f -- "$tmp"; return 3 }
    mv -- "$tmp" "$proposal" || { rm -f -- "$tmp"; return 3 }
    print "# images: wrote ${#targets} path(s) into ${proposal:t}"
  else
    print "# images: ${#targets} path(s) would be written; re-run with --yes"
  fi

  return 0
}

main "$@"
