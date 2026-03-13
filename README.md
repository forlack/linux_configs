# Linux Configs

Personal configuration files for CachyOS (Arch-based) with KDE Plasma.

## Contents

- **tmux/** - Tmux configuration (Ctrl+Space prefix, COSMIC Dark theme, TPM plugins)
- **kitty/** - Kitty terminal config (JetBrains Mono, COSMIC Dark colors)
- **fish/** - Fish shell config (CachyOS base, aliases, tmux auto-rename)

## Installation

```bash
# Tmux
cp tmux/tmux.conf ~/.tmux.conf
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# Then in tmux: Ctrl+Space, I to install plugins

# Kitty
mkdir -p ~/.config/kitty
cp kitty/kitty.conf ~/.config/kitty/kitty.conf

# Fish
mkdir -p ~/.config/fish
cp fish/config.fish ~/.config/fish/config.fish
```
