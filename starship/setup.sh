#! /usr/bin/env sh

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

SOURCE="$(realpath .)"
DESTINATION="$(realpath ~/.config)"

info "Configuraing starship..."

find -name "starship.toml" | while read fn; do
    symlink "$SOURCE/$fn" "$DESTINATION/$fn"
done

success "Finished configuring starship."
