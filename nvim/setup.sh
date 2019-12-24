#! /usr/bin/env sh

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

SOURCE="$(realpath .)"
DESTINATION="$(realpath ~/.config/nvim)"

info "Configuraing neovim..."

substep_info "Creating nvim folder folder..."
mkdir -p "$DESTINATION"

find . -name "*.vim" -o -name "coc-settings.json" | while read fn; do
    symlink "$SOURCE/$fn" "$DESTINATION/$fn"
done

success "Finished configuring neovim."
