#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app/Contents/Developer ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
exec xcodebuild test -project HomeSchoolHelper.xcodeproj \
    -scheme HomeSchoolHelper -configuration Debug \
    -destination "${HSH_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=latest}" \
    -derivedDataPath .build/xcode -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES "$@"
