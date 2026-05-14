source /usr/share/cachyos-fish-config/cachyos-config.fish

# Only show greeter outside of tmux (i.e., fresh kitty sessions)
function fish_greeting
    if not set -q TMUX
        fastfetch
    end
end

# opencode
fish_add_path /home/chase/.opencode/bin

abbr -a mp mpremote
abbr -a greet fastfetch

# --- Tmux Auto-Naming ---
# Automatically rename tmux window to current folder name
function __update_tmux_window_name --on-variable PWD
    if set -q TMUX
        tmux rename-window (basename $PWD)
    end
end
