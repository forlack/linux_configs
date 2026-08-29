#!/bin/bash
# Mark the tmux window containing Claude/Codex as working, or clear that mark
# when the turn ends. TMUX_PANE is inherited by agent hook processes.

state=${1:-}

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
