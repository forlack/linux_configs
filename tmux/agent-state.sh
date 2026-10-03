#!/bin/bash
# Mark the tmux window containing Claude/Codex as working, or clear that mark
# when the turn ends. TMUX_PANE is inherited by agent hook processes.

state=${1:-}

# Under Codex's shared app-server daemon, TMUX_PANE is the daemon's, not this
# session's; resolve the real pane from the hook JSON on stdin.
from_codex_daemon() {
  local p=$PPID i
  for i in 1 2 3 4; do
    [ "$p" -gt 1 ] 2>/dev/null || return 1
    case "$(ps -o args= -p "$p")" in *codex\ app-server*) return 0 ;; esac
    p=$(ps -o ppid= -p "$p" | tr -d ' ')
  done
  return 1
}
if [ -n "${TMUX:-}" ] && [ ! -t 0 ] && from_codex_daemon; then
  TMUX_PANE=$(bash "$(dirname "$0")/codex-pane.sh")
fi

if [ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ]; then
  case "$state" in
    working)
      tmux set-option -w -t "$TMUX_PANE" @agent_state working 2>/dev/null
      ;;
    done)
      tmux set-option -w -u -t "$TMUX_PANE" @agent_state 2>/dev/null || true
      ;;
  esac

  tmux refresh-client -S 2>/dev/null || true
fi
