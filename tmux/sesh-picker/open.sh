#!/usr/bin/env bash
# Given a selected index row (tab-separated), open a new tmux window in the
# session's cwd and resume it live.
#
#   row fields: epoch  date  tool  title  cwd  uuid  path
set -euo pipefail

row="$1"
IFS=$'\t' read -r _epoch _date tool title cwd uuid _path <<< "$row"

[ -d "$cwd" ] || cwd="$HOME"

# Short, readable window name: tool + first word(s) of title.
# NB: tmux forbids ':' in window names (it's the session:window separator).
name=$(printf '%s' "$title" | tr -cd '[:alnum:] _-' | cut -c1-16)
wname="${tool}·${name}"

case "$tool" in
  claude) cmd="claude --resume '$uuid'" ;;
  codex)  cmd="codex resume '$uuid'" ;;
  *)      printf 'unknown tool: %s\n' "$tool" >&2; exit 1 ;;
esac

# Open in a new window in the target directory, running the resume command.
tmux new-window -c "$cwd" -n "$wname" "$cmd"
