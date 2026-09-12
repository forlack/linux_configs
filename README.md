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

It applies these macOS defaults:

- disable press-and-hold accents so keys repeat normally
- faster key repeat and shorter repeat delay
- Finder shows hidden files
- Finder shows the path bar
- Finder defaults to list view

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

To enable Touch ID for `sudo`, run:

```bash
sudo cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local
sudo sed -i '' 's/^#auth/auth/' /etc/pam.d/sudo_local
```

To apply only the macOS defaults later:

```bash
./scripts/macos-defaults.sh
```

## macOS tmux features

The macOS config includes the Linux popups, tab colors, and session restoration,
plus native `pbcopy` clipboard integration and Kitty true color support.
After updating the repo, reload with `tmux source-file ~/.tmux.conf`.

With the Ctrl+Space prefix: `f` toggles the scratchpad, `b` opens btop,
`e` opens Yazi, `w` switches windows, `h` shows help, and `/` opens the
Claude/Codex session picker. Alt+j/Alt+k select the previous/next window.
Dependencies: `brew install btop yazi fzf ripgrep python`.

For Codex working/done tab indicators, merge `codex/tmux-hooks.macos.toml`
into your existing `~/.codex/config.toml`, then review/enable the hooks in
Codex if prompted. Preserve your existing model, permissions, and project settings.
The full Linux Codex/Claude settings contain machine-specific paths and should
not be linked directly on macOS.

Resurrection uses `lsof` on macOS and `/proc` on Linux to identify open session
files. When no exact session ID is available, it falls back to Claude continue
or Codex resume-last. Restoration only sends commands into shell panes.
