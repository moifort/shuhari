#!/usr/bin/env bash
# Captures one raw screenshot per panel on the 6.9" simulator the App Store requires.
#
# Usage: scripts/screenshots/capture.sh <path-to-Shuhari.app> <output-dir>
set -euo pipefail

APP_PATH="${1:?usage: capture.sh <app-path> <output-dir>}"
OUT_DIR="${2:?usage: capture.sh <app-path> <output-dir>}"

BUNDLE_ID="com.polyforms.shuhari.app"
DEVICE_NAME="iPhone 17 Pro Max"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

UDID="$(xcrun simctl list devices available \
  | grep -F "$DEVICE_NAME (" \
  | head -1 \
  | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"

if [ -z "$UDID" ]; then
  echo "no available '$DEVICE_NAME' simulator" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
# The store panels are shot in light appearance; the notebook is a light-first app.
xcrun simctl ui "$UDID" appearance light
xcrun simctl install "$UDID" "$APP_PATH"

SCREENS="$(bun --print "JSON.parse(require('fs').readFileSync('$ROOT/scripts/screenshots/panels.json','utf8')).map(p => p.screen).join(' ')")"

for SCREEN in $SCREENS; do
  # simctl launch on an already-running app foregrounds it without re-reading the
  # arguments, which silently returns the previous screen. Terminate first, always.
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  sleep 1
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -gallery "$SCREEN" >/dev/null
  sleep 6
  xcrun simctl io "$UDID" screenshot "$OUT_DIR/$SCREEN.png" >/dev/null
  echo "captured $SCREEN"
done

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
