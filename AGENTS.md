# Agent notes

This repo is Chase's dotfiles source-of-truth. The live config locations on this machine are **symlinks pointing into this repo** — editing a file here is editing the live config, and vice versa.

## Symlink map

| Live path                              | Repo path                  |
| -------------------------------------- | -------------------------- |
| `~/.config/fish/config.fish`           | `fish/config.fish`         |
| `~/.config/kitty/kitty.conf`           | `kitty/kitty.conf`         |
| `~/.tmux.conf` (note: `$HOME`, not `~/.config/tmux/`) | `tmux/tmux.conf` |
| `~/.claude/settings.json`              | `claude/settings.json`     |
| `~/.claude/hooks/block-dangerous.sh`   | `claude/hooks/block-dangerous.sh` |
| `~/.claude/hooks/notify-done.sh`       | `claude/hooks/notify-done.sh` |

## Rules

- **Do not** `rm` a live config path and re-create it as a regular file — that severs the symlink. Write through it (Edit/Write/`>` all follow symlinks correctly).
- When adding a new config to track: move the file into this repo, then `ln -s <abs-repo-path> <live-path>`.
- After editing, commit + push from `~/linux_configs` like any normal repo.

## Bell-notification chain

`claude/hooks/notify-done.sh` (and the inline Stop hook in `claude/settings.json`) emits `\a` to the controlling tty when a Claude turn ends. The notification is the product of three pieces working together — don't "fix" one in isolation:

1. **Claude Stop hook** → writes `\a` to `/dev/<tty>`.
2. **kitty** has `enable_audio_bell no` → visual bell only, no sound.
3. **tmux** has bell-on-activity → window gets flagged so you notice across panes.
