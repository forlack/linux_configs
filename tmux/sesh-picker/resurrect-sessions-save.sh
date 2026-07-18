#!/usr/bin/env bash
# resurrect post-save hook: record the EXACT Claude/Codex session each pane is
# running, keyed by pane coordinates, so the restore hook can reopen the right
# session per pane — even when several run in the same directory (e.g. ~).
#
# Codex holds its rollout .jsonl open, so we read the exact session id from
# /proc/<pid>/fd. Claude keeps nothing open and exposes no session env var, so
# it's recorded with an empty id and the restore hook falls back to --continue.
set -u

MAP="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect/claude-codex-sessions.tsv"
mkdir -p "$(dirname "$MAP")"
tmpfile="$(mktemp)"

UUID_RE='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'

# All pids in a pane's process tree (shell -> node -> codex binary, etc.).
descendants() {
  local pid="$1" child
  echo "$pid"
  for child in $(pgrep -P "$pid" 2>/dev/null); do
    descendants "$child"
  done
}

# Print "tool<TAB>id" for the first pid whose open fds point at a session file.
open_session() {
  local pid f tgt id
  for pid in "$@"; do
    for f in /proc/"$pid"/fd/*; do
      tgt="$(readlink "$f" 2>/dev/null)" || continue
      case "$tgt" in
        "$HOME"/.codex/sessions/*rollout-*.jsonl)
          id="$(basename "$tgt" .jsonl | grep -oE "$UUID_RE" | tail -1)"
          [ -n "$id" ] && { printf 'codex\t%s\n' "$id"; return 0; } ;;
        "$HOME"/.claude/projects/*.jsonl)
          case "$tgt" in *subagents*) continue ;; esac
          id="$(basename "$tgt" .jsonl)"
          [ -n "$id" ] && { printf 'claude\t%s\n' "$id"; return 0; } ;;
      esac
    done
  done
  return 1
}

tmux list-panes -a -F '#{session_name}	#{window_index}	#{pane_index}	#{pane_pid}	#{pane_current_command}' |
while IFS=$'\t' read -r s w p pid cmd; do
  pids="$(descendants "$pid" | tr '\n' ' ')"
  if res="$(open_session $pids)"; then
    tool="${res%%$'\t'*}"; id="${res#*$'\t'}"
  else
    # No open session file: detect claude/codex by command; leave id empty.
    tool=""; id=""
    case "$cmd" in
      claude) tool="claude" ;;
      node)
        if ps -o args= -p "$(echo "$pids" | tr ' ' ',')" 2>/dev/null | grep -q '\.local/bin/codex'; then
          tool="codex"
        fi ;;
    esac
  fi
  [ -n "$tool" ] && printf '%s\t%s\t%s\t%s\t%s\n' "$s" "$w" "$p" "$tool" "$id" >> "$tmpfile"
done

mv "$tmpfile" "$MAP"
