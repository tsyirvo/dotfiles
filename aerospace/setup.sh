#! /usr/bin/env sh

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

SOURCE="$(grealpath .)"
CONFIG_PATH="$(grealpath ~/.config/aerospace)"

info "Setting up aerospace..."

mkdir -p "$CONFIG_PATH"

find . -name "aerospace.toml" | while read fn; do
    symlink "$SOURCE/$fn" "$CONFIG_PATH/$fn"
done

clear_broken_symlinks "$CONFIG_PATH"

success "Successfully set up aerospace."
