if test -d /opt/homebrew/bin
    fish_add_path /opt/homebrew/bin /opt/homebrew/sbin
end

if test -d $HOME/.opencode/bin
    fish_add_path $HOME/.opencode/bin
end

fish_add_path $HOME/.local/bin $HOME/.cargo/bin $HOME/Applications/depot_tools

if test -f $HOME/.fish_profile
    source $HOME/.fish_profile
end

set -gx MANROFFOPT "-c"
if command -q bat
    set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
end

set -U __done_min_cmd_duration 10000
set -U __done_notification_urgency_level low

function fish_greeting
    if not set -q TMUX
        if command -q fastfetch
            fastfetch
        end
    end
end

abbr -a mp mpremote
abbr -a greet fastfetch

function __history_previous_command
    switch (commandline -t)
        case "!"
            commandline -t $history[1]
            commandline -f repaint
        case "*"
            commandline -i !
    end
end

function __history_previous_command_arguments
    switch (commandline -t)
        case "!"
            commandline -t ""
            commandline -f history-token-search-backward
        case "*"
            commandline -i '$'
    end
end

if test "$fish_key_bindings" = fish_vi_key_bindings
    bind -Minsert ! __history_previous_command
    bind -Minsert '$' __history_previous_command_arguments
else
    bind ! __history_previous_command
    bind '$' __history_previous_command_arguments
end

function history
    builtin history --show-time='%F %T ' $argv
end

function backup --argument filename
    cp $filename $filename.bak
end

function copy
    set count (count $argv | tr -d \n)
    if test "$count" = 2; and test -d "$argv[1]"
        set from (echo $argv[1] | string trim --right --chars=/)
        set to (echo $argv[2])
        command cp -r $from $to
    else
        command cp $argv
    end
end

if command -q eza
    alias ls='eza -al --color=always --group-directories-first --icons=always'
    alias la='eza -a --color=always --group-directories-first --icons=always'
    alias ll='eza -l --color=always --group-directories-first --icons=always'
    alias lt='eza -aT --color=always --group-directories-first --icons=always'
    alias l.="eza -a | grep -e '^\.'"
end

alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias psmem='ps aux | sort -nr -k 4'
alias psmem10='ps aux | sort -nr -k 4 | head -10'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias tb='nc termbin.com 9999'
alias update='brew update && brew upgrade'
alias cleanup='brew autoremove && brew cleanup'

function __update_tmux_window_name --on-variable PWD
    if set -q TMUX
        tmux rename-window (basename $PWD)
    end
end

if command -q zoxide
    zoxide init fish | source
end

if command -q starship
    starship init fish | source
end
