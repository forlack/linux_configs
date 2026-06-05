# Linux Configs

Personal configuration files for CachyOS (Arch-based) with KDE Plasma, plus macOS ports for a Homebrew-based setup.

## Contents

- **tmux/** - Tmux configuration (Ctrl+Space prefix, COSMIC Dark theme, TPM plugins)
- **kitty/** - Kitty terminal config (JetBrains Mono, COSMIC Dark colors)
- **fish/** - Fish shell config (CachyOS base, aliases, tmux auto-rename)
- **starship/** - Starship prompt config used on macOS
- **scripts/** - Sync helpers for platform-specific installs

## CachyOS Installation

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

## macOS Installation

The macOS setup uses Homebrew packages and symlinks the live config files back into this repo.

```bash
./scripts/sync-macos.sh
```

The script installs:

- `fish`, `tmux`, `kitty`
- `eza`, `bat`, `zoxide`, `starship`, `fastfetch`, `gh`
- `git-lfs`, `lazygit`, `direnv`
- JetBrains Mono font
- tmux plugin manager and configured tmux plugins

It links:

| Live path | Repo path |
| --- | --- |
| `~/.config/fish/config.fish` | `fish/config.macos.fish` |
| `~/.config/fish/conf.d/done.fish` | `fish/conf.d/done.fish` |
| `~/.config/kitty/kitty.conf` | `kitty/kitty.macos.conf` |
| `~/.tmux.conf` | `tmux/tmux.macos.conf` |
| `~/.config/starship.toml` | `starship/starship.toml` |

The script prints the two manual shell commands macOS may require:

```bash
echo '/opt/homebrew/bin/fish' | sudo tee -a /etc/shells
chsh -s '/opt/homebrew/bin/fish'
```

Use the printed Homebrew path if it differs from `/opt/homebrew/bin/fish`.
