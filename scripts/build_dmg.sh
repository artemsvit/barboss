#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

DEVELOPER_ID="Developer ID Application: Artem Svitelskyi (8KK8V96Q6B)"
KEYCHAIN_PROFILE="BarBossNotarization"

echo "=== Building, Signing, and Notarizing BarBoss DMG Distribution ==="

# 1. Resolve Xcode Developer Directory
if ! xcodebuild -version >/dev/null 2>&1; then
    if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
        export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
    elif [ -d "/Applications/Xcode-beta.app/Contents/Developer" ]; then
        export DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"
    fi
fi

echo "Using Xcode from: ${DEVELOPER_DIR:-$(xcode-select -p)}"

# 2. Regenerate Xcode project
cd "${ROOT_DIR}"
echo "Regenerating Xcode project with xcodegen..."
xcodegen generate

# 3. Clean and build BarBoss in Release mode
BUILD_DIR="${ROOT_DIR}/build"
DERIVED_DATA="${BUILD_DIR}/DerivedData"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

echo "Compiling BarBoss (Release)..."
xcodebuild \
    -project BarBoss.xcodeproj \
    -scheme BarBoss \
    -configuration Release \
    -destination "platform=macOS" \
    -derivedDataPath "${DERIVED_DATA}" \
    DEVELOPMENT_TEAM="8KK8V96Q6B" \
    CODE_SIGN_IDENTITY="${DEVELOPER_ID}" \
    CODE_SIGNING_REQUIRED=YES \
    ENABLE_HARDENED_RUNTIME=YES \
    build

APP_PATH="${DERIVED_DATA}/Build/Products/Release/BarBoss.app"
if [ ! -d "${APP_PATH}" ]; then
    echo "Error: BarBoss.app not found at ${APP_PATH}"
    exit 1
fi

echo "BarBoss.app built successfully at: ${APP_PATH}"

# 4. Ensure Resources and Info.plist are complete
mkdir -p "${APP_PATH}/Contents/Resources"
if [ -f "${ROOT_DIR}/BarBoss/Resources/AppIcon.icns" ]; then
    cp "${ROOT_DIR}/BarBoss/Resources/AppIcon.icns" "${APP_PATH}/Contents/Resources/AppIcon.icns"
fi

echo "Enforcing Info.plist keys..."
plutil -replace LSUIElement -bool YES "${APP_PATH}/Contents/Info.plist"
plutil -replace CFBundleIconFile -string AppIcon "${APP_PATH}/Contents/Info.plist"
plutil -replace CFBundleIconName -string AppIcon "${APP_PATH}/Contents/Info.plist"
plutil -replace SUFeedURL -string "https://barboss.artsvit.com/appcast.xml" "${APP_PATH}/Contents/Info.plist"
plutil -replace SUPublicEDKey -string "0000000000000000000000000000000000000000000=" "${APP_PATH}/Contents/Info.plist"
plutil -replace SUEnableAutomaticChecks -bool YES "${APP_PATH}/Contents/Info.plist"

# 5. Code sign embedded frameworks & app with Developer ID & Hardened Runtime
echo "Deep signing nested frameworks & tools..."
if [ -d "${APP_PATH}/Contents/Frameworks" ]; then
    find "${APP_PATH}/Contents/Frameworks" -type f \( -name "*.dylib" -o -perm +0111 \) -exec codesign --force --options runtime --timestamp --sign "${DEVELOPER_ID}" {} + 2>/dev/null || true
    find "${APP_PATH}/Contents/Frameworks" -type d -name "*.framework" -exec codesign --force --options runtime --timestamp --sign "${DEVELOPER_ID}" {} + 2>/dev/null || true
fi
if [ -d "${APP_PATH}/Contents/Helpers" ]; then
    find "${APP_PATH}/Contents/Helpers" -maxdepth 2 -type d -name "*.app" -exec codesign --force --options runtime --timestamp --sign "${DEVELOPER_ID}" {} + 2>/dev/null || true
fi

echo "Signing BarBoss.app with Developer ID & Hardened Runtime..."
codesign --force --options runtime --timestamp \
    --entitlements "${ROOT_DIR}/BarBoss/Resources/BarBoss.entitlements" \
    --sign "${DEVELOPER_ID}" \
    "${APP_PATH}"

codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

# 6. Prepare staging folder for create-dmg
DMG_STAGING="${BUILD_DIR}/dmg_staging"
mkdir -p "${DMG_STAGING}"
cp -R "${APP_PATH}" "${DMG_STAGING}/"

# 7. Create styled DMG
DMG_OUTPUT="${BUILD_DIR}/BarBoss.dmg"
echo "Creating styled DMG with create-dmg..."
rm -f "${DMG_OUTPUT}"

create-dmg \
    --volname "BarBoss" \
    --volicon "${ROOT_DIR}/BarBoss/Resources/AppIcon.icns" \
    --background "${ROOT_DIR}/scripts/dmg_background.png" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 128 \
    --text-size 13 \
    --icon "BarBoss.app" 175 190 \
    --app-drop-link 485 190 \
    --hide-extension "BarBoss.app" \
    --no-internet-enable \
    --format UDZO \
    --overwrite \
    "${DMG_OUTPUT}" \
    "${DMG_STAGING}"

# 8. Sign DMG
echo "Signing DMG with Developer ID..."
codesign --force --sign "${DEVELOPER_ID}" --timestamp "${DMG_OUTPUT}"

# 9. Notarize DMG with Apple Notary Service
echo "Submitting DMG to Apple Notary Service (profile: ${KEYCHAIN_PROFILE})..."
xcrun notarytool submit "${DMG_OUTPUT}" \
    --keychain-profile "${KEYCHAIN_PROFILE}" \
    --wait

# 10. Staple ticket to DMG
echo "Stapling notarization ticket to DMG..."
xcrun stapler staple "${DMG_OUTPUT}"

# 11. Validate with Gatekeeper Assessment
echo "Validating Gatekeeper acceptance for DMG..."
spctl -a -t open --context context:primary-signature -v "${DMG_OUTPUT}"

echo "=== Notarized DMG Build Complete! ==="
echo "Artifact: ${DMG_OUTPUT}"
ls -lh "${DMG_OUTPUT}"
