#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
    echo "These native AppKit tests require macOS and Xcode." >&2
    exit 1
fi

project_root="$(cd "$(dirname "$0")/.." && pwd)"
test_directory="$(mktemp -d "${TMPDIR:-/tmp}/shuttle-tests.XXXXXX")"
trap 'rm -rf "$test_directory"' EXIT

# Compiles and executes the production startup/menu code in the host's native
# architecture. Tests use isolated configuration files and never run shell hosts.
xcrun clang -fobjc-arc -mmacosx-version-min=13.0 \
    -framework Cocoa -framework ServiceManagement -I "$project_root/Shuttle" \
    "$project_root/tests/RegressionTests.m" "$project_root/Shuttle/AppDelegate.m" \
    "$project_root/Shuttle/LaunchAtLoginController.m" -o "$test_directory/RegressionTests"
"$test_directory/RegressionTests" "$project_root" "$test_directory"
