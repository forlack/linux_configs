#!/bin/bash
# PreToolUse hook: block dangerous bash commands
# Exit 0 = allow, Exit 2 = block (feeds error back to Claude)

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

if [ "$tool_name" != "Bash" ]; then
  exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Block rm -rf on critical paths
if echo "$command" | grep -qE 'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|--recursive)\s+(/|~|\$HOME|/home)'; then
  echo '{"decision": "block", "reason": "Blocked: rm -rf on critical path. Please confirm with the user first."}' >&2
  exit 2
fi

# Block force push to main/master
if echo "$command" | grep -qE 'git\s+push\s+.*--force.*\s+(main|master)|git\s+push\s+-f\s+.*\s+(main|master)'; then
  echo '{"decision": "block", "reason": "Blocked: force push to main/master is not allowed."}' >&2
  exit 2
fi

# Block git reset --hard
if echo "$command" | grep -qE 'git\s+reset\s+--hard'; then
  echo '{"decision": "block", "reason": "Blocked: git reset --hard. Please confirm with the user first."}' >&2
  exit 2
fi

exit 0
