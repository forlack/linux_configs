source /usr/share/cachyos-fish-config/cachyos-config.fish

function ripdvd --description "Rip a DVD to Jellyfin"
    command rip-dvd-movie $argv
end

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
