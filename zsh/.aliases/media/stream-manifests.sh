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
# usage: dlhls '<m3u8-or-mpd-url>' [N_m3u8DL-RE args...]
# always quote URLs in zsh so ? and & are not parsed by the shell
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
