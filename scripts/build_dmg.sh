#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

DEVELOPER_ID="Developer ID Application: Artem Svitelskyi (8KK8V96Q6B)"
KEYCHAIN_PROFILE="BarBossNotarization"

echo "=== Building, Signing, and Notarizing BarBoss DMG Distribution ==="

# 1. Resolve Xcode Developer Directory
if ! xcodebuild -version >/dev/null 2>&1; then
    for candidate in \
        "/Applications/Xcode-beta.app/Contents/Developer" \
        "/Applications/Xcode.app/Contents/Developer"; do
        if [ -x "${candidate}/usr/bin/xcodebuild" ] && \
           DEVELOPER_DIR="${candidate}" "${candidate}/usr/bin/xcodebuild" -version >/dev/null 2>&1; then
            export DEVELOPER_DIR="${candidate}"
            break
        fi
    done
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
APP_VERSION="$(awk -F'"' '/MARKETING_VERSION:/ {print $2; exit}' "${ROOT_DIR}/project.yml")"
APP_BUILD="$(awk -F'"' '/CURRENT_PROJECT_VERSION:/ {print $2; exit}' "${ROOT_DIR}/project.yml")"
if [ -z "${APP_VERSION}" ] || [ -z "${APP_BUILD}" ]; then
    echo "Error: could not read MARKETING_VERSION / CURRENT_PROJECT_VERSION from project.yml"
    exit 1
fi

plutil -replace LSUIElement -bool YES "${APP_PATH}/Contents/Info.plist"
plutil -replace CFBundleIconFile -string AppIcon "${APP_PATH}/Contents/Info.plist"
plutil -replace CFBundleIconName -string AppIcon "${APP_PATH}/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "${APP_VERSION}" "${APP_PATH}/Contents/Info.plist"
plutil -replace CFBundleVersion -string "${APP_BUILD}" "${APP_PATH}/Contents/Info.plist"
plutil -replace SUFeedURL -string "https://barboss.artsvit.com/appcast.xml" "${APP_PATH}/Contents/Info.plist"
plutil -replace SUPublicEDKey -string "qCe12n2kfrYp7PYoMojEtF5I3YWI7QA7vKIh1KbUYzM=" "${APP_PATH}/Contents/Info.plist"
plutil -replace SUEnableAutomaticChecks -bool YES "${APP_PATH}/Contents/Info.plist"

echo "Stamped BarBoss ${APP_VERSION} (build ${APP_BUILD})"
if [ "${APP_VERSION}" = "1.0" ] || [ "${APP_BUILD}" = "1" ]; then
    echo "Error: version was not bumped. Sparkle will still report 1.0 as latest."
    exit 1
fi

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
rm -rf "${BUILD_DIR}/BarBoss.app"
cp -R "${APP_PATH}" "${BUILD_DIR}/BarBoss.app"

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

# 12. Sign the update and write Sparkle appcast
SPARKLE_BIN="$(find "${DERIVED_DATA}/SourcePackages/artifacts/sparkle" -name sign_update -type f | head -1 | xargs dirname)"
if [ -z "${SPARKLE_BIN}" ] || [ ! -x "${SPARKLE_BIN}/sign_update" ]; then
    echo "Error: Sparkle sign_update tool not found in DerivedData"
    exit 1
fi

echo "Signing update for Sparkle (account: BarBoss)..."
SIGN_OUTPUT="$("${SPARKLE_BIN}/sign_update" --account BarBoss "${DMG_OUTPUT}")"
echo "${SIGN_OUTPUT}"
ED_SIGNATURE="$(printf '%s\n' "${SIGN_OUTPUT}" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
DMG_LENGTH="$(stat -f%z "${DMG_OUTPUT}")"
if [ -z "${ED_SIGNATURE}" ]; then
    echo "Error: failed to read sparkle:edSignature from sign_update"
    exit 1
fi

PUBDATE="$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"
APPCAST_PATH="${ROOT_DIR}/landing/appcast.xml"
cat > "${APPCAST_PATH}" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>BarBoss Changelog</title>
    <link>https://barboss.artsvit.com/appcast.xml</link>
    <description>Most recent updates to BarBoss.</description>
    <language>en</language>
    <item>
      <title>BarBoss ${APP_VERSION}</title>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <pubDate>${PUBDATE}</pubDate>
      <description><![CDATA[
        <h2>BarBoss ${APP_VERSION}</h2>
        <p>Sparkle updates now advertise this build, and the DMG installer shows a drag arrow into Applications.</p>
        <ul>
          <li>Sparkle feed now ships the current short version and build number</li>
          <li>Updates are signed with the BarBoss EdDSA key</li>
          <li>DMG window includes a clear arrow from BarBoss to Applications</li>
        </ul>
      ]]></description>
      <enclosure url="https://barboss.artsvit.com/BarBoss.dmg"
                 sparkle:version="${APP_BUILD}"
                 sparkle:shortVersionString="${APP_VERSION}"
                 sparkle:edSignature="${ED_SIGNATURE}"
                 length="${DMG_LENGTH}"
                 type="application/octet-stream" />
    </item>
  </channel>
</rss>
EOF

cp -f "${DMG_OUTPUT}" "${ROOT_DIR}/landing/BarBoss.dmg"
echo "Updated landing/appcast.xml and landing/BarBoss.dmg"

echo "=== Notarized DMG Build Complete! ==="
echo "Artifact: ${DMG_OUTPUT}"
echo "Sparkle: BarBoss ${APP_VERSION} (build ${APP_BUILD}), length ${DMG_LENGTH}"
ls -lh "${DMG_OUTPUT}"
