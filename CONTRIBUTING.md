# Contributing

## Prerequisites

- macOS 14.0+
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- An Apple ID signed into Xcode (free account works)

## Getting started

```sh
git clone git@github.com:ianmcnally/meatballrice.git
cd meatballrice
xcodegen generate
open meatballrice.xcodeproj
```

## Project structure

```
meatballrice/
  MeatballriceApp.swift   # App entry point, menu bar setup
  TimerManager.swift      # Timer logic, notifications
  TimerView.swift         # All UI (popover content, slider, buttons)
  Preset.swift            # Timer preset definitions
  Info.plist              # App metadata (LSUIElement for menu-bar-only)
  meatballrice.entitlements
project.yml               # XcodeGen project spec (source of truth)
```

## Code signing

The app must be code-signed for notifications to work. `project.yml` has a `DEVELOPMENT_TEAM` set — if you're building on a different machine, update it to your own team ID:

1. Sign into your Apple ID in **Xcode > Settings > Apple Accounts**
2. Find your team ID:
   ```sh
   security find-certificate -c "Apple Development" -p ~/Library/Keychains/login.keychain-db | openssl x509 -noout -subject
   ```
   The `OU` field is your team ID.
3. Update `DEVELOPMENT_TEAM` in `project.yml`
4. Regenerate: `xcodegen generate`

## Regenerating the Xcode project

The `.xcodeproj` is generated from `project.yml`. After changing `project.yml`:

```sh
xcodegen generate
```

Don't edit `.xcodeproj` directly — changes will be overwritten.

## Building from the command line

```sh
xcodebuild -project meatballrice.xcodeproj -scheme meatballrice build
```

## Running

```sh
open ~/Library/Developer/Xcode/DerivedData/meatballrice-*/Build/Products/Debug/meatballrice.app
```

Or hit Cmd+R in Xcode.

## Releasing

1. Bump `CURRENT_PROJECT_VERSION` in `project.yml` and regenerate:
   ```sh
   xcodegen generate
   ```

2. Build a release binary:
   ```sh
   xcodebuild -scheme meatballrice -configuration Release clean build
   ```

3. Zip the app:
   ```sh
   cd ~/Library/Developer/Xcode/DerivedData/meatballrice-*/Build/Products/Release
   zip -r meatballrice.zip meatballrice.app
   ```

4. Create a GitHub release:
   ```sh
   gh release create vX.Y.Z meatballrice.zip --title "vX.Y.Z" --notes "Release notes here"
   ```

> **Note:** The app is not notarized, so users will need to right-click > Open to bypass Gatekeeper.
