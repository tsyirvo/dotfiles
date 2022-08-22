function repo
    set -l repo_path (repodir $argv)
    echo "$repo_path"
    cd "$repo_path"
end

function repodir
    set repo_base ~/Projects
    set repo_path (find "$repo_base" -mindepth 2 -maxdepth 2 -type d -name "*$argv*" | head -n 1)
    if not test "$argv"; or not test "$repo_path"
        set repo_path "$repo_base"
    end
    echo "$repo_path"
end

# Often used shortcuts/aliases
function projects; cd ~/Projects; end
function personal; cd ~/Projects/personal; end
function inolab; cd ~/Projects/inolab; end
function luko; ~/Projects/inolab/luko-app-react-native; and eval $EDITOR .; end