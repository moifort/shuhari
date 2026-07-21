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

# Every simctl call is announced before it runs. A silent hang here once burned a
# ninety-minute CI job and taught nothing: the log must always say which command was
# in flight when time ran out.
step() { echo "→ $*"; }

echo "--- available '$DEVICE_NAME' simulators ---"
xcrun simctl list devices available | grep -F "$DEVICE_NAME (" || true

UDID="$(xcrun simctl list devices available \
  | grep -F "$DEVICE_NAME (" \
  | head -1 \
  | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"

if [ -z "$UDID" ]; then
  echo "no available '$DEVICE_NAME' simulator" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

step "boot $UDID"
xcrun simctl boot "$UDID" 2>/dev/null || true

# Polled rather than `simctl bootstatus -b`, which waits without a deadline and is
# what the cancelled job was sitting in. Three minutes is generous for a warm runner
# and still fails while the log is worth reading.
step "waiting for the simulator to boot"
deadline=$((SECONDS + 180))
until xcrun simctl list devices | grep "$UDID" | grep -q "(Booted)"; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "the simulator never booted within 180s" >&2
    xcrun simctl list devices | grep -F "$DEVICE_NAME" >&2
    exit 1
  fi
  sleep 2
done
echo "booted"

# The store panels are shot in light appearance; the notebook is a light-first app.
step "appearance light"
xcrun simctl ui "$UDID" appearance light

step "install $APP_PATH"
xcrun simctl install "$UDID" "$APP_PATH"

SCREENS="$(bun --print "JSON.parse(require('fs').readFileSync('$ROOT/scripts/screenshots/panels.json','utf8')).map(p => p.screen).join(' ')")"

for SCREEN in $SCREENS; do
  # simctl launch on an already-running app foregrounds it without re-reading the
  # arguments, which silently returns the previous screen. Terminate first, always.
  step "terminate before $SCREEN"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  sleep 1
  step "launch -gallery $SCREEN"
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -gallery "$SCREEN" >/dev/null
  sleep 6
  step "screenshot $SCREEN"
  xcrun simctl io "$UDID" screenshot "$OUT_DIR/$SCREEN.png" >/dev/null
  echo "captured $SCREEN"
done

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
