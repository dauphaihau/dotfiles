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
# usage: dlhls '<m3u8-or-mpd-url>' [-n 'Save Name'] [N_m3u8DL-RE args...]
# example: dlhls 'https://example.com/master.m3u8?token=abc&expires=123' -n 'Episode 01' -M format=mp4
# always quote URLs in zsh so ? does not glob and & does not background the command
_dlhls_has_mux_args() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      -M|--mux-after-done)
        return 0
        ;;
    esac
  done

  return 1
}

_dlhls_fix_mp4_audio_compat() {
  local filepath="$1"
  [[ -z "$filepath" || ! -f "$filepath" ]] && return 0
  [[ "${filepath##*.}" != "mp4" ]] && return 0

  if ! command -v ffprobe >/dev/null 2>&1 || ! command -v ffmpeg >/dev/null 2>&1; then
    return 0
  fi

  local acodec=""
  acodec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$filepath" 2>/dev/null)

  [[ "$acodec" != "mp3" ]] && return 0

  local compat_tmp="${filepath%.mp4}_aac.mp4"
  echo "normalizing audio to AAC for better MP4 player compatibility: $filepath"

  ffmpeg -y -loglevel error -i "$filepath" \
    -c:v copy \
    -c:a aac -b:a 192k \
    "$compat_tmp" && command mv -f "$compat_tmp" "$filepath"
}

# dlhls = download HTTP Live Streaming manifests (.m3u8); also works with DASH/ISM manifests
dlhls() {
  local url="$1"
  [[ -z "$url" ]] && {
    echo "usage: dlhls <m3u8-or-mpd-url> [-n <save-name>] [N_m3u8DL-RE args...]" >&2
    echo "note: quote URLs in zsh, especially when they contain ? or &" >&2
    return 2
  }
  shift

  if ! command -v N_m3u8DL-RE >/dev/null 2>&1; then
    echo "N_m3u8DL-RE is not installed." >&2
    echo "Install it from: https://github.com/nilaoda/N_m3u8DL-RE" >&2
    return 127
  fi

  local save_name=""
  local -a extra_args=()
  local -a save_name_args=()
  local newest_mp4=""
  local start_epoch=$EPOCHSECONDS
  local -a stat_data

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--name)
        if [[ -z "$2" ]]; then
          echo "missing value for $1" >&2
          return 2
        fi
        save_name="$2"
        shift 2
        ;;
      *)
        extra_args+=("$1")
        shift
        ;;
    esac
  done

  if ! _dlhls_has_mux_args "${extra_args[@]}"; then
    extra_args+=(-M format=mp4)
  fi

  [[ -n "$save_name" ]] && save_name_args=(--save-name "$save_name")

  N_m3u8DL-RE \
    "$url" \
    --auto-select \
    --save-dir . \
    "${save_name_args[@]}" \
    "${extra_args[@]}"

  local exit_code=$?
  (( exit_code == 0 )) || return "$exit_code"

  newest_mp4=(*.mp4(N.om[1]))
  if [[ -n "$newest_mp4" ]]; then
    zmodload zsh/stat 2>/dev/null || true
    if zstat -A stat_data +mtime -- "$newest_mp4" 2>/dev/null && (( stat_data[1] >= start_epoch )); then
      _dlhls_fix_mp4_audio_compat "$newest_mp4"
    fi
  fi
}
