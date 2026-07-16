#!/usr/bin/env bash
#
# Build, install and launch the Shuhari app on the physical iPhone
# "TiPhone junior". On-demand dev helper — not part of the CI/release flow.
#
# Usage: scripts/install-device.sh
#
set -euo pipefail

DEVICE_ID="00008130-000A2068029A001C" # TiPhone junior (iPhone 15 Pro)
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

echo "==> Building for device ${DEVICE_ID}"
xcodebuild -project ios/Shuhari.xcodeproj -scheme Shuhari \
  -destination "platform=iOS,id=${DEVICE_ID}" \
  -derivedDataPath build/device build

APP="build/device/Build/Products/Debug-iphoneos/Shuhari.app"

echo "==> Installing ${APP}"
xcrun devicectl device install app "$APP" --device "$DEVICE_ID"

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")

echo "==> Launching ${BUNDLE_ID}"
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"
