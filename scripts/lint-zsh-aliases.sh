#!/usr/bin/env zsh

emulate -L zsh -o errexit -o nounset -o pipefail

usage() {
  cat <<'EOF'
Usage: lint-zsh-aliases.sh [options] [file ...]

Lint zsh alias/function definitions for:
  - collisions with existing commands or shell builtins
  - duplicate definitions
  - risky overrides of common shell tools

If no files are provided, the script scans:
  - ~/.zshrc
  - ~/.aliases/*.sh

Options:
  --allow NAME    Ignore collisions and risky override warnings for NAME
  -h, --help      Show this help
EOF
}

typeset -a input_files allowlist
typeset -A allow_map risky_names seen
typeset -i total=0 warnings=0 errors=0

while (( $# > 0 )); do
  case "$1" in
    --allow)
      if (( $# < 2 )); then
        echo "missing value for --allow" >&2
        exit 2
      fi
      allowlist+=("$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      input_files+=("$1")
      shift
      ;;
  esac
done

if (( ${#input_files[@]} == 0 )); then
  input_files+=("$HOME/.zshrc")
  if [[ -d "$HOME/.aliases" || -L "$HOME/.aliases" ]]; then
    input_files+=("$HOME"/.aliases/*.sh(N))
  fi
fi

for name in "${allowlist[@]}"; do
  allow_map["$name"]=1
done

risky_names=(
  awk 1
  cat 1
  cd 1
  cp 1
  df 1
  dig 1
  find 1
  grep 1
  less 1
  ls 1
  man 1
  mv 1
  open 1
  ping 1
  ps 1
  rm 1
  sed 1
  source 1
  time 1
)

tmp_defs="$(mktemp)"
trap 'rm -f "$tmp_defs"' EXIT

for file in "${input_files[@]}"; do
  [[ -f "$file" ]] || continue
  perl -ne '
    if (/^[ \t]*alias[ \t]+([A-Za-z0-9_.:+-]+)=/) {
      print "$1\talias\t$ARGV\t$.\n";
      next;
    }
    if (/^[ \t]*function[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]*(?:\(\))?[ \t]*\{?/) {
      print "$1\tfunction\t$ARGV\t$.\n";
      next;
    }
    if (/^[ \t]*([A-Za-z_][A-Za-z0-9_]*)[ \t]*\(\)[ \t]*\{/) {
      print "$1\tfunction\t$ARGV\t$.\n";
    }
  ' "$file" >> "$tmp_defs"
done

if [[ ! -s "$tmp_defs" ]]; then
  echo "No alias or function definitions found."
  exit 0
fi

printf 'Scanning %d file(s)\n' "${#input_files[@]}"

while IFS=$'\t' read -r name kind file line; do
  (( total += 1 ))

  if [[ -n "${seen[$name]:-}" ]]; then
    (( warnings += 1 ))
    printf 'WARN  duplicate %-8s %-20s at %s:%s (first at %s)\n' \
      "$kind" "$name" "$file" "$line" "${seen[$name]}"
  else
    seen["$name"]="$file:$line"
  fi

  if [[ -n "${allow_map[$name]:-}" ]]; then
    continue
  fi

  whence_line="$(whence -w -- "$name" 2>/dev/null || true)"
  type_kind="${whence_line#*: }"

  case "$type_kind" in
    command|builtin|reserved)
      (( errors += 1 ))
      resolved="$(whence -p -- "$name" 2>/dev/null || true)"
      if [[ -z "$resolved" ]]; then
        resolved="$type_kind"
      fi
      printf 'ERROR command collision %-20s (%s) shadows %s at %s:%s\n' \
        "$name" "$kind" "$resolved" "$file" "$line"
      ;;
  esac

  if [[ -n "${risky_names[$name]:-}" ]]; then
    (( warnings += 1 ))
    printf 'WARN  risky override   %-20s (%s) at %s:%s\n' \
      "$name" "$kind" "$file" "$line"
  fi
done < "$tmp_defs"

printf '\nSummary: %d definitions, %d error(s), %d warning(s)\n' \
  "$total" "$errors" "$warnings"

if (( errors > 0 )); then
  exit 1
fi
