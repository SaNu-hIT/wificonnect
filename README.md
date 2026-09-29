# WifiADB

Two things in this repo:

1. **Menu bar app** (`main.swift`, `build.sh`) — no Xcode needed. Lists wireless ADB devices,
   reconnects them, enables Wi‑Fi debugging on USB devices, and shows an always-on-top desktop
   panel with a flip-clock break timer. Activity log: `~/Documents/WifiADB/activity.json`.
2. **WidgetKit widget** (`WifiADBWidget/`) — real macOS desktop widget with the break timer.
   Needs Xcode 16+ and an Apple ID for signing.

## Menu bar app

```bash
./build.sh && open WifiADB.app
```

Requires `adb` in one of: Homebrew `android-commandlinetools`, `~/Library/Android/sdk/platform-tools`,
`/opt/homebrew/bin`, `/usr/local/bin`.

## WidgetKit widget

```
WifiADBWidget/
  WifiADBWidget.xcodeproj
  App/       host app (SwiftUI window with the same timer; required for the widget to exist)
  Widget/    widget extension: timeline provider + widget bundle
  Shared/    TimerStore (App Group state + JSON log), AppIntents for the buttons, flip-clock view
```

### Build

1. Open `WifiADBWidget/WifiADBWidget.xcodeproj`.
2. Select the project → both targets → **Signing & Capabilities** → set your **Team**.
   If the bundle IDs `com.wifiadb.app` / `com.wifiadb.app.widget` clash, rename them (the widget
   ID must be the app ID plus a suffix).
3. If Xcode complains about the App Group, use its suggested team-prefixed name and change it
   in **both** `.entitlements` files and in `appGroupID` in `Shared/TimerStore.swift`.
4. Run the **WifiADB** scheme once. Then right-click the desktop → **Edit Widgets** → search
   **Break Timer** → add the medium or large widget.

### How it works

- Timer state lives in the App Group `UserDefaults`; buttons in the widget are `AppIntent`s that
  update it and reload the widget timeline.
- The countdown uses `Text(timerInterval:)`, so it ticks every second without timeline refreshes.
- At the end the widget turns orange and shows an activity (walk, push-ups, pull-ups…) with
  Done / Skip. The answer is appended to
  `~/Library/Group Containers/<app group>/activity.json` and the same duration restarts.
- Widgets cannot play sound or animate flips; the host app plays a sound if it is open.

This project was written without Xcode available, so it has not been built yet — expect to fix
small things (signing, App Group name) on first open.
