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
    -f "bv*[vcodec^=avc1]+ba/b[ext=mp4]/b"          # prefer Mac-friendly H.264/AAC output
    --merge-output-format mp4                        # mux into mp4 container
    --embed-metadata                                 # embed title/uploader/etc into file
    --add-metadata                                   # write metadata tags (date, description…)
    --no-write-description                           # skip writing a separate .description file
    -o "%(title).100B [%(id)s].%(ext)s"              # truncate title to 100 bytes to avoid long filename errors
    --print-to-file "after_move:filepath" "$tmpfile" # write final filepath to temp file
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
