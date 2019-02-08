#! /usr/bin/env sh

DIR=$(dirname "$0")
cd "$DIR"

. scripts/functions.sh

info "Prompting for sudo password..."
if sudo -v; then
    # Keep-alive: update existing `sudo` time stamp until `setup.sh` has finished
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    success "Sudo credentials updated."
else
    error "Failed to obtain sudo credentials."
fi

info "Installing XCode command line tools..."
if xcode-select --print-path &>/dev/null; then
    success "XCode command line tools already installed."
elif xcode-select --install &>/dev/null; then
    success "Finished installing XCode command line tools."
else
    error "Failed to install XCode command line tools."
fi

info "Overwriting /etc/hosts with the ad-blocking hosts file from someonewhocares.org..."
sudo cp /etc/hosts /etc/hosts.backup
sudo cp ./configs/hosts /etc/hosts

info "Checking for the Homebrew install..."
brew_bin=$(which brew) 2>&1 > /dev/null
if [[ $? != 0 ]]; then
    substep_info "Installing homebrew."
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    if [[ $? != 0 ]]; then
        error "Unable to install Uomebrew, script $0 abort!"
        exit 2
    else
        success "Finished installing homebrew."
    fi
else
    substep_info "Updating homebrew."
    brew update
    brew upgrade
    success "Brews updated."
fi

info "Installing all packages..."
./packages/setup.sh

# info "Setting Fish as the default shell..."
# echo "/usr/local/bin/fish" | sudo tee -a /etc/shells
# chsh -s /usr/local/bin/fish

info "Default to always pin yarn & npm versions"
yarn config set save-prefix false
npm config set save-exact true

find * -name "setup.sh" -not -wholename "packages*" | while read setup; do
    ./$setup
done

success "Finished installing all Dotfiles 🎉"