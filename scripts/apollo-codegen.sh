#!/usr/bin/env bash
# Regenerate the iOS app's typed GraphQL code from shared/schema.graphql.
#
# `apollo-ios-cli` is not installed system-wide: it ships inside the Apollo iOS
# package that SwiftPM checks out for the Xcode project, so its path depends on
# the DerivedData folder Xcode picked. Resolve it here rather than asking every
# caller to hunt for it — and pin it to *this* project's checkout, since another
# project's copy is likely a different, incompatible CLI version.
set -euo pipefail

cd "$(dirname "$0")/.."

# Every lookup ends in `|| true`: `find` on a missing directory fails, and under
# `set -e` with `pipefail` that kills the script mid-assignment — silently, before
# reaching the diagnostics below. Which is precisely how a first CI run failed with
# no message at all.
# A newline-separated string, not an array: `"${array[@]}"` on an empty array is an
# unbound variable under `set -u` in the bash macOS ships, so the diagnostic would
# itself crash exactly when it is needed.
searched=""

look_in() {
  searched="${searched}  $1"$'\n'
  [ -d "$1" ] || return 0
  find "$1" -name apollo-ios-cli -type f 2>/dev/null | head -1 || true
}

# CI resolves packages into a path of its own choosing (`-derivedDataPath`), so look
# there first when it says where. A developer machine leaves them under the global
# DerivedData and needs no variable.
cli=""
if [ -n "${DERIVED_DATA_PATH:-}" ]; then
  cli=$(look_in "$DERIVED_DATA_PATH/SourcePackages/checkouts/apollo-ios/CLI")
fi

# A derived-data folder inside the repo, which is what CI asks xcodebuild for. Probed
# without being told: relying on an environment variable surviving a `bun run` cost
# two release attempts, and this needs no variable at all.
if [ -z "$cli" ]; then
  for candidate in build/*; do
    [ -d "$candidate" ] || continue
    cli=$(look_in "$candidate/SourcePackages/checkouts/apollo-ios/CLI")
    [ -n "$cli" ] && break
  done
fi

if [ -z "$cli" ]; then
  searched="${searched}  $HOME/Library/Developer/Xcode/DerivedData/Shuhari-*/SourcePackages/checkouts/apollo-ios/CLI"$'\n'
  for candidate in "$HOME"/Library/Developer/Xcode/DerivedData/Shuhari-*; do
    [ -d "$candidate" ] || continue
    cli=$(look_in "$candidate/SourcePackages/checkouts/apollo-ios/CLI")
    [ -n "$cli" ] && break
  done
fi

if [ -z "$cli" ]; then
  cli=$(command -v apollo-ios-cli || true)
fi

if [ -z "$cli" ]; then
  echo "apollo-ios-cli not found. Looked in:" >&2
  printf '%s' "$searched" >&2
  echo "Build the Xcode project once so SwiftPM checks out apollo-ios, then retry," >&2
  echo "or point DERIVED_DATA_PATH at a folder where they are already resolved." >&2
  exit 1
fi

# Absolute before the `cd`: a path found under ./build is relative to the repo root
# and stops resolving the moment we step into ios/.
cli="$(cd "$(dirname "$cli")" && pwd)/$(basename "$cli")"

echo "Using $cli"
cd ios && "$cli" generate
