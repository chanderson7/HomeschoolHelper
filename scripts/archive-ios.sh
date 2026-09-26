#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app/Contents/Developer ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
    export PATH="/Applications/Xcode.app/Contents/Developer/usr/bin:$PATH"
fi

ARCHIVE_PATH="${ARCHIVE_PATH:-.build/archives/HomeSchoolHelper.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-.build/ipa}"
CONFIG="${CONFIG:-Release}"
SCHEME="HomeSchoolHelper"
PROJECT="HomeSchoolHelper.xcodeproj"
EXPORT_OPTIONS="${EXPORT_OPTIONS:-Config/ExportOptions-AppStore.plist}"

echo "==> Preparing Release Archive Build..."
mkdir -p "$(dirname "$ARCHIVE_PATH")"
rm -rf "$ARCHIVE_PATH"

echo "==> Archiving $SCHEME ($CONFIG) for generic iOS device..."
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    -derivedDataPath .build/xcode \
    CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}" \
    "$@"

echo "==> Validating Archive at $ARCHIVE_PATH..."
APP_DIR="$ARCHIVE_PATH/Products/Applications/HomeSchoolHelper.app"
if [ ! -d "$APP_DIR" ]; then
    echo "Error: Archive did not contain HomeSchoolHelper.app at $APP_DIR" >&2
    exit 1
fi

BUNDLE_ID=$(defaults read "$APP_DIR/Info.plist" CFBundleIdentifier 2>/dev/null || echo "com.andersonsites.homeschoolhelper")
VERSION=$(defaults read "$APP_DIR/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "0.1.0")
BUILD=$(defaults read "$APP_DIR/Info.plist" CFBundleVersion 2>/dev/null || echo "1")

echo "  Bundle Identifier: $BUNDLE_ID"
echo "  Marketing Version: $VERSION"
echo "  Build Version:     $BUILD"
echo "  Archive Size:      $(du -sh "$ARCHIVE_PATH" | cut -f1)"

if [ -d "$ARCHIVE_PATH/dSYMs" ]; then
    echo "  dSYMs found:       $(ls "$ARCHIVE_PATH/dSYMs" | tr '\n' ' ')"
    echo ""
fi

echo "==> Release Archive created successfully!"
echo ""
echo "Distribution Next Steps:"
echo "  1. Double-click or open in Xcode Organizer to validate and submit to TestFlight:"
echo "     open \"$ARCHIVE_PATH\""
echo ""
echo "  2. To export an IPA locally (requires active Developer certificate):"
echo "     xcodebuild -exportArchive -archivePath \"$ARCHIVE_PATH\" -exportPath \"$EXPORT_PATH\" -exportOptionsPlist \"$EXPORT_OPTIONS\""
echo ""
echo "  3. To upload an exported IPA via altool (App Store Connect API Key):"
echo "     xcrun altool --upload-app -f \"$EXPORT_PATH/HomeSchoolHelper.ipa\" -t ios --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>"
echo ""
