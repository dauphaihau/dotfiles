#!/usr/bin/env bash
# Policy: Enforce Package Manager
# Blocks npm in repos that use pnpm and suggests the replacement.
 
set -euo pipefail
cmd=$(jq -r '.tool_input.command // ""')

if [ -f pnpm-lock.yaml ] && echo "$cmd" | grep -Eq '\bnpm\b'; then
  echo "This repo uses pnpm. Replace 'npm' with 'pnpm' (e.g., 'pnpm install', 'pnpm run <script>')." 1>&2
  exit 2
fi

if [ -f bun.lockb ] || [ -f bun.lock ]; then
  if echo "$cmd" | grep -Eq '\bnpm\b'; then
    echo "This repo uses bun. Replace 'npm' with 'bun' (e.g., 'bun install', 'bun run <script>')." 1>&2
    exit 2
  fi
fi

exit 0