if not status is-interactive
    # ssh commands and daemons they spawn (e.g. the herdr server started by
    # `herdr --remote`, whose plugins call `wt`) still need mise tools on PATH.
    if type -q mise
        mise activate fish --shims | source
    end
    return
end

if type -q mise
    mise activate fish | source
end

if type -q starship
    starship init fish | source
end

if type -q zoxide
    zoxide init fish | source
end

if type -q fzf
    fzf --fish | source
end

if type -q atuin
    atuin init fish | source
end

if test -r "$HOME/.orbstack/shell/init2.fish"
    source "$HOME/.orbstack/shell/init2.fish"
end
