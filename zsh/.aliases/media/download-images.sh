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
