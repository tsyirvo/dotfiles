#!/usr/bin/env bash

# ~/.macos — https://mths.be/macos

# Close any open System Preferences panes, to prevent them from overriding
# settings we’re about to change

DIR=$(dirname "$0")
cd "$DIR"

. ../scripts/functions.sh

info "Setting up macOS defaults..."

# Ask for the administrator password upfront
sudo -v

# # Keep-alive: update existing `sudo` time stamp until `.osx` has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Set computer name
sudo scutil --set ComputerName "TsyirvoMacBookPro"
sudo scutil --set LocalHostName "TsyirvoMacBookPro"
sudo scutil --set HostName "TsyirvoMacBookPro"
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "TsyirvoMacBookPro"

# System Preferences
source ./_01-general.sh
source ./_02-desktop_screensaver.sh
source ./_03-dock.sh
source ./_04-spotlight.sh
source ./_05-apps.sh
source ./_06-screen.sh
source ./_07-energy.sh
source ./_08-inputs.sh

success "Successfully set up macOS Defaults. Note that some of these changes require a logout/restart to take effect."