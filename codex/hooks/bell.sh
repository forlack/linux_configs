#!/bin/bash
# Codex Stop hook: emit a terminal bell to the controlling tty (same mechanism
# as Claude's Stop hook in claude/settings.json) so tmux/kitty can flash it.
bash /home/chase/linux_configs/tmux/agent-state.sh done
t=$(ps -o tty= -p $PPID | tr -d ' ')
[ -n "$t" ] && [ "$t" != "?" ] && printf '\a' > "/dev/$t" 2>/dev/null
exit 0
