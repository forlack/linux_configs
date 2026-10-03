#!/usr/bin/env bash
# resurrect post-save hook: record the EXACT Claude/Codex session each pane is
# running, keyed by pane coordinates, so the restore hook can reopen the right
# session per pane — even when several run in the same directory (e.g. ~).
#
# The map is named after the save file it belongs to (sessions-<stamp>.tsv), so
# restoring an OLD snapshot never picks up a newer snapshot's mapping.
#
# Codex >= 0.160 runs turns in a shared app-server daemon that holds every
# rollout .jsonl open, so the TUI's fds say nothing. On Linux, use the newest
# session -> pane entry the Codex hooks cached (tmux/codex-pane.sh), else the id
# in `codex resume <id>`. Otherwise read an open session file from
# /proc/<pid>/fd on Linux or lsof on macOS. The daemon (a child of whichever TUI
# launched it) is skipped so its open rollouts aren't misattributed to that
# pane. With no id, the restore hook falls back to --continue / resume --last.
set -u

RDIR=$(tmux show-option -gqv @resurrect-dir)
if [ -z "$RDIR" ]; then
  if [ -d "$HOME/.tmux/resurrect" ]; then
    RDIR="$HOME/.tmux/resurrect"
  else
    RDIR="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
  fi
fi
RDIR="${RDIR/#\~/$HOME}"
UUID_RE='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'

# Path of the map that pairs with the current "last" save file.
map_path() {
  local base stamp
  base="$(basename "$(readlink "$RDIR/last" 2>/dev/null)" 2>/dev/null)"
  [ -z "$base" ] && base="$(basename "$(ls -t "$RDIR"/tmux_resurrect_*.txt 2>/dev/null | head -1)" 2>/dev/null)"
  [ -z "$base" ] && return 1
  stamp="${base#tmux_resurrect_}"; stamp="${stamp%.txt}"
  echo "$RDIR/sessions-${stamp}.tsv"
}

MAP="$(map_path)" || exit 0
mkdir -p "$RDIR"
tmpfile="$(mktemp)"

CODEX_CACHE="${XDG_RUNTIME_DIR:-/tmp}/codex-tmux-panes"

# Pane process tree, minus Codex's shared app-server daemon and its children.
descendants() {
  local pid="$1" child
  case "$(ps -o args= -p "$pid" 2>/dev/null)" in *codex\ app-server*) return ;; esac
  echo "$pid"
  for child in $(pgrep -P "$pid" 2>/dev/null); do
    descendants "$child"
  done
}

# Print the session id of the Codex TUI among these pids running in pane $1.
codex_session() {
  local pane="$1" pid args start f id=""; shift
  for pid in "$@"; do
    args="$(tr '\0' ' ' 2>/dev/null < /proc/"$pid"/cmdline)" || continue
    case "$args" in */bin/codex|*/bin/codex\ *) ;; *) continue ;; esac
    case "$args" in *codex-code-mode-host*) continue ;; esac
    # Newest hook-cached session for this pane since this TUI started; covers
    # fresh sessions and /new or /resume inside the TUI.
    start=$(( $(date +%s) - $(ps -o etimes= -p "$pid") ))
    f="$(grep -lx -- "$pane" "$CODEX_CACHE"/* 2>/dev/null | xargs -r ls -t 2>/dev/null | head -1)"
    if [ -n "$f" ] && [ "$(stat -c %Y "$f")" -ge "$start" ]; then
      id="$(basename "$f")"
    else
      id="$(grep -oE " resume $UUID_RE" <<<"$args" | grep -oE "$UUID_RE")"
    fi
    [ -n "$id" ] && { echo "$id"; return 0; }
  done
  return 1
}

# Print "tool<TAB>id" for the first pid whose open fds point at a session file.
session_files() {
  local pid="$1" f
  if [ "$(uname -s)" = Darwin ]; then
    /usr/sbin/lsof -a -p "$pid" -Fn 2>/dev/null | sed -n 's/^n//p'
  else
    for f in /proc/"$pid"/fd/*; do
      readlink "$f" 2>/dev/null || true
    done
  fi
}

open_session() {
  local pid tgt id
  for pid in "$@"; do
    while IFS= read -r tgt; do
      case "$tgt" in
        "$HOME"/.codex/sessions/*rollout-*.jsonl)
          id="$(basename "$tgt" .jsonl | grep -oE "$UUID_RE" | tail -1)"
          [ -n "$id" ] && { printf 'codex\t%s\n' "$id"; return 0; } ;;
        "$HOME"/.claude/projects/*.jsonl)
          case "$tgt" in *subagents*) continue ;; esac
          id="$(basename "$tgt" .jsonl)"
          [ -n "$id" ] && { printf 'claude\t%s\n' "$id"; return 0; } ;;
      esac
    done < <(session_files "$pid")
  done
  return 1
}

tmux list-panes -a -F '#{session_name}	#{window_index}	#{pane_index}	#{pane_pid}	#{pane_current_command}	#{pane_id}' |
while IFS=$'\t' read -r s w p pid cmd pane_id; do
  pids="$(descendants "$pid" | tr '\n' ' ')"
  if id="$(codex_session "$pane_id" $pids)"; then
    tool="codex"
  elif res="$(open_session $pids)"; then
    tool="${res%%$'\t'*}"; id="${res#*$'\t'}"
  else
    tool=""; id=""
    case "$cmd" in
      claude) tool="claude" ;;
      codex) tool="codex" ;;
      node)
        if ps -o args= -p "$(echo "$pids" | tr ' ' ',')" 2>/dev/null | grep -q '\.local/bin/codex'; then
          tool="codex"
        fi ;;
    esac
  fi
  [ -n "$tool" ] && printf '%s\t%s\t%s\t%s\t%s\n' "$s" "$w" "$p" "$tool" "$id" >> "$tmpfile"
done

mv "$tmpfile" "$MAP"

# Prune old maps that no longer have a matching save file.
for m in "$RDIR"/sessions-*.tsv; do
  [ -e "$m" ] || continue
  st="$(basename "$m" .tsv)"; st="${st#sessions-}"
  [ -e "$RDIR/tmux_resurrect_${st}.txt" ] || rm -f "$m"
done
