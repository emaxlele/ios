#!/bin/bash
#
# Run Sourcery for a given framework, ensuring BITWARDEN_SDK_PATH is set so that
# the SDK SPM package sources in sourcery.yml can be resolved.
#
# Usage: ./Scripts/generate-mocks.sh [BitwardenShared|AuthenticatorShared|BitwardenKit|AuthenticatorBridgeKit]
#
# Intended to be run as an Xcode build phase script, where $BUILD_ROOT and $TARGET_NAME
# are already set in the environment by Xcode. When no framework argument is given,
# TARGET_NAME is used to determine which framework's config to run.
#
# To run standalone, supply BUILD_ROOT manually:
#   BUILD_ROOT=$(xcodebuild -showBuildSettings \
#     -workspace Bitwarden.xcworkspace -scheme Bitwarden \
#     -disableAutomaticPackageResolution 2>/dev/null \
#     | awk -F ' = ' '/^ *BUILD_ROOT = / { sub(/[[:space:]]+$/, "", $2); print $2; exit }') \
#   ./Scripts/generate-mocks.sh
#
# BUILD_ROOT = .../DerivedData/Bitwarden-<hash>/Build
# BITWARDEN_SDK_PATH = .../DerivedData/Bitwarden-<hash>/SourcePackages/checkouts/sdk-swift

set -euo pipefail

if [[ ! "$PATH" =~ "/opt/homebrew/bin" ]]; then
    PATH="/opt/homebrew/bin:$PATH"
fi

FRAMEWORK="${1:-${TARGET_NAME:-BitwardenShared}}"
CONFIG="$FRAMEWORK/Sourcery/sourcery.yml"

if [ ! -f "$CONFIG" ]; then
    echo "Error: config not found at $CONFIG"
    exit 1
fi

# BUILD_ROOT is always <DerivedData>/Build regardless of build type. BUILD_DIR changes
# structure during `xcodebuild archive` (deeper into ArchiveIntermediates), so deriving
# the DerivedData root from BUILD_DIR produces the wrong path for archive builds.
if [ -z "${BUILD_ROOT:-}" ]; then
    echo "⚠️  BUILD_ROOT is not set."
    echo "   Run this script from an Xcode build phase, or supply BUILD_ROOT manually."
    echo "   See the script header for instructions."
    exit 1
fi

export BITWARDEN_SDK_PATH
BITWARDEN_SDK_PATH="$(dirname "$BUILD_ROOT")/SourcePackages/checkouts/sdk-swift"

echo "BITWARDEN_SDK_PATH: $BITWARDEN_SDK_PATH"
mint run sourcery --config "$CONFIG"
