#! /usr/bin/env sh

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

SOURCE="$(realpath .)"
DESTINATION="$(realpath ~/)"

info "Configuraing Tmux..."

substep_info "Creating Tmux plugins folder..."
mkdir -p "$DESTINATION/.tmux/plugins/tpm"

find -name ".tmux.conf" | while read fn; do
    symlink "$SOURCE/$fn" "$DESTINATION/$fn"
done

setup_plugins() {
  git clone https://github.com/tmux-plugins/tpm "$DESTINATION/.tmux/plugins/tpm"
}

if setup_plugins; then
    success "Successfully set up plugins manager."
else
    error "Failed setting up plugins manager."
fi


success "Finished configuring Tmux"
