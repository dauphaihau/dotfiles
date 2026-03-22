#!/usr/bin/env bash
# Log Bash Commands for Audit
# Writes each Bash command to a log file with timestamps.

set -euo pipefail
cmd=$(jq -r '.tool_input.command // ""')
mkdir -p .claude
printf '%s %s\n' "$(date -Is)" "$cmd" >> .claude/bash-commands.log
exit 0