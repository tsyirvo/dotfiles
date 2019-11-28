. ~/.config/fish/aliases.fish

set -x -g LS_COLORS "di=38;5;27:fi=38;5;7:ln=38;5;51:pi=40;38;5;11:so=38;5;13:or=38;5;197:mi=38;5;161:ex=38;5;9:"

set -x -g TERM "xterm-256color"

set -x -g LC_ALL en_US.UTF-8
set -x -g LANG en_US.UTF-8

# Coreutils bin and man folders
set -x -g PATH (brew --prefix coreutils)/libexec/gnubin $PATH

# Findutils bin and man folders
set -x -g PATH (brew --prefix findutils)/libexec/gnubin $PATH

# User bin folder
set -x -g PATH ~/bin $PATH /usr/local/sbin

# Globals
set -gx EDITOR code

set SPACEFISH_PACKAGE_SHOW false
set SPACEFISH_GIT_SYMBOL :

# Fastlane bin
set -x PATH $HOME/.fastlane/bin $PATH

# set -x YVM_DIR /usr/local/opt/yvm
# . $YVM_DIR/yvm.fish