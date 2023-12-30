#! /usr/bin/env sh

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

SOURCE="$(grealpath .)"
GIT_PATH="$(grealpath ~)"

info "Setting up git..."

find . -name ".git*" | while read fn; do
    fn=$(basename $fn)
    symlink "$SOURCE/$fn" "$GIT_PATH/$fn"
done

success "Successfully set up git."