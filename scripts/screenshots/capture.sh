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

# `simctl boot` alone starts a headless simulator: an app launched into it runs, but
# nothing composes it to the screen, and every capture comes back showing SpringBoard.
# That shipped to App Store Connect once. Opening the Simulator UI is what makes the
# framebuffer show the foreground app.
# Best-effort, and deliberately not fatal: Xcode moves this app around — 27 replaced
# it with DeviceHub and ships no Simulator.app at all — and a machine whose UI is
# already running needs none of this. A capture that really did fail is caught by the
# SpringBoard check below, which is the guarantee; this is only the remedy.
step "opening the Simulator UI"
simulator_app=""
for candidate in \
  "$(xcode-select -p)/Applications/Simulator.app" \
  "$(xcode-select -p)/../Applications/Simulator.app"; do
  [ -d "$candidate" ] && simulator_app="$candidate" && break
done

if [ -n "$simulator_app" ]; then
  open -a "$simulator_app" --args -CurrentDeviceUDID "$UDID"
  sleep 15
else
  echo "no Simulator.app under $(xcode-select -p) — continuing headless"
fi

# The store panels are shot in light appearance; the notebook is a light-first app.
step "appearance light"
xcrun simctl ui "$UDID" appearance light

# A fixed status bar: full signal, full battery, and the hour Apple has put on every
# device it has ever photographed. It also makes the captures byte-comparable, which
# the SpringBoard check below relies on.
step "freezing the status bar"
xcrun simctl status_bar "$UDID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4

# Shot before the app is even installed: this is what a failed capture looks like, and
# every capture is checked against it.
step "recording what SpringBoard looks like"
xcrun simctl io "$UDID" screenshot "$OUT_DIR/.springboard.png" >/dev/null
SPRINGBOARD="$(md5 -q "$OUT_DIR/.springboard.png")"

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

  # Polled rather than slept: a cold runner renders far slower than a warm laptop, and
  # a fixed wait produced four blank white panels — the app in front, drawn by nobody.
  # A rendered screen of this app never compresses under ~200 kB; a blank one lands
  # around 70 kB. Crude, dependency-free, and it separates the two cases cleanly.
  captured=""
  for attempt in 1 2 3 4 5 6 7 8; do
    sleep 4
    xcrun simctl io "$UDID" screenshot "$OUT_DIR/$SCREEN.png" >/dev/null 2>&1
    size=$(stat -f%z "$OUT_DIR/$SCREEN.png")
    if [ "$(md5 -q "$OUT_DIR/$SCREEN.png")" = "$SPRINGBOARD" ]; then
      echo "   attempt $attempt: still SpringBoard"
    elif [ "$size" -lt 200000 ]; then
      echo "   attempt $attempt: blank ($size bytes)"
    else
      captured="yes"
      break
    fi
  done

  if [ -z "$captured" ]; then
    echo "'$SCREEN' never rendered — last capture was $(stat -f%z "$OUT_DIR/$SCREEN.png") bytes" >&2
    echo "--- what the app said ---" >&2
    xcrun simctl spawn "$UDID" log show --last 3m --style compact \
      --predicate 'process == "Shuhari"' 2>/dev/null | tail -40 >&2 || true
    exit 1
  fi
  echo "captured $SCREEN ($(stat -f%z "$OUT_DIR/$SCREEN.png") bytes)"
done

rm -f "$OUT_DIR/.springboard.png"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
