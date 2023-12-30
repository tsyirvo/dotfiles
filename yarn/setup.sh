#! /usr/bin/env sh

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

SOURCE="$(grealpath .)"
CONFIG_PATH="$(grealpath ~/)"

info "Setting up yarn..."

find . -name ".yarnrc.yml" | while read fn; do
    symlink "$SOURCE/$fn" "$CONFIG_PATH/$fn"
done

success "Successfully set up yarn."
