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

# Fastlane bin
set -x -g PATH (brew --prefix fastlane)/bin $PATH

# Java version
set -x JAVA_HOME (/usr/libexec/java_home -v11.0.9)

# Android
set -x ANDROID_HOME ~/Library/Android/sdk
set -x ANDROID_SDK_ROOT ~/Library/Android/sdk
set -x ANDROID_AVD_HOME ~/.android/avd

# Android ADB
set -x -g PATH $ANDROID_HOME/platform-tools $PATH
set -x -g PATH $ANDROID_HOME/tools $PATH
set -x -g PATH $ANDROID_HOME/emulator $PATH

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/tsyirvo/google-cloud-sdk/path.fish.inc' ]; . '/Users/tsyirvo/google-cloud-sdk/path.fish.inc'; end

starship init fish | source