#!/usr/bin/env bash
# Resume the most recent Codex session that was started in the current directory
# (resurrect restores the pane's cwd first, so $PWD is the right one). Falls back
# to `codex resume --last` when no session matches this directory.
#
# Why: `codex resume --last` only knows the single globally-newest session, so
# multiple restored codex panes would all reopen the same one. Matching on the
# session's recorded cwd restores the correct session per pane.

target="${1:-$PWD}"

best_id=""
# Newest first; stop at the first rollout whose session_meta.cwd == target.
while IFS= read -r f; do
  read -r cwd id < <(
    head -1 "$f" 2>/dev/null | jq -r '[.payload.cwd, .payload.id] | @tsv' 2>/dev/null
  )
  if [ "$cwd" = "$target" ] && [ -n "$id" ]; then
    best_id="$id"
    break
  fi
done < <(find "$HOME/.codex/sessions" -name 'rollout-*.jsonl' -printf '%T@\t%p\n' 2>/dev/null \
         | sort -rn | cut -f2-)

if [ -n "$best_id" ]; then
  exec codex resume "$best_id"
else
  exec codex resume --last
fi
