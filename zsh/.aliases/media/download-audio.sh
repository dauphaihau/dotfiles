# download audio as mp3, optionally clipping with --range "*MM:SS-HH:MM:SS" or "*MM:SS-inf"
dla() {
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

  if [[ "$url" == *"youtube.com"* || "$url" == *"youtu.be"* ]] && [[ $has_cookie_args -eq 0 ]]; then
    auth_args+=(--cookies-from-browser firefox)
  fi

  local -a args=(
    -x
    --audio-format mp3
  )

  [[ -n "$range" ]] && args+=(--download-sections "$range" --force-keyframes-at-cuts)
  args+=("${auth_args[@]}")
  args+=("${extra_args[@]}")

  yt-dlp "${args[@]}" "$url"
}

alias dlm='noglob dlm'
