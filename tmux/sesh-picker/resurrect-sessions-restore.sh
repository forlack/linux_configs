#!/usr/bin/env bash
# resurrect post-restore hook: reopen the exact Claude/Codex session each pane
# was running, using the map that pairs with the snapshot being restored.
#
#   map row:  session <TAB> window <TAB> pane <TAB> tool <TAB> id
#
# Exact id -> `claude --resume <id>` / `codex resume <id>`.
# Empty id (claude, which we can't pin exactly) -> `claude --continue`.
#
# Safety: only send into a pane that is currently a bare shell, so we never
# clobber a pane resurrect restored with another program, and never double-fire.
set -u

RDIR="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"

# The map for the snapshot that was just restored (resurrect restores "last").
base="$(basename "$(readlink "$RDIR/last" 2>/dev/null)" 2>/dev/null)"
[ -z "$base" ] && exit 0
stamp="${base#tmux_resurrect_}"; stamp="${stamp%.txt}"
MAP="$RDIR/sessions-${stamp}.tsv"
[ -f "$MAP" ] || exit 0    # no map for this snapshot -> do nothing (safe)

while IFS=$'\t' read -r s w p tool id; do
  [ -n "${s:-}" ] || continue
  case "$tool" in
    claude) [ -n "$id" ] && cmd="claude --resume $id" || cmd="claude --continue" ;;
    codex)  [ -n "$id" ] && cmd="codex resume $id"    || cmd="codex resume --last" ;;
    *) continue ;;
  esac
  # Only act if the target pane exists AND is an idle shell.
  cur="$(tmux display-message -p -t "$s:$w.$p" '#{pane_current_command}' 2>/dev/null)" || continue
  case "$cur" in
    fish|bash|zsh|sh|dash|ksh) tmux send-keys -t "$s:$w.$p" "$cmd" C-m ;;
    *) : ;;   # something already running here — leave it alone
  esac
done < "$MAP"
