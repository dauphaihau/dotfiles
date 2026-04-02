# download audio as mp3
dlm() { yt-dlp -x --audio-format mp3 "$1" }

# download video: download video as mp4 (best h264 quality) + embed caption as Finder comment
dlv() {
  local url="$1"
  local desc
  desc=$(yt-dlp \
    --print "%(description)s" \
    --no-download \
    "$url" 2>/dev/null)

  local -a args=(
    -f "bestvideo[vcodec^=avc]+bestaudio/best"  # best h264 video + best audio
    --merge-output-format mp4                   # mux into mp4 container
    --embed-metadata                            # embed title/uploader/etc into file
    --add-metadata                              # write metadata tags (date, description…)
    --no-write-description                      # skip writing a separate .description file
    -o "%(title).100B [%(id)s].%(ext)s"         # truncate title to 100 bytes to avoid long filename errors
    --print after_move:filepath                 # print final filepath after download+merge
  )

  yt-dlp "${args[@]}" "$url" | while read -r filepath; do
      if [[ -n "$desc" ]]; then
        local safe_desc="${desc//\"/\\\"}"
        osascript -e "tell application \"Finder\" to set comment of (POSIX file \"$filepath\" as alias) to \"$safe_desc\""
      fi
    done
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
