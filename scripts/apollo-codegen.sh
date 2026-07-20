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

# CI resolves packages into a path of its own choosing (`-derivedDataPath`), so look
# there first when it says where. A developer machine leaves them under the global
# DerivedData and needs no variable.
cli=""
if [ -n "${DERIVED_DATA_PATH:-}" ]; then
  cli=$(find "$DERIVED_DATA_PATH/SourcePackages/checkouts/apollo-ios/CLI" \
    -name apollo-ios-cli -type f 2>/dev/null | head -1)
fi

if [ -z "$cli" ]; then
  cli=$(find ~/Library/Developer/Xcode/DerivedData/Shuhari-*/SourcePackages/checkouts/apollo-ios/CLI \
    -name apollo-ios-cli -type f 2>/dev/null | head -1)
fi

if [ -z "$cli" ]; then
  cli=$(command -v apollo-ios-cli || true)
fi

if [ -z "$cli" ]; then
  echo "apollo-ios-cli not found." >&2
  echo "Build the Xcode project once so SwiftPM checks out apollo-ios, then retry," >&2
  echo "or point DERIVED_DATA_PATH at a folder where they are already resolved." >&2
  exit 1
fi

echo "Using $cli"
cd ios && "$cli" generate
