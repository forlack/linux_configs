#!/usr/bin/env bash
# Content search: given a query, find sessions whose transcript body contains it
# and emit their index rows (so display/preview/open all keep working).
#
# Usage: search_content.sh <query>
# With an empty query, returns the full index (all sessions).
set -euo pipefail

q="${1:-}"
CACHE="$HOME/.cache/sesh-picker/index.tsv"

if [ -z "$q" ]; then
  cat "$CACHE"
  exit 0
fi

# Session files whose raw content matches (literal, case-insensitive).
# -l stops at first hit per file, so this stays fast even on huge sessions.
matches=$(rg -l -i -F --no-messages -- "$q" \
  "$HOME/.claude/projects" "$HOME/.codex/sessions" 2>/dev/null || true)
[ -z "$matches" ] && exit 0

# Keep only index rows whose path (field 7) matched, preserving recency order.
awk -F'\t' 'NR==FNR{want[$0]=1; next} ($7 in want)' \
  <(printf '%s\n' "$matches") "$CACHE"
