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
  local -a auth_args=()
  local has_cookie_args=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --range)
        range="$2"
        shift 2
        ;;
      --cookies|--cookies-from-browser)
        has_cookie_args=1
        extra_args+=("$1")
        [[ -n "$2" ]] && extra_args+=("$2")
        shift 2
        ;;
      *)
        extra_args+=("$1")
        shift
        ;;
    esac
  done

  if [[ "$url" == *"instagram.com"* && $has_cookie_args -eq 0 ]]; then
    auth_args+=(--cookies-from-browser firefox)
  fi

  local desc
  desc=$(yt-dlp \
    "${auth_args[@]}" \
    --print "%(description)s" \
    --no-download \
    "$url" 2>/dev/null)

  local tmpfile
  tmpfile=$(mktemp)

  local -a args=(
    -f "bv*[vcodec^=avc1]+ba/b[ext=mp4]/b"              # prefer Mac-friendly H.264/AAC output
    --merge-output-format mp4                            # mux into mp4 container
    --embed-metadata                                     # embed title/uploader/etc into file
    --add-metadata                                       # write metadata tags (date, description…)
    --no-write-description                               # skip writing a separate .description file
    -o "%(title).100B [%(id)s].%(ext)s"                  # truncate title to 100 bytes to avoid long filename errors
    --print-to-file "after_move:filepath" "$tmpfile"     # write final filepath to temp file
  )

  [[ -n "$range" ]] && args+=(--download-sections "$range" --force-keyframes-at-cuts)
  args+=("${auth_args[@]}")
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

  # QuickTime and Finder previews often fail on VP9/AV1 in MP4; normalize to H.264/AAC.
  if [[ -n "$filepath" ]] && command -v ffprobe >/dev/null 2>&1 && command -v ffmpeg >/dev/null 2>&1; then
    local vcodec=""
    vcodec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$filepath" 2>/dev/null)

    if [[ "$vcodec" == "vp9" || "$vcodec" == "av1" ]]; then
      local compat_tmp="${filepath%.mp4}_h264.mp4"
      ffmpeg -y -loglevel error -i "$filepath" \
        -c:v libx264 -preset medium -crf 23 \
        -c:a aac -b:a 128k \
        "$compat_tmp" && mv "$compat_tmp" "$filepath"
    fi
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
  local -a extra_args=()
  local -a auth_args=()
  local has_cookie_args=0

  if ! command -v gallery-dl >/dev/null 2>&1; then
    echo "gallery-dl is not installed. Install it with: brew install gallery-dl" >&2
    return 127
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cookies|--cookies-from-browser)
        has_cookie_args=1
        extra_args+=("$1")
        [[ -n "$2" ]] && extra_args+=("$2")
        shift 2
        ;;
      *)
        extra_args+=("$1")
        shift
        ;;
    esac
  done

  if [[ "$url" == *"instagram.com"* && $has_cookie_args -eq 0 ]]; then
    auth_args+=(--cookies-from-browser firefox)
  fi

  gallery-dl \
    -D . \
    "${auth_args[@]}" \
    "${extra_args[@]}" \
    "$url"
}

# record live/VOD streams via streamlink
# usage: dls <url> [stream=best] [-o output.ts] [streamlink args...]
dls() {
  local url="$1"
  [[ -z "$url" ]] && {
    echo "usage: dls <url> [stream=best] [-o output.ts] [streamlink args...]" >&2
    return 2
  }
  shift

  if ! command -v streamlink >/dev/null 2>&1; then
    echo "streamlink is not installed. Install it with: brew install streamlink" >&2
    return 127
  fi

  local stream="best"
  local output=""
  local -a extra_args=()

  if [[ $# -gt 0 && "$1" != -* ]]; then
    stream="$1"
    shift
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o|--output)
        output="$2"
        shift 2
        ;;
      *)
        extra_args+=("$1")
        shift
        ;;
    esac
  done

  [[ -z "$output" ]] && output="stream-$(date +%Y%m%d-%H%M%S).ts"

  streamlink \
    --output "$output" \
    "${extra_args[@]}" \
    "$url" \
    "$stream"
}

# probe downloader support for a video page URL
# usage: probevid <url>
probevid() {
  local url="$1"
  [[ -z "$url" ]] && {
    echo "usage: probevid <url>" >&2
    return 2
  }

  local yt_ok=0
  local sl_ok=0

  if command -v yt-dlp >/dev/null 2>&1; then
    if yt-dlp --simulate --skip-download "$url" >/dev/null 2>&1; then
      yt_ok=1
      echo "yt-dlp: supported"
    else
      echo "yt-dlp: unsupported"
    fi
  else
    echo "yt-dlp: not installed"
  fi

  if command -v streamlink >/dev/null 2>&1; then
    if streamlink --can-handle-url "$url" >/dev/null 2>&1; then
      sl_ok=1
      echo "streamlink: supported"
    else
      echo "streamlink: unsupported"
    fi
  else
    echo "streamlink: not installed"
  fi

  if (( yt_ok )); then
    echo "next: use dlv \"$url\""
    return 0
  fi

  if (( sl_ok )); then
    echo "next: use dls \"$url\""
    return 0
  fi

  cat <<EOF
next: neither tool recognizes the page URL
look in browser DevTools Network for:
  - .m3u8
  - .mpd
  - direct .mp4
then download the direct stream URL with:
  N_m3u8DL-RE "<m3u8-or-mpd-url>" --auto-select
or:
  curl -L -O "<direct-mp4-url>"
EOF

  return 1
}

# download direct HLS/DASH/MSS manifests via N_m3u8DL-RE
# usage: dlhls <m3u8-or-mpd-url> [N_m3u8DL-RE args...]
dlhls() {
  local url="$1"
  [[ -z "$url" ]] && {
    echo "usage: dlhls <m3u8-or-mpd-url> [N_m3u8DL-RE args...]" >&2
    return 2
  }
  shift

  if ! command -v N_m3u8DL-RE >/dev/null 2>&1; then
    echo "N_m3u8DL-RE is not installed." >&2
    echo "Install it from: https://github.com/nilaoda/N_m3u8DL-RE" >&2
    return 127
  fi

  N_m3u8DL-RE \
    "$url" \
    --auto-select \
    --save-dir . \
    "$@"
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
