#!/bin/bash
# Stop hook: play notification sound when Claude finishes responding

# Try various notification methods in order of preference
if command -v paplay &>/dev/null; then
  # PulseAudio/PipeWire (most common on modern Linux)
  sound="/usr/share/sounds/freedesktop/stereo/complete.oga"
  if [ -f "$sound" ]; then
    paplay "$sound" &>/dev/null &
  else
    # Fallback: generate a beep via paplay
    paplay /usr/share/sounds/freedesktop/stereo/message.oga &>/dev/null &
  fi
elif command -v pw-play &>/dev/null; then
  sound="/usr/share/sounds/freedesktop/stereo/complete.oga"
  [ -f "$sound" ] && pw-play "$sound" &>/dev/null &
elif command -v aplay &>/dev/null; then
  # ALSA fallback
  sound="/usr/share/sounds/freedesktop/stereo/complete.oga"
  [ -f "$sound" ] && aplay "$sound" &>/dev/null &
elif command -v notify-send &>/dev/null; then
  # Desktop notification as fallback
  notify-send "Claude Code" "Task complete" &>/dev/null &
else
  # Terminal bell as last resort
  printf '\a'
fi

exit 0
