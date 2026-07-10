#!/bin/bash
# Claude Code statusline: model+effort, context usage, rate limits, git branch/changes.
input=$(cat)

CYAN='\033[36m'
DIM_BLACK='\033[90m'
GREEN='\033[32m'
MAGENTA='\033[35m'
YELLOW='\033[33m'
BLUE='\033[34m'
LIGHT_GRAY='\033[38;5;250m'
RESET='\033[0m'

model=$(echo "$input" | jq -r '.model.display_name // "unknown"')
effort=$(echo "$input" | jq -r '.effort.level // empty')

if [ -n "$effort" ]; then
  model_col="${model}-${effort}"
else
  model_col="${model}"
fi

used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$used_pct" ]; then
  ctx_col=$(printf "ctx %.0f%%" "$used_pct")
else
  ctx_col="ctx --"
fi

five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
usage_col=""
if [ -n "$five" ] || [ -n "$week" ]; then
  usage_col="Usg: "
  if [ -n "$five" ]; then
    usage_col="${usage_col}$(printf '%.0f%%' "$five")"
  else
    usage_col="${usage_col}--"
  fi
  usage_col="${usage_col}/"
  if [ -n "$week" ]; then
    usage_col="${usage_col}$(printf '%.0f%%' "$week")"
  else
    usage_col="${usage_col}--"
  fi
fi

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
dir_col=""
if [ -n "$cwd" ]; then
  # Show path relative to $HOME (e.g. ~/linux_configs), else the full path.
  case "$cwd" in
    "$HOME") dir_col="~" ;;
    "$HOME"/*) dir_col="~/${cwd#$HOME/}" ;;
    *) dir_col="$cwd" ;;
  esac
fi
branch=""
changes=""
if [ -n "$cwd" ] && git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  if [ -z "$branch" ]; then
    branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  fi
  changed_count=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [ "$changed_count" -gt 0 ] 2>/dev/null; then
    changes="+${changed_count}"
  fi
fi

sep=" | "
out="${CYAN}${model_col}${RESET}"
out="${out}${DIM_BLACK}${sep}${RESET}${LIGHT_GRAY}${ctx_col}${RESET}"
if [ -n "$usage_col" ]; then
  out="${out}${DIM_BLACK}${sep}${RESET}${GREEN}${usage_col}${RESET}"
fi
if [ -n "$dir_col" ]; then
  out="${out}${DIM_BLACK}${sep}${RESET}${BLUE}${dir_col}${RESET}"
fi
if [ -n "$branch" ]; then
  out="${out}${DIM_BLACK}${sep}${RESET}${MAGENTA}${branch}${RESET}"
fi
if [ -n "$changes" ]; then
  out="${out}${DIM_BLACK}${sep}${RESET}${YELLOW}${changes}${RESET}"
fi

printf "%b\n" "$out"
