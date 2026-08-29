#!/usr/bin/env bash
#
# macOS user defaults
# Re-run manually any time: mise run macos
# Some changes need a logout/restart to take effect.
set -euo pipefail

## preflight — sudo + sanity guard -------------------------------------------
sudo -v || { echo "defaults: sudo required" >&2; exit 1; }
defaults read NSGlobalDomain AppleShowScrollBars >/dev/null 2>&1 \
  || echo "defaults: NSGlobalDomain not readable yet (first run?)"

## General — NSGlobalDomain survivors -----------------------------------------
# Store SSH identities in the Keychain
sudo ssh-add --apple-use-keychain

# Disable Gatekeeper (install apps from anywhere)
sudo spctl --master-disable

# Mute the startup chime
sudo nvram StartupMute=%01

# Show scroll bars (Automatic | WhenScrolling | Always)
defaults write NSGlobalDomain AppleShowScrollBars -string 'WhenScrolling'

# Disable the over-the-top focus ring animation
defaults write NSGlobalDomain NSUseAnimatedFocusRing -bool false

# Increase window resize speed for Cocoa applications
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# Expand save panels by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print panels by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Save to disk (not iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Quit the printer app when jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Disable the “Are you sure you want to open this application?” dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Rebuild the Open-With menu (dedupe)
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user

# Show ASCII control characters in caret notation
defaults write NSGlobalDomain NSTextShowsControlCharacters -bool true

# Disable automatic termination of inactive apps
defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true

# Disable the crash reporter
defaults write com.apple.CrashReporter DialogType -string "none"

# Help Viewer windows non-floating
defaults write com.apple.helpviewer DevMode -bool true

# Typing: kill the "smart" autocorrections that annoy coders
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

## Dock ---------------------------------------------------------------- -------
defaults write com.apple.dock mouse-over-hilite-stack -bool true
defaults write com.apple.dock tilesize -int 32
defaults write com.apple.dock mineffect -string "genie"
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize -int 50
defaults write com.apple.dock orientation -string "bottom"

# Don't minimize on title-bar double-click
defaults write NSGlobalDomain AppleMiniaturizeOnDoubleClick -bool true
# Minimize into the app icon, not a Dock tile
defaults write com.apple.dock minimize-to-application -bool false

# Spring loading for all Dock items
defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true
# Indicator lights for running apps
defaults write com.apple.dock show-process-indicators -bool true
# More transparent Dock
defaults write com.apple.dock hide-mirror -bool true
# No launch animation
defaults write com.apple.dock launchanim -bool false
# Faster Mission Control animation
defaults write com.apple.dock expose-animation-duration -float 0.1
# Don't group windows by app (old Exposé behavior)
defaults write com.apple.dock expose-group-by-app -bool false

# Auto-hide: instant + fast
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.75
defaults write com.apple.dock autohide -bool true
# Hidden apps' icons translucent
defaults write com.apple.dock showhidden -bool true
# No recent applications in Dock
defaults write com.apple.dock show-recents -bool false

# Status-bar clock format
defaults write com.apple.menuextra.clock DateFormat -string "EEE d MMM HH:mm:ss"

# Hot corners — all no-op (0)
defaults write com.apple.dock wvous-tl-corner -int 0
defaults write com.apple.dock wvous-tl-modifier -int 0
defaults write com.apple.dock wvous-tr-corner -int 0
defaults write com.apple.dock wvous-tr-modifier -int 0
defaults write com.apple.dock wvous-br-corner -int 0
defaults write com.apple.dock wvous-br-modifier -int 0
defaults write com.apple.dock wvous-bl-corner -int 0
defaults write com.apple.dock wvous-bl-modifier -int 0

## Finder ------------------------------------------------------------- -------
# Quit Finder via ⌘Q (hides desktop icons too)
defaults write com.apple.finder QuitMenuItem -bool true
# No window/Get Info animations
defaults write com.apple.finder DisableAllAnimations -bool true

# Default Finder window = Desktop
defaults write com.apple.finder NewWindowTarget -string "PfDe"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"

# Desktop icons: external + mounted servers + removable; hide internal HD
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

# Show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Hide the status bar, show the path bar
defaults write com.apple.finder ShowStatusBar -bool false
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder _FXShowPosixPathInTitle -bool false

# Folders first; search current folder by default
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
# No warning when changing an extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Spring loading for directories (no delay)
defaults write NSGlobalDomain com.apple.springing.enabled -bool true
defaults write NSGlobalDomain com.apple.springing.delay -float 0

# No .DS_Store on network/USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Skip disk-image verification (faster mounts)
defaults write com.apple.frameworks.diskimages skip-verify -bool true
defaults write com.apple.frameworks.diskimages skip-verify-locked -bool true
defaults write com.apple.frameworks.diskimages skip-verify-remote -bool true
# Auto-open a window when a volume mounts
defaults write com.apple.frameworks.diskimages auto-open-ro-root -bool true
defaults write com.apple.frameworks.diskimages auto-open-rw-root -bool true
defaults write com.apple.finder OpenWindowForNewRemovableDisk -bool true

# Column view everywhere
defaults write com.apple.finder FXPreferredViewStyle -string "clmv"

# No warning before emptying the Trash
defaults write com.apple.finder WarnOnEmptyTrash -bool false

# AirDrop over Ethernet + unsupported Macs
defaults write com.apple.NetworkBrowser BrowseAllInterfaces -bool true

# Show /Volumes
sudo chflags nohidden /Volumes

# Info panes: General / Open with / Sharing & Permissions
defaults write com.apple.finder FXInfoPanesExpanded -dict \
    General -bool true \
    OpenWith -bool true \
    Privileges -bool true

## Trackpad / Mouse / Keyboard — working keys only -----------------------------
# Tap to click (user + login screen)
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Right-click via two-finger tap
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults -currentHost write NSGlobalDomain com.apple.trackpad.trackpadCornerClickBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true

# Better Bluetooth audio quality
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40

# Full keyboard access in dialogs (Tab moves focus)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# No press-and-hold accent popup; fast key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Locale
defaults write NSGlobalDomain AppleLanguages -array "en"
defaults write NSGlobalDomain AppleLocale -string "en_US@currency=EUR"
defaults write NSGlobalDomain AppleMeasurementUnits -string "Centimeters"
defaults write NSGlobalDomain AppleMetricUnits -bool true
systemsetup -settimezone "Europe/Paris" > /dev/null

## Screen & Screen Saver -------------------------------------------------------
# Require password immediately after sleep/screensaver
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
# Screensaver after 30 minutes
defaults -currentHost write com.apple.screensaver idleTime -int 1800

# Screenshots → Desktop, PNG, no shadow
defaults write com.apple.screencapture location -string "${HOME}/Desktop"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

# Subpixel font rendering
defaults write NSGlobalDomain AppleFontSmoothing -int 1

# HiDPI display modes (requires restart)
sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true

## Energy — pmset, active settings only ----------------------------------------
sudo pmset -a lidwake 1
sudo pmset -a autorestart 1
sudo pmset -a displaysleep 60        # display after 60 min
sudo pmset -b sleep 20               # machine on battery: 20 min
sudo pmset -a standbydelay 86400     # standby after 24h
sudo pmset proximitywake 0           # no wake from iPhone/Watch

## Spotlight ----------------------------------------------------------- --------
defaults write com.apple.spotlight orderedItems -array \
	'{"enabled" = 1;"name" = "APPLICATIONS";}' \
	'{"enabled" = 1;"name" = "SYSTEM_PREFS";}' \
	'{"enabled" = 0;"name" = "DIRECTORIES";}' \
	'{"enabled" = 0;"name" = "DOCUMENTS";}' \
	'{"enabled" = 0;"name" = "PDF";}' \
	'{"enabled" = 0;"name" = "FONTS";}' \
	'{"enabled" = 0;"name" = "MESSAGES";}' \
	'{"enabled" = 0;"name" = "CONTACT";}' \
	'{"enabled" = 0;"name" = "EVENT_TODO";}' \
	'{"enabled" = 0;"name" = "IMAGES";}' \
	'{"enabled" = 0;"name" = "BOOKMARKS";}' \
	'{"enabled" = 0;"name" = "MUSIC";}' \
	'{"enabled" = 0;"name" = "MOVIES";}' \
	'{"enabled" = 0;"name" = "PRESENTATIONS";}' \
	'{"enabled" = 0;"name" = "SPREADSHEETS";}' \
	'{"enabled" = 0;"name" = "SOURCE";}' \
	'{"enabled" = 0;"name" = "MENU_DEFINITION";}' \
	'{"enabled" = 0;"name" = "MENU_OTHER";}' \
	'{"enabled" = 0;"name" = "MENU_CONVERSION";}' \
	'{"enabled" = 0;"name" = "MENU_EXPRESSION";}' \
	'{"enabled" = 0;"name" = "MENU_WEBSEARCH";}' \
	'{"enabled" = 0;"name" = "MENU_SPOTLIGHT_SUGGESTIONS";}'

# Rebuild the index so the new rules take effect
killall mds > /dev/null 2>&1
sudo mdutil -i on / > /dev/null
sudo mdutil -E / > /dev/null

## Other apps ------------------------------------------------------------------
# Time Machine: don't offer new disks as backup
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# Activity Monitor
defaults write com.apple.ActivityMonitor OpenMainWindow -bool true
defaults write com.apple.ActivityMonitor IconType -int 5
defaults write com.apple.ActivityMonitor ShowCategory -int 0
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

# Photos doesn't auto-open on device plug-in
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

# App Store: no auto-updates/reboots
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1
defaults write com.apple.commerce AutoUpdate -bool false
defaults write com.apple.commerce AutoUpdateRestartRequired -bool false

# Xcode: show build duration
defaults write com.apple.dt.Xcode ShowBuildOperationDuration -bool true

## Apply -----------------------------------------------------------------------
killall Dock Finder SystemUIServer >/dev/null 2>&1 || true
echo "macOS defaults applied — some changes require a logout/restart."
