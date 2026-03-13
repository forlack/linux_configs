source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

# opencode
fish_add_path /home/chase/.opencode/bin

alias mp='mpremote'

# --- Tmux Auto-Naming ---
# Automatically rename tmux window to current folder name
function __update_tmux_window_name --on-variable PWD
    if set -q TMUX
        tmux rename-window (basename $PWD)
    end
end
