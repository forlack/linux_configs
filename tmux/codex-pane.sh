#!/bin/bash
# Print the tmux pane id running the Codex session described by the hook JSON
# on stdin. Codex >= 0.160 runs every TUI's turns in one shared app-server
# daemon, so hooks inherit the daemon's TMUX_PANE (whichever pane launched it)
# instead of their own. Resolve the real pane from the payload's session_id:
#   1. cached session -> pane mapping from an earlier hook,
#   2. a TUI started as `codex resume <session_id>`,
#   3. TUIs in the payload's cwd not resuming some other session; if several,
#      the one started most recently before the session id's UUIDv7 timestamp.
# Prints nothing if no pane matches.

input=$(cat)
sid=$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null)
cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)
[ -n "$sid" ] || exit 0

cache="${XDG_RUNTIME_DIR:-/tmp}/codex-tmux-panes"
mkdir -p "$cache"

pane_alive() { tmux display-message -p -t "$1" '#{pane_id}' >/dev/null 2>&1; }

if [ -f "$cache/$sid" ]; then
  pane=$(<"$cache/$sid")
  # Touch so the resurrect save hook can tell the pane's newest session.
  if pane_alive "$pane"; then touch "$cache/$sid"; echo "$pane"; exit 0; fi
fi

descendants() {
  local p
  for p in $(cat /proc/"$1"/task/*/children 2>/dev/null); do
    echo "$p"
    descendants "$p"
  done
}

# Session creation time in seconds, from the UUIDv7's 48-bit ms prefix.
sid_hex=${sid//-/}
sid_ts=$(( 16#${sid_hex:0:12} / 1000 ))
now=$(date +%s)

best= best_start=0
while read -r pane pane_pid; do
  for pid in $(descendants "$pane_pid"); do
    args=$(tr '\0' ' ' 2>/dev/null < /proc/"$pid"/cmdline) || continue
    case "$args" in
      */bin/codex\ *app-server*|*codex-code-mode-host*) continue ;;
      */bin/codex|*/bin/codex\ *) ;;
      *) continue ;;
    esac
    case "$args" in
      *" $sid"*) echo "$pane" > "$cache/$sid"; echo "$pane"; exit 0 ;;
      *" resume "[0-9a-f]*-*) continue ;;  # pinned to a different session
    esac
    [ -n "$cwd" ] && [ "$(readlink /proc/"$pid"/cwd)" != "$cwd" ] && continue
    start=$(( now - $(ps -o etimes= -p "$pid") ))
    if [ "$start" -le $(( sid_ts + 2 )) ] && [ "$start" -ge "$best_start" ]; then
      best=$pane best_start=$start
    fi
  done
done < <(tmux list-panes -a -F '#{pane_id} #{pane_pid}' 2>/dev/null)

if [ -n "$best" ]; then
  echo "$best" > "$cache/$sid"
  echo "$best"
fi
