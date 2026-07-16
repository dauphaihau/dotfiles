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
