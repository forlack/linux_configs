#!/bin/bash
# Codex Stop hook: emit a terminal bell to the controlling tty (same mechanism
# as Claude's Stop hook in claude/settings.json) so tmux/kitty can flash it.
# Codex's shared app-server daemon runs this hook with no tty and the daemon's
# TMUX_PANE, so resolve the session's real pane from the hook JSON.
input=$(cat)
bash "$HOME/linux_configs"/tmux/agent-state.sh done <<<"$input"
t=
if [ -n "${TMUX:-}" ]; then
  pane=$(bash "$HOME/linux_configs"/tmux/codex-pane.sh <<<"$input")
  [ -n "$pane" ] && t=$(tmux display-message -p -t "$pane" '#{pane_tty}' 2>/dev/null)
fi
if [ -z "$t" ]; then
  t=$(ps -o tty= -p $PPID | tr -d ' ')
  [ -n "$t" ] && [ "$t" != "?" ] && t=/dev/$t || t=
fi
[ -n "$t" ] && printf '\a' > "$t" 2>/dev/null
exit 0
