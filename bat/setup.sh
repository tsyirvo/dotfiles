#! /usr/bin/env sh

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

SOURCE="$(grealpath .)"
CONFIG_PATH="$(grealpath ~/.config/bat)"

info "Setting up bat..."

mkdir -p "$CONFIG_PATH"
mkdir -p "$CONFIG_PATH/themes"

find * -name "themes/Catppuccin Mocha.tmTheme" | while read fn; do
    symlink "$SOURCE/$fn" "$CONFIG_PATH/themes/$fn"
done

clear_broken_symlinks "$CONFIG_PATH"

success "Successfully set up bat."
