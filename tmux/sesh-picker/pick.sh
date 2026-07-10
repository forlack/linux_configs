#!/usr/bin/env bash
# Session picker: refresh the cache, show a two-pane fzf (list | transcript),
# and resume the chosen Claude/Codex session in a new tmux window.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="$HOME/.cache/sesh-picker/index.tsv"

# Refresh the index (fast after first run thanks to mtime caching).
python3 "$DIR/index.py" || true
[ -s "$CACHE" ] || { echo "No sessions found."; sleep 2; exit 0; }

# preview.py emits its own ANSI colors (user vs. agent), rendered via fzf --ansi.
SEARCH="$DIR/search_content.sh"

# Two search modes:
#   default (session❯)  fuzzy-match session titles     — native fzf filtering
#   ctrl-f  (content❯)   grep the chat bodies as you type — live rg reload
#   ctrl-t               back to title mode
# The preview is scrolled to the bottom (+9999) so the newest turn shows first.
#
# Fields: 1=epoch 2=date 3=tool 4=title 5=cwd 6=uuid 7=path
sel=$(
  fzf --ansi --delimiter='\t' \
      --with-nth='2' \
      --preview "python3 '$DIR/preview.py' {3} {7}" \
      --preview-window='right:50%:wrap-word:border-left' \
      --preview-wrap-sign='' \
      --header 'enter: resume  ·  ctrl-f: search chat text  ·  ctrl-t: titles  ·  esc: cancel' \
      --prompt 'session ❯ ' \
      --color='fg:#C4C4C4,bg:#1B1B1B,hl:#49BAC8,fg+:#FFFFFF,bg+:#101010,hl+:#49BAC8,border:#49BAC8,header:#6296BE,prompt:#49BAC8,pointer:#49BAC8' \
      --no-border \
      --bind "start:unbind(change)" \
      --bind "change:reload(bash '$SEARCH' {q})" \
      --bind "ctrl-f:disable-search+change-prompt(content ❯ )+rebind(change)+reload(bash '$SEARCH' {q})" \
      --bind "ctrl-t:enable-search+change-prompt(session ❯ )+unbind(change)+reload(cat '$CACHE')" \
      < "$CACHE"
) || exit 0

[ -n "${sel:-}" ] && exec "$DIR/open.sh" "$sel"
