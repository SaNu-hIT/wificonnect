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

Projects come from **Claude Code**: every minute the app reads new lines of the session logs in
`~/.claude/projects` and lists each repo you worked in, most recent first. Status is live git
state (`main · 3 uncommitted · 1 unpushed`); the next step is the title of the latest session in
that repo. Subfolders count as their git repo, or outside git as the top folder under where the
session was started. Temporary folders, hidden folders and folders that only hold other projects
(like `~/apps`) are skipped. The first scan reads the whole history once (a few seconds); later
ones read only what was added.

`~/Documents/WifiADB/work.json` (menu bar → **Open work.json**) adds your own details on top:

```json
{
  "focus": "tekto_app",
  "hide": ["thottam-marketing"],
  "projects": [
    { "name": "tekto_app", "next": "Ship 2.0", "due": "2026-10-10" },
    { "name": "Taxes", "status": "gather receipts", "due": "2026-10-31" }
  ]
}
```

- `focus` — project shown big at the top; default: the most recently active one.
- `hide` — names to leave out.
- `projects` — an entry named like a found project replaces its `status` / `next` and adds `due`;
  other entries are added after the found ones. All fields except `name` are optional.
- `"claudeCode": false` — list only `projects`.

The app re-reads the file within 3 seconds of a change.

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
- Break log: `~/Library/Group Containers/3JJ3V54F69.com.wifiadb.shared/activity.json`.
- Widgets cannot play sound or animate flips; the menu bar app plays the sound.

### Build

1. Open `WifiADBWidget/WifiADBWidget.xcodeproj`.
2. Project → both targets → **Signing & Capabilities** → set your **Team**.
   If the bundle IDs `com.wifiadb.app` / `com.wifiadb.app.widget` clash, rename them (the widget
   ID must be the app ID plus a suffix).
3. The App Group is prefixed with the team ID (`3JJ3V54F69.com.wifiadb.shared`), which macOS
   allows without a provisioning profile. With a different team, change the prefix in **both**
   `.entitlements` files and in `appGroupID` in `Shared/TimerStore.swift`. A plain `group.…` ID
   only works if the signing profile lists it; otherwise the sandbox blocks the widget from the
   shared data and it shows up empty.
4. Run the **WifiADB** scheme once (it only shows a menu bar icon). Then right-click the desktop →
   **Edit Widgets** → search **Work Buddy** → add the large widget.
