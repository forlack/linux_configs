# Agent notes

This repo is Chase's dotfiles source-of-truth. Prefer editing files in this repo, then syncing or symlinking the live config paths.

On CachyOS/Linux, use the default files. On macOS, use the `*.macos.*` files and `scripts/sync-macos.sh`. macOS UI/defaults live in `scripts/macos-defaults.sh`.

## Symlink map

| Live path                              | Repo path                  |
| -------------------------------------- | -------------------------- |
| `~/.config/fish/config.fish`           | `fish/config.fish` on Linux, `fish/config.macos.fish` on macOS |
| `~/.config/fish/conf.d/done.fish`      | `fish/conf.d/done.fish` on macOS |
| `~/.config/kitty/kitty.conf`           | `kitty/kitty.conf` on Linux, `kitty/kitty.macos.conf` on macOS |
| `~/.tmux.conf` (note: `$HOME`, not `~/.config/tmux/`) | `tmux/tmux.conf` on Linux, `tmux/tmux.macos.conf` on macOS |
| `~/.config/starship.toml`              | `starship/starship.toml` on macOS |
| `~/.claude/settings.json`              | `claude/settings.json`     |
| `~/.claude/hooks/block-dangerous.sh`   | `claude/hooks/block-dangerous.sh` |
| `~/.claude/hooks/notify-done.sh`       | `claude/hooks/notify-done.sh` |

## Rules

- **Do not** `rm` a live config path and re-create it as a regular file — that severs the symlink. Write through it (Edit/Write/`>` all follow symlinks correctly).
- When adding a new config to track: move the file into this repo, then `ln -s <abs-repo-path> <live-path>`.
- For macOS setup, prefer running `./scripts/sync-macos.sh` from the repo root instead of hand-copying files.
- Keep privileged macOS steps, such as Touch ID sudo and `chsh`, documented instead of forcing them in scripts.
- After editing, commit + push from `~/linux_configs` like any normal repo.

## Bell-notification chain

`claude/hooks/notify-done.sh` (and the inline Stop hook in `claude/settings.json`) emits `\a` to the controlling tty when a Claude turn ends. The notification is the product of three pieces working together — don't "fix" one in isolation:

1. **Claude Stop hook** → writes `\a` to `/dev/<tty>`.
2. **kitty** has `enable_audio_bell no` → visual bell only, no sound.
3. **tmux** has bell-on-activity → window gets flagged so you notice across panes.
