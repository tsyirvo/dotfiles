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
sudo scutil --set ComputerName "MacDaddyO"
sudo scutil --set LocalHostName "MacDaddyO"
sudo scutil --set HostName "MacDaddyO"
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "MacDaddyO"


# System Preferences
source $DIR/_01-general.sh
source $DIR/_02-desktop_screensaver.sh
source $DIR/_03-dock.sh
source $DIR/_04-spotlight.sh
source $DIR/_05-apps.sh
source $DIR/_06-screen.sh
source $DIR/_07-energy.sh
source $DIR/_08-inputs.sh

success "Successfully set up macOS Defaults. Note that some of these changes require a logout/restart to take effect."