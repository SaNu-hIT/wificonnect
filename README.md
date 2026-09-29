# WifiADB

Menu bar app for wireless ADB plus a desktop "work buddy" widget.

- **Menu bar app** (`main.swift`, `build.sh`) — no Xcode needed. Lists wireless ADB devices,
  reconnects them (including port changes via mDNS), enables Wi‑Fi debugging on USB devices,
  and shows an always-on-top panel with a flip-clock break timer.
- **WidgetKit widget** (`WifiADBWidget/`) — real macOS desktop widget: work summary, break timer,
  wireless device list. Needs Xcode 16+ and an Apple ID for signing. The menu bar app is its host.

## Menu bar app

```bash
./build.sh && open WifiADB.app
```

Requires `adb` in one of: Homebrew `android-commandlinetools`, `~/Library/Android/sdk/platform-tools`,
`/opt/homebrew/bin`, `/usr/local/bin`.

## Work buddy

The app creates `~/Documents/WifiADB/work.json` on first run (menu bar → **Open work.json**):

```json
{
  "focus": "wificonnect",
  "projects": [
    { "name": "wificonnect", "status": "in progress", "next": "Build the widget", "due": "2026-10-05" }
  ]
}
```

`focus` names the project shown big at the top; the rest are listed below it with status, next
step and days left. All fields except `name` are optional. The app re-reads the file within
3 seconds of a change.

## Widget

```
WifiADBWidget/
  WifiADBWidget.xcodeproj
  App/       entitlements only — the app target compiles ../main.swift (the menu bar app)
  Widget/    widget extension: timeline provider, views, Info.plist
  Shared/    TimerStore, DeviceStore, WorkStore (App Group state) and the AppIntents for buttons
```

- **Medium** size: break timer. **Large** size: work buddy + break timer + wireless devices.
- Timer state, device list and work data live in the App Group; the app writes, the widget reads.
  Timer buttons are `AppIntent`s that change the shared state directly, so the panel and the
  widget always agree.
- The widget cannot run adb. Its Reconnect / Disconnect buttons queue a command in the App Group
  and launch the menu bar app if needed; the app runs it on its next poll (≤ 3 s).
- Break log: `~/Library/Group Containers/group.com.wifiadb.shared/activity.json`.
- Widgets cannot play sound or animate flips; the menu bar app plays the sound.

### Build

1. Open `WifiADBWidget/WifiADBWidget.xcodeproj`.
2. Project → both targets → **Signing & Capabilities** → set your **Team**.
   If the bundle IDs `com.wifiadb.app` / `com.wifiadb.app.widget` clash, rename them (the widget
   ID must be the app ID plus a suffix).
3. If Xcode complains about the App Group, use its suggested team-prefixed name in **both**
   `.entitlements` files and in `appGroupID` in `Shared/TimerStore.swift`.
4. Run the **WifiADB** scheme once (it only shows a menu bar icon). Then right-click the desktop →
   **Edit Widgets** → search **Work Buddy** → add the large widget.

The Xcode project was written without Xcode available and has not been built there yet; expect
small fixes (signing, App Group name) on first open. The menu bar app and the shared code are
built and tested with `swiftc`.
