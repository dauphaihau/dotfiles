# merge video files
# default mode re-encodes for reliability across mismatched inputs
# usage: mergev output.mp4 input1.mp4 input2.mp4 [input3.mp4 ...]
# usage: mergev --copy output.mp4 input1.mp4 input2.mp4 [input3.mp4 ...]
mergev() {
  local mode="reencode"

  case "$1" in
    --copy)
      mode="copy"
      shift
      ;;
    --reencode)
      shift
      ;;
  esac

  local output="$1"
  shift

  if [[ -z "$output" || $# -lt 2 ]]; then
    echo "usage: mergev [--copy|--reencode] output.mp4 input1.mp4 input2.mp4 [input3.mp4 ...]" >&2
    return 2
  fi

  if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "ffmpeg is not installed. Install it with: brew install ffmpeg" >&2
    return 127
  fi

  if [[ "$mode" == "reencode" ]] && ! command -v ffprobe >/dev/null 2>&1; then
    echo "ffprobe is not installed. Install it with: brew install ffmpeg" >&2
    return 127
  fi

  local list_file
  list_file="$(mktemp)"

  local file escaped_file
  local video_duration audio_duration segment_duration
  local -a input_args=()
  local -a filter_parts=()
  local -a concat_refs=()
  local index=0
  for file in "$@"; do
    if [[ ! -f "$file" ]]; then
      echo "file not found: $file" >&2
      rm -f "$list_file"
      return 1
    fi

    escaped_file="${file:A}"
    escaped_file="${escaped_file//\'/\'\\\'\'}"
    printf "file '%s'\n" "$escaped_file" >> "$list_file"

    input_args+=(-i "$file")

    if [[ "$mode" == "reencode" ]]; then
      video_duration="$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=nw=1:nk=1 "$file" | head -n 1)"
      audio_duration="$(ffprobe -v error -select_streams a:0 -show_entries stream=duration -of default=nw=1:nk=1 "$file" | head -n 1)"

      if [[ -z "$video_duration" || -z "$audio_duration" ]]; then
        echo "could not read video/audio duration for: $file" >&2
        rm -f "$list_file"
        return 1
      fi

      segment_duration="$(awk -v v="$video_duration" -v a="$audio_duration" 'BEGIN { print (v < a ? v : a) }')"

      filter_parts+=("[$index:v]trim=duration=$segment_duration,setpts=PTS-STARTPTS,scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p[v$index]")
      filter_parts+=("[$index:a]atrim=duration=$segment_duration,asetpts=PTS-STARTPTS[a$index]")
    else
      filter_parts+=("[$index:v]setpts=PTS-STARTPTS,scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p[v$index]")
      filter_parts+=("[$index:a]asetpts=PTS-STARTPTS[a$index]")
    fi

    concat_refs+=("[v$index][a$index]")
    index=$((index + 1))
  done

  if [[ "$mode" == "copy" ]]; then
    ffmpeg -y -f concat -safe 0 -i "$list_file" -c copy "$output"
  else
    local filter_complex=""
    local part
    for part in "${filter_parts[@]}"; do
      [[ -n "$filter_complex" ]] && filter_complex="${filter_complex}; "
      filter_complex="${filter_complex}${part}"
    done

    [[ -n "$filter_complex" ]] && filter_complex="${filter_complex}; "
    for part in "${concat_refs[@]}"; do
      filter_complex="${filter_complex}${part}"
    done
    filter_complex="${filter_complex}concat=n=${#concat_refs}:v=1:a=1[v][a]"

    ffmpeg -y "${input_args[@]}" \
      -filter_complex "$filter_complex" \
      -map "[v]" -map "[a]" \
      -c:v libx264 -preset medium -crf 18 \
      -c:a aac -b:a 192k \
      -movflags +faststart \
      "$output"
  fi
  local exit_code=$?

  rm -f "$list_file"
  return $exit_code
}
