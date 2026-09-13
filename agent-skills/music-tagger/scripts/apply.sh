#!/usr/bin/env zsh
# music-tagger: apply a proposal produced by the music-tagger skill.
#
# usage: apply.sh <proposal.md> [--yes]
#   default (no --yes) is a dry run: prints planned actions, changes nothing.
#
# proposal format: a Markdown table. Non-table lines (title, prose, blanks) are
# ignored, so the file can be read and edited as ordinary Markdown.
#
#   - dir: /abs/path/to/folder
#
#   | STATUS | FILE | TITLE | ARTIST | LYRICS | IMAGE | CONF | NOTE |
#   | --- | --- | --- | --- | --- | --- | --- | --- |
#   | OK | messy name.mp3 | Real Title | Real Artist | - | covers/real-title.jpg | high | split |
#
#   STATUS      OK | SKIP | ASK | UNSUPPORTED   (only OK is applied)
#   FILE        audio path relative to the 'dir:' header
#   TITLE       new title, or '-' / empty to leave unchanged
#   ARTIST      new artist, or '-' / empty to leave unchanged
#   LYRICS      plain-text lyrics file to embed, relative to 'dir:' (absolute
#               paths also work), or '-' / empty for no lyrics
#   IMAGE       cover image supplied by the user, relative to 'dir:' (absolute
#               also works), or '-' / empty for none. Always embedded as
#               FRONT_COVER; one image per file.
#   CONF, NOTE  informational only
#
# Every row must have exactly 8 cells. Cell padding is trimmed, so the table may
# be aligned or not. A literal '|' inside a value shifts the cells, so such rows
# must be written as ASK rather than OK. A ':' in an image path is rejected:
# mtag builds "--add-image <path>:FRONT_COVER" and a colon would split it wrong.
#
# Tagging uses the user's `mtag` zsh function, which also renames to "<title>.mp3".
# Rows where that rename would clobber an existing file, or would be a no-op,
# fall back to `eyeD3 --title/--artist/--add-lyrics/--add-image` so the filename
# is left alone. Lyrics staged under the proposal folder's .mtag-lyrics/ are
# deleted after they are embedded and verified; any other file is never touched.

emulate -L zsh
source "${0:A:h}/lib.zsh"

main() {
  setopt pipe_fail

  if (( $# < 1 )); then
    print -u2 "usage: apply.sh <proposal.md> [--yes]"
    return 2
  fi

  local proposal=$1
  local execute=0
  [[ $2 == --yes || $2 == -y ]] && execute=1

  if [[ ! -f $proposal ]]; then
    print -u2 "apply.sh: no such proposal: $proposal"
    return 2
  fi

  local cmd
  for cmd in ffprobe jq; do
    command -v $cmd >/dev/null || { print -u2 "apply.sh: $cmd not found in PATH"; return 3 }
  done

  local dir
  dir=$(proposal_dir "$proposal")
  if [[ -z $dir || ! -d $dir ]]; then
    print -u2 "apply.sh: proposal has no usable 'dir: <path>' header"
    return 2
  fi
  dir=${dir:A}

  local bad
  bad=$(proposal_bad_rows "$proposal")
  if [[ -n $bad ]]; then
    print -u2 "apply.sh: malformed table row (need $PROPOSAL_CELLS cells): $bad"
    return 2
  fi

  local have_mtag=0
  if [[ -r $HOME/.aliases/media/tag-audio.sh ]]; then
    source "$HOME/.aliases/media/tag-audio.sh"
    (( ${+functions[mtag]} )) && have_mtag=1
  fi

  if (( execute )); then
    print "# music-tagger apply  dir: $dir"
  else
    print "# music-tagger apply (DRY RUN, nothing is written)  dir: $dir"
  fi
  print "# tagger: $( (( have_mtag )) && print mtag || print 'eyeD3 (mtag not found)' )"

  local stage="$dir/.mtag-lyrics"
  local line state file title artist lyrics image ipath sanitized mode action readpath target src
  local got got_title got_artist got_lyrics got_art had_art replaced
  local ext
  local applied=0 skipped=0 failed=0 planned=0
  local -a reply tagargs
  local -a staged_clean=()

  while IFS= read -r line; do
    proposal_parse_row "$line" || continue

    state=$(trim "${reply[1]}")
    proposal_row_is_data "$state" || continue

    file=$(trim "${reply[2]}")
    title=$(trim "${reply[3]}")
    artist=$(trim "${reply[4]}")
    lyrics=$(trim "${reply[5]}")
    image=$(trim "${reply[6]}")

    if [[ $state != OK ]]; then
      print -r -- "SKIP     $state  $file"
      (( skipped++ ))
      continue
    fi

    [[ $title == '-' ]] && title=""
    [[ $artist == '-' ]] && artist=""
    [[ $lyrics == '-' ]] && lyrics=""
    [[ $image == '-' ]] && image=""

    if [[ -z $title && -z $artist && -z $lyrics && -z $image ]]; then
      print -u2 "ERROR    nothing to set: $file"
      (( failed++ ))
      continue
    fi

    src="$dir/$file"
    if [[ ! -f $src ]]; then
      print -u2 "ERROR    missing file: $src"
      (( failed++ ))
      continue
    fi

    lpath=""
    if [[ -n $lyrics ]]; then
      if [[ $lyrics == /* ]]; then
        lpath=$lyrics
      else
        lpath="$dir/$lyrics"
      fi
      if [[ ! -f $lpath ]]; then
        print -u2 "ERROR    lyrics file not found: $lpath"
        (( failed++ ))
        continue
      fi
    fi

    ipath=""
    if [[ -n $image ]]; then
      if [[ $image == *:* ]]; then
        print -u2 "ERROR    image path must not contain ':': $image"
        (( failed++ ))
        continue
      fi
      if [[ $image == /* ]]; then
        ipath=$image
      else
        ipath="$dir/$image"
      fi
      if [[ ! -f $ipath ]]; then
        print -u2 "ERROR    image not found: $ipath"
        (( failed++ ))
        continue
      fi
      ext=${ipath:e:l}
      case $ext in
        jpg|jpeg|png|webp) ;;
        *) print -u2 "ERROR    unsupported image type '.$ext': $ipath"; (( failed++ )); continue ;;
      esac
    fi

    sanitized=${title//\//-}
    mode=eyeD3
    readpath=$src
    if [[ -n $title ]]; then
      target="$dir/${sanitized}.mp3"
      if (( have_mtag )) && [[ ${target:l} != ${src:l} && ! -e $target ]]; then
        mode=mtag
        readpath=$target
        action="mtag  (renames to ${sanitized}.mp3)"
      elif [[ ${target:l} == ${src:l} ]]; then
        action="eyeD3 (filename already '${sanitized}.mp3', no rename)"
      elif (( have_mtag )); then
        action="eyeD3 (target '${sanitized}.mp3' exists, no rename)"
      else
        action="eyeD3 (mtag unavailable, no rename)"
      fi
    elif (( have_mtag )); then
      mode=mtag
      action="mtag  (no rename)"
    else
      action="eyeD3 (no title, no rename)"
    fi

    had_art=0
    if [[ -n $ipath ]]; then
      had_art=$(ffprobe -v quiet -print_format json -show_streams -- "$src" 2>/dev/null \
                | jq -r '[.streams[]? | select((.disposition // {}) | .attached_pic == 1)] | length' 2>/dev/null)
      [[ -z $had_art ]] && had_art=0
    fi

    if (( execute )); then
      if [[ $mode == mtag ]]; then
        tagargs=(-f "$src")
        [[ -n $title ]] && tagargs+=(-t "$sanitized")
        [[ -n $artist ]] && tagargs+=(-a "$artist")
        [[ -n $lpath ]] && tagargs+=(-l "$lpath")
        [[ -n $ipath ]] && tagargs+=(-i "$ipath")
        mtag "${tagargs[@]}" || { print -u2 "ERROR    mtag failed: $file"; (( failed++ )); continue }
      else
        tagargs=()
        [[ -n $title ]] && tagargs+=(--title "$sanitized")
        [[ -n $artist ]] && tagargs+=(--artist "$artist")
        [[ -n $lpath ]] && tagargs+=(--add-lyrics "$lpath")
        [[ -n $ipath ]] && tagargs+=(--add-image "$ipath:FRONT_COVER")
        eyeD3 "${tagargs[@]}" -- "$src" >/dev/null || { print -u2 "ERROR    eyeD3 failed: $file"; (( failed++ )); continue }
      fi

      got=$(ffprobe -v quiet -print_format json -show_format -show_streams -- "$readpath" 2>/dev/null \
            | jq -r '{
                title:  (.format.tags.title // ""),
                artist: (.format.tags.artist // ""),
                lyrics: ([ (.format.tags // {}) | to_entries[] | select(.key | startswith("lyrics")) ] | length),
                art:    ([ .streams[]? | select((.disposition // {}) | .attached_pic == 1) ] | length)
              } | "\(.title)\t\(.artist)\t\(.lyrics)\t\(.art)"' 2>/dev/null)
      reply=("${(@ps:\t:)got}")
      got_title=${reply[1]}
      got_artist=${reply[2]}
      got_lyrics=${reply[3]}
      got_art=${reply[4]}

      if [[ -n $title && $got_title != $sanitized ]] || [[ -n $artist && $got_artist != $artist ]]; then
        print -u2 "ERROR    readback mismatch: $file -> title='$got_title' artist='$got_artist'"
        (( failed++ ))
        continue
      fi
      if [[ -n $lpath && ${got_lyrics:-0} -lt 1 ]]; then
        print -u2 "ERROR    lyrics not embedded: $file"
        (( failed++ ))
        continue
      fi
      if [[ -n $ipath && ${got_art:-0} -lt 1 ]]; then
        print -u2 "ERROR    cover image not embedded: $file"
        (( failed++ ))
        continue
      fi
      if [[ -n $lpath && $lpath == "$stage/"* ]]; then
        staged_clean+=("$lpath")
      fi

      renamed=""
      [[ $readpath != $src ]] && renamed="  =>  ${readpath:t}"
      replaced=""
      (( had_art > 0 )) && [[ -n $ipath ]] && replaced=" (replaced existing cover)"
      print -r -- "OK       $file$renamed   [title='${title:+$sanitized}' artist='$artist'${lpath:+ lyrics='$lyrics'}${ipath:+ image='$image'}$replaced]"
      (( applied++ ))
    else
      print -r -- "WOULD    $file  ->  title='${title:+$sanitized}' artist='$artist'${lpath:+ lyrics='$lyrics'}${ipath:+ image='$image'}   [$action]"
      (( planned++ ))
    fi
  done < "$proposal"

  if (( execute )); then
    local p
    for p in "${staged_clean[@]}"; do
      rm -f -- "$p"
    done
    [[ -d $stage ]] && rmdir "$stage" 2>/dev/null
  fi

  if (( execute )); then
    print "# applied: $applied  skipped: $skipped  failed: $failed"
  else
    print "# would apply: $planned  skipped: $skipped  failed: $failed"
    print "# re-run with --yes to execute"
  fi

  (( failed > 0 )) && return 1
  return 0
}

main "$@"
