#!/usr/bin/env bash

# Shared printing functions for repo scripts/tasks.
# Sourced by .chezmoiscripts via tasks/lib/functions.sh at the repo path.
coloredEcho() {
    local exp="$1";
    local color="$2";
    local arrow="$3";
    if ! [[ $color =~ ^[0-9]$ ]] ; then
       case $(echo "$color" | tr '[:upper:]' '[:lower:]') in
        black) color=0 ;;
        red) color=1 ;;
        green) color=2 ;;
        yellow) color=3 ;;
        blue) color=4 ;;
        magenta) color=5 ;;
        cyan) color=6 ;;
        white|*) color=7 ;; # white or invalid color
       esac
    fi
    tput bold;
    tput setaf "$color";
    echo "$arrow $exp";
    tput sgr0;
}

info() {
    coloredEcho "$1" blue "========>"
}

success() {
    coloredEcho "$1" green "========>"
}

error() {
    coloredEcho "$1" red "========>"
}
