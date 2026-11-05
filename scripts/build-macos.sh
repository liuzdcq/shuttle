#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
    echo "This build requires macOS and the full Xcode application." >&2
    exit 1
fi

project_root="$(cd "$(dirname "$0")/.." && pwd)"
build_kind="${1:-universal}"
case "$build_kind" in
    arm64) architectures=(arm64) ;;
    universal) architectures=(arm64 x86_64) ;;
    *) echo "Usage: $0 [arm64|universal]" >&2; exit 2 ;;
esac

output_directory="$project_root/build/$build_kind"
xcodebuild -project "$project_root/Shuttle.xcodeproj" -scheme Shuttle \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath "$output_directory" \
    "ARCHS=${architectures[*]}" ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build

application="$output_directory/Build/Products/Release/Shuttle.app"
executable="$application/Contents/MacOS/Shuttle"
/usr/bin/lipo -verify_arch "${architectures[@]}" "$executable"
/usr/bin/lipo -archs "$executable"

# Ad-hoc signing is enough for a local source build, including Apple silicon.
# A Developer ID identity can be supplied for distribution; notarize separately.
/usr/bin/codesign --force --sign "${SHUTTLE_SIGN_IDENTITY:--}" --options runtime \
    --entitlements "$project_root/Shuttle/Shuttle.entitlements" "$application"
/usr/bin/codesign --verify --strict --verbose=2 "$application"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$application" "$output_directory/Shuttle-$build_kind.zip"
echo "Application: $application"
echo "Archive: $output_directory/Shuttle-$build_kind.zip"
