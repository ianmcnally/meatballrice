# meatballrice

A minimal menu bar timer for macOS.

- Lives in the menu bar — no dock icon
- Shows countdown in the menu bar while running, reverts to a timer icon when idle
- Supports presets (25m, 5m, 15m) or custom durations
- Tap the time display to type a custom duration: `25` for 25 minutes, `5:30` for 5m30s, `:30` for 30 seconds
- System notification + sound when the timer completes
- Dismisses the popover automatically when you start a timer

## Requirements

- macOS 14.0+
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Setup

```sh
brew install xcodegen
git clone git@github.com:ianmcnally/meatballrice.git
cd meatballrice
xcodegen generate
open meatballrice.xcodeproj
```

Build and run from Xcode (Cmd+R), or from the command line:

```sh
xcodebuild -project meatballrice.xcodeproj -scheme meatballrice build
open ~/Library/Developer/Xcode/DerivedData/meatballrice-*/Build/Products/Debug/meatballrice.app
```

## Notifications

The app uses `UNUserNotificationCenter` for system notifications. On first launch, macOS will prompt for notification permission. If you don't see the prompt or notifications aren't working:

1. Check **System Settings > Notifications > meatballrice** and enable Allow Notifications
2. Make sure the app is code-signed (see Contributing)
