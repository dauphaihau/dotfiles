# download audio as mp3, optionally clipping with --range "*MM:SS-HH:MM:SS" or "*MM:SS-inf"
dlm() {
  local url="$1"
  shift
  local range=""
  local -a extra_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --range)
        range="$2"
        shift 2
        ;;
      *)
        extra_args+=("$1")
        shift
        ;;
    esac
  done

  local -a args=(
    -x
    --audio-format mp3
  )

  [[ -n "$range" ]] && args+=(--download-sections "$range" --force-keyframes-at-cuts)
  args+=("${extra_args[@]}")

  yt-dlp "${args[@]}" "$url"
}

# download video: download video as mp4 (best h264 quality) + embed caption as Finder comment
dlv() {
  local url="$1"
  shift
  local range=""
  local -a extra_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --range)
        range="$2"
        shift 2
        ;;
      *)
        extra_args+=("$1")
        shift
        ;;
    esac
  done

  local desc
  desc=$(yt-dlp \
    --print "%(description)s" \
    --no-download \
    "$url" 2>/dev/null)

  local tmpfile
  tmpfile=$(mktemp)

  local -a args=(
    -f "bestvideo[vcodec^=avc]+bestaudio/best"          # best h264 video + best audio
    --merge-output-format mp4                            # mux into mp4 container
    --embed-metadata                                     # embed title/uploader/etc into file
    --add-metadata                                       # write metadata tags (date, description…)
    --no-write-description                               # skip writing a separate .description file
    -o "%(title).100B [%(id)s].%(ext)s"                  # truncate title to 100 bytes to avoid long filename errors
    --print-to-file "after_move:filepath" "$tmpfile"     # write final filepath to temp file
  )

  [[ -n "$range" ]] && args+=(--download-sections "$range" --force-keyframes-at-cuts)
  args+=("${extra_args[@]}")

  yt-dlp "${args[@]}" "$url"

  local filepath
  filepath=$(cat "$tmpfile" 2>/dev/null | tail -1)
  rm -f "$tmpfile"

  # Fix black frames / wrong container duration caused by DASH segment boundaries
  if [[ -n "$range" && -n "$filepath" ]]; then
    local range_stripped="${range#\*}"
    local ts_start="${range_stripped%%-*}"
    local ts_end="${range_stripped##*-}"

    local start_s=0 end_s=0 x
    local -a parts
    parts=(${(s/:/)ts_start})
    for x in $parts; do start_s=$(( start_s * 60 + x )); done
    parts=(${(s/:/)ts_end})
    for x in $parts; do end_s=$(( end_s * 60 + x )); done

    local clip_duration=$(( end_s - start_s ))
    local tmpvid="${filepath%.mp4}_fix.mp4"
    ffmpeg -y -loglevel error -i "$filepath" -t "$clip_duration" -c copy "$tmpvid" \
      && mv "$tmpvid" "$filepath"
  fi

  if [[ -n "$desc" && -n "$filepath" ]]; then
    local safe_desc="${desc//\"/\\\"}"
    osascript -e "tell application \"Finder\" to set comment of (POSIX file \"$filepath\" as alias) to \"$safe_desc\""
  fi
}

# download instagram images/carousels via gallery-dl into the current directory
# usage: dlig <instagram-url> [gallery-dl args...]
# note: private or rate-limited posts usually require browser cookies, e.g.
#   dlig <url> --cookies-from-browser safari
dlig() {
  local url="$1"
  shift

  if ! command -v gallery-dl >/dev/null 2>&1; then
    echo "gallery-dl is not installed. Install it with: brew install gallery-dl" >&2
    return 127
  fi

  gallery-dl \
    -D . \
    "$@" \
    "$url"
}

# set mp3 metadata tags: mtag -f <file> [-t title] [-a artist] [-i image] [-l lyrics]
mtag() {
  local title artist file image lyrics
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t) title="$2";   shift 2 ;;
      -a) artist="$2";  shift 2 ;;
      -f) file="$2";    shift 2 ;;
      -i) image="$2";   shift 2 ;;
      -l) lyrics="$2";  shift 2 ;;
      *)  shift ;;
    esac
  done
  local -a args=()
  [[ -n "$title" ]]  && args+=(--title "$title")
  [[ -n "$artist" ]] && args+=(--artist "$artist")
  [[ -n "$image" ]]  && args+=(--add-image "$image:FRONT_COVER")
  [[ -n "$lyrics" ]] && args+=(--add-lyrics "$lyrics")
  eyeD3 "${args[@]}" "$file"
  if [[ -n "$title" ]]; then
    local dir
    dir=$(dirname "$file")
    mv "$file" "${dir}/${title}.mp3"
  fi
}
