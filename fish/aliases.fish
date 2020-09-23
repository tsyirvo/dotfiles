### Git ###
alias glog="git log --graph --pretty=format:'%Cred%h%Creset %an: %s - %Creset %C(yellow)%d%Creset %Cgreen(%cr)%Creset' --abbrev-commit --date=relative"
alias gd='git diff --color | sed "s/^\([^-+ ]*\)[-+ ]/\\1/" | less -r'
alias ga='git add -A'
alias gac='git add -A && git commit -m'
alias gs='git status -sb'

alias gcp="git checkout -"
alias gcd="git checkout develop"
alias gcm="git checkout master"

alias grc="git reset --soft HEAD~1"
alias grs="git reset --soft HEAD ."
alias gsc='git stash && git stash clear'

alias gp='git push origin HEAD'
alias gpf='git push origin HEAD -f --force-with-lease'
alias gpd='git pull origin develop'
alias gpdr='git pull origin develop --rebase'
alias gpm='git pull origin master'
alias gpmr='git pull origin master --rebase'
alias gpt='git push --follow-tags'
alias gft='git fetch --tags'

alias gco='git checkout origin HEAD'
alias gcb='git checkout -b $1'
alias gb='git branch'
alias gt='git tag'

alias ghide='git update-index --assume-unchanged'
alias gunhide='git update-index --no-assume-unchanged'
alias ghidden='! git ls-files -v | grep '^h' | cut -c3-'

### System ###
alias ls="exa -la"

### XCode ###
alias ios="open /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app"
alias watchos="open /Applications/Xcode.app/Contents/Developer/Applications/Simulator\ \(Watch\).app"

### Kubectl ###
alias k="kubectl"

### Neovim ###
alias v="nvim"

### Tmux ###
alias t="tmux"
alias ta="tmux a -t"
alias tls="tmux ls"
alias tn="tmux new -s"

### Docker ###
alias d="docker"
alias dc="docker container"
alias dcr="docker container run"
alias dcs="docker container stop"
alias dn="docker network"
alias di="docker image"
alias dv="docker volume"