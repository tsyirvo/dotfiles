function wcp --description "Spawn Claude agent (plan mode) in background tmux session"
    set -l branch $argv[1]
    set -l claude_args

    set -l i 2
    while test $i -le (count $argv)
        if test "$argv[$i]" = "--"
            set claude_args $argv[(math $i + 1)..-1]
            break
        end
        set i (math $i + 1)
    end

    wt switch --create --no-cd $branch

    set -l repo (basename (git rev-parse --show-toplevel 2>/dev/null))
    set -l safe_branch (string replace -a '/' '-' -- $branch)
    set -l sname {$repo}__{$safe_branch}

    if test (count $claude_args) -gt 0
        # Join the args into a single string
        set -l prompt_text (string join ' ' -- $claude_args)
        # Escape any double quotes inside the prompt
        set -l escaped (string replace -a '"' '\\"' -- "$prompt_text")
        # Send with double quotes so the target shell handles apostrophes etc.
        tmux send-keys -t "$sname:agent.left" "claude --permission-mode plan \"$escaped\"" Enter
    else
        tmux send-keys -t "$sname:agent.left" "claude --permission-mode plan" Enter
    end

    echo "✓ Agent spawned in background: $sname"
    echo "  → <prefix>+T to jump there via sesh"
end
