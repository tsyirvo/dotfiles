function wpi --description "Spawn Pi agent in background tmux session"
    set -l branch $argv[1]
    set -l pi_args

    set -l i 2
    while test $i -le (count $argv)
        if test "$argv[$i]" = "--"
            set pi_args $argv[(math $i + 1)..-1]
            break
        end
        set i (math $i + 1)
    end

    wt switch --create --no-cd $branch

    set -l repo (basename (git rev-parse --show-toplevel 2>/dev/null))
    set -l safe_branch (string replace -a '/' '-' -- $branch)
    set -l sname {$repo}__{$safe_branch}

    if test (count $pi_args) -gt 0
        set -l prompt_text (string join ' ' -- $pi_args)
        set -l escaped (string replace -a '"' '\\"' -- "$prompt_text")
        tmux send-keys -t "$sname:agent.left" "pi \"$escaped\"" Enter
    else
        tmux send-keys -t "$sname:agent.left" "pi" Enter
    end

    if set -q TMUX
        tmux switch-client -t "$sname"
    else
        tmux attach-session -t "$sname"
    end
end
