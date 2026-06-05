#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "macos-defaults.sh only supports macOS." >&2
  exit 1
fi

# Keyboard: prefer fast repeat behavior for terminal/editor use.
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Finder: make developer files and paths visible by default.
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string Nlsv

killall Finder >/dev/null 2>&1 || true

echo "macOS defaults applied. Reopen apps or log out/in for keyboard changes to fully apply."
