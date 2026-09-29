#!/bin/bash
# Builds WifiADB.app (menu bar only, no Dock icon) next to this script.
set -euo pipefail
cd "$(dirname "$0")"

APP=WifiADB.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
# Shared stores are also used by the WidgetKit widget in the Xcode project.
swiftc -O main.swift \
    WifiADBWidget/Shared/TimerStore.swift \
    WifiADBWidget/Shared/DeviceStore.swift \
    WifiADBWidget/Shared/WorkStore.swift \
    -o "$APP/Contents/MacOS/WifiADB"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>WifiADB</string>
    <key>CFBundleIdentifier</key><string>local.wifiadb</string>
    <key>CFBundleExecutable</key><string>WifiADB</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

echo "Built $APP — run: open $APP"
