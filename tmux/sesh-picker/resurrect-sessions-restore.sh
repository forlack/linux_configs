#!/usr/bin/env bash
# resurrect post-restore hook: reopen the exact Claude/Codex session each pane
# was running, using the map written by resurrect-sessions-save.sh.
#
#   map row:  session <TAB> window <TAB> pane <TAB> tool <TAB> id
#
# Exact id -> `claude --resume <id>` / `codex resume <id>`.
# Empty id (claude, which we can't pin exactly) -> `claude --continue`.
set -u

MAP="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect/claude-codex-sessions.tsv"
[ -f "$MAP" ] || exit 0

while IFS=$'\t' read -r s w p tool id; do
  [ -n "${s:-}" ] || continue
  case "$tool" in
    claude) [ -n "$id" ] && cmd="claude --resume $id" || cmd="claude --continue" ;;
    codex)  [ -n "$id" ] && cmd="codex resume $id"    || cmd="codex resume --last" ;;
    *) continue ;;
  esac
  # Only send if the target pane exists (best effort; ignore if layout differs).
  if tmux list-panes -t "$s:$w" -F '#{pane_index}' 2>/dev/null | grep -qx "$p"; then
    tmux send-keys -t "$s:$w.$p" "$cmd" C-m
  fi
done < "$MAP"
