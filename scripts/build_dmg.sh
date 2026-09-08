#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== Building BarBoss DMG Distribution ==="

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
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    build

APP_PATH="${DERIVED_DATA}/Build/Products/Release/BarBoss.app"
if [ ! -d "${APP_PATH}" ]; then
    echo "Error: BarBoss.app not found at ${APP_PATH}"
    exit 1
fi

echo "BarBoss.app built successfully at: ${APP_PATH}"

# 4. Sign app and frameworks ad-hoc for local execution
echo "Code signing BarBoss.app (ad-hoc)..."
codesign --force --deep --sign - "${APP_PATH}"

# 5. Prepare staging folder for DMG
DMG_ROOT="${BUILD_DIR}/dmg_root"
mkdir -p "${DMG_ROOT}"
cp -R "${APP_PATH}" "${DMG_ROOT}/"
ln -s /Applications "${DMG_ROOT}/Applications"

# 6. Create DMG
DMG_OUTPUT="${BUILD_DIR}/BarBoss.dmg"
echo "Creating disk image (UDZO compressed)..."
rm -f "${DMG_OUTPUT}"
hdiutil create \
    -volname "BarBoss" \
    -srcfolder "${DMG_ROOT}" \
    -ov \
    -format UDZO \
    "${DMG_OUTPUT}"

echo "=== DMG Build Complete! ==="
echo "Artifact: ${DMG_OUTPUT}"
ls -lh "${DMG_OUTPUT}"
