#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app/Contents/Developer ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
    export PATH="/Applications/Xcode.app/Contents/Developer/usr/bin:$PATH"
fi

DESTINATION="${1:-platform=iOS Simulator,name=iPhone 17 Pro,OS=latest}"
OUTPUT_DIR="AppStoreScreenshots"
RAW_DIR=".build/raw_screenshots"
RESULT_BUNDLE=".build/screenshots.xcresult"

echo "==> Preparing App Store Screenshot Generation..."
mkdir -p "$OUTPUT_DIR"
rm -rf "$RESULT_BUNDLE" "$RAW_DIR"

echo "==> Running Marketing Screenshot UI Test on $DESTINATION..."
xcodebuild test \
    -project HomeSchoolHelper.xcodeproj \
    -scheme HomeSchoolHelper \
    -configuration Debug \
    -destination "$DESTINATION" \
    -derivedDataPath .build/xcode \
    -resultBundlePath "$RESULT_BUNDLE" \
    -only-testing:HomeSchoolHelperUITests/HomeSchoolHelperUITests/testAppStoreMarketingScreenshots \
    CODE_SIGNING_ALLOWED=NO \
    ONLY_ACTIVE_ARCH=YES

echo "==> Exporting screenshot attachments with xcresulttool..."
xcrun xcresulttool export attachments \
    --path "$RESULT_BUNDLE" \
    --output-path "$RAW_DIR"

echo "==> Organizing screenshots into $OUTPUT_DIR..."
python3 -c "
import json
import os
import shutil

raw_dir = '$RAW_DIR'
output_dir = '$OUTPUT_DIR'
manifest_path = os.path.join(raw_dir, 'manifest.json')

if os.path.exists(manifest_path):
    with open(manifest_path, 'r') as f:
        manifest = json.load(f)

    count = 0
    # Process attachments in test results
    for test in manifest:
        for attachment in test.get('attachments', []):
            suggested = attachment.get('suggestedHumanReadableName', '')
            filename = attachment.get('exportedFileName', '')
            if filename.endswith('.png') and suggested.startswith(('01_', '02_', '03_', '04_', '05_', '06_')):
                target_name = suggested.split('_0_')[0] + '.png'
                src = os.path.join(raw_dir, filename)
                dst = os.path.join(output_dir, target_name)
                if os.path.exists(src):
                    shutil.copy2(src, dst)
                    print(f'  Saved: {dst}')
                    count += 1

    print(f'==> Successfully organized {count} App Store screenshots in {output_dir}/')
else:
    print('Warning: manifest.json not found in exported attachments.')
"

