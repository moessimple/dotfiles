#!/bin/bash

echo ""
warn "This will change macOS system settings."
echo "Close System Settings before continuing."
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Close any open System Preferences panes, to prevent them from overriding
# settings we’re about to change
osascript -e 'tell application "System Preferences" to quit'

# Ask for the administrator password upfront
sudo -v

# Keep-alive: update existing `sudo` time stamp until this script has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

###############################################################################
# Disk Encryption                                                             #
###############################################################################

# Enable FileVault
if [[ $(fdesetup status) == "FileVault is On." ]]; then
    echo "FileVault is already on."
else
    sudo fdesetup enable
fi

###############################################################################
# Application Firewall                                                        #
###############################################################################

# Enable Application Firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# Enable stealth mode
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on

# Don't auto-whitelist apps just because they're signed
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned off
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp off

# Restart the Application Firewall process
sudo pkill -HUP socketfilterfw || true

###############################################################################
# General UI/UX                                                               #
###############################################################################

# Disable the sound effects on boot
sudo nvram SystemAudioVolume=" " || true

# Show remaining battery percentage
defaults write com.apple.menuextra.battery ShowPercent -string "YES"

# Set sidebar icon size to medium
defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 2

# Show scrollbars only while scrolling (other values: `Automatic`, `Always`)
defaults write NSGlobalDomain AppleShowScrollBars -string "WhenScrolling"

# Increase window resize speed for Cocoa applications
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Save to disk (not to iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Keep Gatekeeper quarantine active for downloaded files
defaults write com.apple.LaunchServices LSQuarantine -bool true

# Disable Resume system-wide
defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool false

# Disable automatic termination of inactive apps
defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true

# Set Help Viewer windows to non-floating mode
defaults write com.apple.helpviewer DevMode -bool true

# Don't reveal system info on the login window clock
sudo defaults delete /Library/Preferences/com.apple.loginwindow AdminHostInfo 2>/dev/null || true

# Disable smart quotes as they’re annoying when typing code
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Disable smart dashes as they’re annoying when typing code
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

###############################################################################
# Trackpad, mouse, keyboard, Bluetooth accessories, and input                 #
###############################################################################

# Enable “natural” (Lion-style) scrolling
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool true

# Pointer speed
defaults write -g com.apple.mouse.scaling -float 1.0

# macOS reads mouse gesture settings from both domains depending on context;
# both must be written to ensure settings are applied after login.
for mouse_domain in \
    "com.apple.driver.AppleBluetoothMultitouch.mouse" \
    "com.apple.AppleMultitouchMouse"; do
    defaults write "$mouse_domain" MouseButtonMode             TwoButton
    defaults write "$mouse_domain" MouseOneFingerDoubleTapGesture -int 0
    defaults write "$mouse_domain" MouseTwoFingerHorizSwipeGesture -int 2
    defaults write "$mouse_domain" MouseTwoFingerDoubleTapGesture  -int 3
done

# Increase sound quality for Bluetooth headphones/headsets
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Max (editable)" 80
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" 80
defaults write com.apple.BluetoothAudioAgent "Apple Initial Bitpool (editable)" 80
defaults write com.apple.BluetoothAudioAgent "Apple Initial Bitpool Min (editable)" 80
defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool" 80
defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool Max" 80
defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool Min" 80

# Enable full keyboard access for all controls
# (e.g. enable Tab in modal dialogs)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Set language and text formats
# Note: defaults to Germany, replace `de`/`de_DE`/`EUR`/`Centimeters` with your own locale.
defaults write NSGlobalDomain AppleLanguages -array "de"
defaults write NSGlobalDomain AppleLocale -string "de_DE@currency=EUR"
defaults write NSGlobalDomain AppleMeasurementUnits -string "Centimeters"
defaults write NSGlobalDomain AppleMetricUnits -bool true

# Set the timezone; see `systemsetup -listtimezones` for other values
sudo systemsetup -settimezone "Europe/Berlin" > /dev/null 2>&1

###############################################################################
# SSD-specific tweaks                                                         #
###############################################################################

# Disable hibernation (speeds up entering sleep mode)
sudo pmset -a hibernatemode 0

# Disable the sudden motion sensor as it’s not useful for SSDs
sudo pmset -a sms 0

###############################################################################
# Screen                                                                      #
###############################################################################

# Require password immediately after sleep or screen saver begins
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Enable HiDPI display modes (requires restart)
sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true

# Re-enable subpixel antialiasing
defaults -currentHost write -globalDomain AppleFontSmoothing -int 2
defaults write -g CGFontRenderingFontSmoothingDisabled -bool false

# Save To Screenshots Folder
defaults write com.apple.screencapture location ~/Screenshots

# Exclude date and time in screenshot filenames
defaults write com.apple.screencapture "include-date" -bool false

# Save screenshots in JPG format (other options: BMP, GIF, PDF, PNG, TIFF)
defaults write com.apple.screencapture type -string "jpg"

# Change screenshot filename pattern
defaults write com.apple.screencapture name 'screenshot'

# Disable shadow in screenshots
defaults write com.apple.screencapture disable-shadow -bool true

###############################################################################
# Finder                                                                      #
###############################################################################

# Set Desktop as the default location for new Finder windows
# For other paths, use `PfLo` and `file:///full/path/here/`
defaults write com.apple.finder NewWindowTarget -string "PfDe"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Desktop/"

# Show icons for hard drives, servers, and removable media on the desktop
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Finder: allow text selection in Quick Look
defaults write com.apple.finder QLEnableTextSelection -bool true

# Display full POSIX path as Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# When performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Avoid creating .DS_Store files on network volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# Verify disk image checksums
defaults write com.apple.frameworks.diskimages skip-verify -bool false
defaults write com.apple.frameworks.diskimages skip-verify-locked -bool false
defaults write com.apple.frameworks.diskimages skip-verify-remote -bool false

# Enable snap-to-grid for icons on the desktop and in other icon views
for scope in DesktopViewSettings FK_StandardViewSettings StandardViewSettings; do
    /usr/libexec/PlistBuddy -c "Set :${scope}:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null ||
        /usr/libexec/PlistBuddy -c "Add :${scope}:IconViewSettings:arrangeBy string grid" ~/Library/Preferences/com.apple.finder.plist
done

# Increase grid spacing for icons on the desktop and in other icon views
for scope in DesktopViewSettings FK_StandardViewSettings StandardViewSettings; do
    /usr/libexec/PlistBuddy -c "Set :${scope}:IconViewSettings:gridSpacing 100" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null ||
        /usr/libexec/PlistBuddy -c "Add :${scope}:IconViewSettings:gridSpacing real 100" ~/Library/Preferences/com.apple.finder.plist
done

# Increase the size of icons on the desktop and in other icon views
for scope in DesktopViewSettings FK_StandardViewSettings StandardViewSettings; do
    /usr/libexec/PlistBuddy -c "Set :${scope}:IconViewSettings:iconSize 80" ~/Library/Preferences/com.apple.finder.plist 2>/dev/null ||
        /usr/libexec/PlistBuddy -c "Add :${scope}:IconViewSettings:iconSize real 80" ~/Library/Preferences/com.apple.finder.plist
done

# Use icon view in all Finder windows by default
# Four-letter codes for the other view modes: `Nlsv` (list), `clmv` (column), `Flwv` (cover flow)
defaults write com.apple.finder FXPreferredViewStyle -string "icnv"

# Disable the warning before emptying the Trash
defaults write com.apple.finder WarnOnEmptyTrash -bool false

# Show the ~/Library folder
chflags nohidden ~/Library

# Show the ~/Users folder
chflags nohidden /Users

# Expand the following File Info panes:
# “General”, “Open with”, and “Sharing & Permissions”
defaults write com.apple.finder FXInfoPanesExpanded -dict \
	General -bool true \
	OpenWith -bool true \
	Privileges -bool true

###############################################################################
# Dock, Dashboard, and hot corners                                            #
###############################################################################

# Enable highlight hover effect for the grid view of a stack (Dock)
defaults write com.apple.dock mouse-over-hilite-stack -bool true

# Prevent applications from bouncing in Dock
defaults write com.apple.dock no-bouncing -bool true

# Set the icon size of Dock items to 80 pixels
defaults write com.apple.dock tilesize -int 80

# Hide indicator lights for open applications in the Dock
defaults write com.apple.dock show-process-indicators -bool true

# Disable Dashboard
defaults write com.apple.dashboard mcx-disabled -bool true

# Don’t show Dashboard as a Space
defaults write com.apple.dock dashboard-in-overlay -bool true

# Don’t automatically rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false

# Make Dock icons of hidden applications translucent
defaults write com.apple.dock showhidden -bool true

# Don't show suggested and recent apps in Dock
defaults write com.apple.dock show-recents -bool false

###############################################################################
# Safari & WebKit                                                             #
###############################################################################

# Enable Safari’s debug menu
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true

# Show the full URL in the address bar (note: this still hides the scheme)
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

# Enable the Develop menu and the Web Inspector in Safari
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

# Update extensions automatically
defaults write com.apple.Safari InstallExtensionUpdatesAutomatically -bool true

###############################################################################
# Mail                                                                        #
###############################################################################

# Disable send and reply animations in Mail.app
defaults write com.apple.mail DisableReplyAnimations -bool true
defaults write com.apple.mail DisableSendAnimations -bool true

# Copy email addresses as `foo@example.com` instead of `Foo Bar <foo@example.com>` in Mail.app
defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false

# Disable inline attachments (just show the icons)
defaults write com.apple.mail DisableInlineAttachmentViewing -bool true

# Disable automatic spell checking
defaults write com.apple.mail SpellCheckingBehavior -string "NoSpellCheckingEnabled"

###############################################################################
# Terminal & iTerm 2                                                          #
###############################################################################

# Only use UTF-8 in Terminal.app
defaults write com.apple.terminal StringEncodings -array 4

# Enable Secure Keyboard Entry in Terminal.app
# See: https://security.stackexchange.com/a/47786/8918
defaults write com.apple.terminal SecureKeyboardEntry -bool true

# Disable the annoying line marks
defaults write com.apple.Terminal ShowLineMarks -int 0

# Don’t display the annoying prompt when quitting iTerm
defaults write com.googlecode.iterm2 PromptOnQuit -bool false

###############################################################################
# Time Machine                                                                #
###############################################################################

# Prevent Time Machine from prompting to use new hard drives as backup volume
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

###############################################################################
# Activity Monitor                                                            #
###############################################################################

# Show the main window when launching Activity Monitor
defaults write com.apple.ActivityMonitor OpenMainWindow -bool true

# Visualize CPU usage in the Activity Monitor Dock icon
defaults write com.apple.ActivityMonitor IconType -int 5

# Show all processes in Activity Monitor
defaults write com.apple.ActivityMonitor ShowCategory -int 0

# Sort Activity Monitor results by CPU usage
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

###############################################################################
# Address Book, Dashboard, iCal, TextEdit, and Disk Utility                   #
###############################################################################

# Use plain text mode for new TextEdit documents
defaults write com.apple.TextEdit RichText -int 0

# Open and save files as UTF-8 in TextEdit
defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4

# Show 24 hours a day
defaults write com.apple.ical "number of hours displayed" 24

# Week should start on Monday
defaults write com.apple.ical "first day of the week" 1

# Day starts at 9AM
defaults write com.apple.ical "first minute of work hours" 540

###############################################################################
# Date & Time                                                                 #
###############################################################################

# Menu bar clock format, e.g. "Wed Jan 5  14:32"
defaults write com.apple.menuextra.clock DateFormat "EEE MMM d  H:mm"

###############################################################################
# Mac App Store                                                               #
###############################################################################

# Enable the WebKit Developer Tools in the Mac App Store
defaults write com.apple.appstore WebKitDeveloperExtras -bool true

# Enable the automatic update check
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

# Check for software updates daily, not just once per week
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

# Download newly available updates in background
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1

# Install System data files & security updates
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1

# Turn on app auto-update
defaults write com.apple.commerce AutoUpdate -bool true

###############################################################################
# Photos                                                                      #
###############################################################################

# Prevent Photos from opening automatically when devices are plugged in
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

###############################################################################
# Messages                                                                    #
###############################################################################

# Disable automatic emoji substitution (i.e. use plain text smileys)
defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "automaticEmojiSubstitutionEnablediMessage" -bool false

# Disable smart quotes as it’s annoying for messages that contain code
defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "automaticQuoteSubstitutionEnabled" -bool false

# Disable continuous spell checking
defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "continuousSpellCheckingEnabled" -bool false

###############################################################################
# Google Chrome & Google Chrome Canary                                        #
###############################################################################

# Expand the print dialog by default
defaults write com.google.Chrome PMPrintingExpandedStateForPrint2 -bool true
defaults write com.google.Chrome.canary PMPrintingExpandedStateForPrint2 -bool true

###############################################################################
# Kill affected applications                                                  #
###############################################################################

for app in "Activity Monitor" \
    "Address Book" \
    "Calendar" \
    "cfprefsd" \
    "Contacts" \
    "Dock" \
    "Finder" \
    "Google Chrome" \
    "Mail" \
    "Messages" \
    "Photos" \
    "Safari" \
    "SystemUIServer" \
    "Terminal" \
    "iCal"; do
    killall "${app}" &> /dev/null || true
done

echo ""
success "macOS defaults configured!"
echo ""
warn "Some changes require a logout/restart to take effect."
echo ""
