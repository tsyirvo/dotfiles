if not status is-interactive
    return
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
