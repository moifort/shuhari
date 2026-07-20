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

# A newline-separated string, not an array: `"${array[@]}"` on an empty array is an
# unbound variable under `set -u` in the bash macOS ships, so the diagnostic would
# itself crash exactly when it is needed.
searched=""
cli=""

# Sets `cli` when the CLI is in `$1`, and extracts it first when only the shipped
# archive is there — which is the state of a freshly resolved checkout. The binary
# itself is unpacked by Apollo's build plugin, so `-resolvePackageDependencies`
# alone leaves the folder holding nothing but `apollo-ios-cli.tar.gz`.
#
# Never called through `$( )`: a command substitution runs in a subshell, and both
# `cli` and the trail of searched paths would be discarded with it.
ensure_cli() {
  searched="${searched}  $1"$'\n'
  [ -d "$1" ] || return 0
  if [ ! -x "$1/apollo-ios-cli" ] && [ -f "$1/apollo-ios-cli.tar.gz" ]; then
    echo "Unpacking $1/apollo-ios-cli.tar.gz"
    tar -xzf "$1/apollo-ios-cli.tar.gz" -C "$1"
  fi
  [ -x "$1/apollo-ios-cli" ] && cli="$1/apollo-ios-cli"
  return 0
}

# A derived-data folder inside the repo, which is what CI asks xcodebuild for, then
# the global DerivedData a developer machine uses. Both probed without being told:
# relying on an environment variable surviving a `bun run` cost two release attempts.
if [ -n "${DERIVED_DATA_PATH:-}" ]; then
  ensure_cli "$DERIVED_DATA_PATH/SourcePackages/checkouts/apollo-ios/CLI"
fi

if [ -z "$cli" ]; then
  for candidate in build/*; do
    [ -d "$candidate" ] || continue
    ensure_cli "$candidate/SourcePackages/checkouts/apollo-ios/CLI"
    [ -n "$cli" ] && break
  done
fi

if [ -z "$cli" ]; then
  for candidate in "$HOME"/Library/Developer/Xcode/DerivedData/Shuhari-*; do
    [ -d "$candidate" ] || continue
    ensure_cli "$candidate/SourcePackages/checkouts/apollo-ios/CLI"
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
