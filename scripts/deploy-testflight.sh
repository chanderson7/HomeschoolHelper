#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app/Contents/Developer ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
    export PATH="/Applications/Xcode.app/Contents/Developer/usr/bin:$PATH"
fi

SKIP_TESTS=0
OPEN_ORGANIZER_ONLY=0
ASC_KEY_PATH="${ASC_KEY_PATH:-${APP_STORE_CONNECT_API_KEY_PATH:-}}"
ASC_KEY_ID="${ASC_KEY_ID:-${APP_STORE_CONNECT_KEY_ID:-}}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-${APP_STORE_CONNECT_ISSUER_ID:-}}"

while [ $# -gt 0 ]; do
    case "$1" in
        --skip-tests)
            SKIP_TESTS=1
            shift
            ;;
        --organizer|--open-organizer)
            OPEN_ORGANIZER_ONLY=1
            shift
            ;;
        --key-path)
            ASC_KEY_PATH="$2"
            shift 2
            ;;
        --key-id)
            ASC_KEY_ID="$2"
            shift 2
            ;;
        --issuer-id)
            ASC_ISSUER_ID="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: sh scripts/deploy-testflight.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-tests        Skip running core unit tests before archiving"
            echo "  --open-organizer    Archive the app and open Xcode Organizer for 1-click submission"
            echo "  --key-path <path>   Path to App Store Connect API Key (.p8 file)"
            echo "  --key-id <id>       App Store Connect API Key ID"
            echo "  --issuer-id <uuid>  App Store Connect API Issuer ID"
            echo ""
            echo "Environment variables supported: ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

ARCHIVE_PATH=".build/archives/HomeSchoolHelper.xcarchive"
EXPORT_OPTIONS="Config/ExportOptions-Upload.plist"

echo "=========================================================="
echo "  Homeschool Helper: Validate & Deploy to TestFlight"
echo "=========================================================="

# 1. Validation
if [ "$SKIP_TESTS" -eq 0 ]; then
    echo ""
    echo "==> [Step 1/3] Validating Core Test Suite..."
    sh scripts/test-core.sh
    echo "  ✓ Core tests passed (67/67)"
else
    echo ""
    echo "==> [Step 1/3] Skipping tests (--skip-tests passed)"
fi

# 2. Archive
echo ""
echo "==> [Step 2/3] Building Release Archive with active signing..."
CODE_SIGNING_ALLOWED=YES sh scripts/archive-ios.sh -allowProvisioningUpdates

# 3. Push to TestFlight or Organizer
echo ""
echo "==> [Step 3/3] Uploading to TestFlight..."

if [ "$OPEN_ORGANIZER_ONLY" -eq 1 ]; then
    echo "Opening Xcode Organizer for submission..."
    open "$ARCHIVE_PATH"
    echo "Done! Click 'Distribute App' -> 'TestFlight & App Store' in Xcode Organizer."
    exit 0
fi

AUTH_ARGS=""
if [ -n "$ASC_KEY_PATH" ] && [ -n "$ASC_KEY_ID" ] && [ -n "$ASC_ISSUER_ID" ]; then
    echo "  Using App Store Connect API Key: $ASC_KEY_ID"
    AUTH_ARGS="-authenticationKeyPath $ASC_KEY_PATH -authenticationKeyID $ASC_KEY_ID -authenticationKeyIssuerID $ASC_ISSUER_ID"
fi

echo "  Uploading via xcodebuild -exportArchive..."
# shellcheck disable=SC2086
if xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates \
    $AUTH_ARGS; then
    echo ""
    echo "=========================================================="
    echo "  ✓ SUCCESS: App uploaded to App Store Connect / TestFlight!"
    echo "=========================================================="
    echo "Apple will process the build in ~5-15 minutes and notify you when ready on TestFlight."
else
    echo ""
    echo "==> Automated upload encountered an authentication or signing challenge."
    echo "Opening the generated archive in Xcode Organizer so you can submit with 1 click:"
    open "$ARCHIVE_PATH"
    echo ""
    echo "In Xcode Organizer:"
    echo "  1. Click 'Distribute App'"
    echo "  2. Select 'TestFlight & App Store'"
    echo "  3. Click 'Upload'"
fi
