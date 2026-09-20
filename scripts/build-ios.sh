#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app/Contents/Developer ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
exec xcodebuild -project HomeSchoolHelper.xcodeproj \
    -scheme HomeSchoolHelper \
    -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath .build/xcode \
    CODE_SIGNING_ALLOWED=NO build "$@"
