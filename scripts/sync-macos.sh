#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "sync-macos.sh only supports macOS." >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required before running this script." >&2
  exit 1
fi

brew install fish tmux eza bat zoxide starship fastfetch dockutil gh git-lfs lazygit direnv
brew install --cask kitty font-jetbrains-mono

mkdir -p "$HOME/.config/fish/conf.d" "$HOME/.config/kitty" "$HOME/.config" "$HOME/.tmux/plugins"

ln -sf "$repo_dir/fish/config.macos.fish" "$HOME/.config/fish/config.fish"
ln -sf "$repo_dir/fish/conf.d/done.fish" "$HOME/.config/fish/conf.d/done.fish"
ln -sf "$repo_dir/kitty/kitty.macos.conf" "$HOME/.config/kitty/kitty.conf"
ln -sf "$repo_dir/tmux/tmux.macos.conf" "$HOME/.tmux.conf"
ln -sf "$repo_dir/starship/starship.toml" "$HOME/.config/starship.toml"

if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

"$HOME/.tmux/plugins/tpm/bin/install_plugins" || true

fish_path="$(brew --prefix)/bin/fish"
if ! grep -qx "$fish_path" /etc/shells; then
  echo "Add fish to /etc/shells with:"
  echo "  echo '$fish_path' | sudo tee -a /etc/shells"
fi

if [[ "${SHELL:-}" != "$fish_path" ]]; then
  echo "Set fish as your login shell with:"
  echo "  chsh -s '$fish_path'"
fi

echo "macOS configs synced from $repo_dir"
