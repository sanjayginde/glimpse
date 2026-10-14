#!/bin/bash
set -euo pipefail

TARGET_NAME="Glimpse"
APP_NAME="Glimpse"
BUNDLE_ID="dev.sanjayginde.glimpse"
VERSION="${VERSION:-1.0}"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
PLIST_FILE="${CONTENTS_DIR}/Info.plist"

SKIP_CLEAN=false
NOTARIZE=false
INSTALL_DIR=""

usage() {
  cat <<USAGE
Usage: $0 [options]

  --skip-clean     Incremental build (skip rm -rf .build)
  --notarize       Notarize and staple the app bundle
  --install        Install to /Applications (required for SMAppService login item)
  --install-user   Install to ~/Applications
  -h, --help       Show this help

Environment:
  SIGN_IDENTITY    codesign identity (default "-" = ad-hoc)
  NOTARY_PROFILE   notarytool keychain profile (default "glimpse-notary")
  NOTARY_KEY_PATH, NOTARY_KEY_ID, NOTARY_ISSUER
                   App Store Connect API key; used instead of NOTARY_PROFILE when set
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-clean)   SKIP_CLEAN=true ;;
    --notarize)     NOTARIZE=true ;;
    --install)      INSTALL_DIR="/Applications" ;;
    --install-user) INSTALL_DIR="${HOME}/Applications" ;;
    -h|--help)      usage; exit 0 ;;
    *)              echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

if [ "${SKIP_CLEAN}" = true ]; then
  echo "Skipping clean (incremental build)..."
else
  echo "Cleaning previous build..."
  rm -rf .build "${APP_DIR}" icon.iconset
fi

echo "Building the app..."
swift build -c release
BUILD_DIR="$(swift build -c release --show-bin-path)"

echo "Creating .app bundle structure..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "Copying executable into .app bundle..."
cp "${BUILD_DIR}/${TARGET_NAME}" "${MACOS_DIR}/${TARGET_NAME}"

if [ -f "Resources/icon.png" ]; then
  echo "Generating iconset..."
  mkdir -p icon.iconset
  sips -z 16 16     Resources/icon.png --out icon.iconset/icon_16x16.png
  sips -z 32 32     Resources/icon.png --out icon.iconset/icon_16x16@2x.png
  sips -z 32 32     Resources/icon.png --out icon.iconset/icon_32x32.png
  sips -z 64 64     Resources/icon.png --out icon.iconset/icon_32x32@2x.png
  sips -z 128 128   Resources/icon.png --out icon.iconset/icon_128x128.png
  sips -z 256 256   Resources/icon.png --out icon.iconset/icon_128x128@2x.png
  sips -z 256 256   Resources/icon.png --out icon.iconset/icon_256x256.png
  sips -z 512 512   Resources/icon.png --out icon.iconset/icon_256x256@2x.png
  sips -z 512 512   Resources/icon.png --out icon.iconset/icon_512x512.png
  sips -z 1024 1024 Resources/icon.png --out icon.iconset/icon_512x512@2x.png
  iconutil -c icns icon.iconset -o "${RESOURCES_DIR}/icon.icns"
  rm -rf icon.iconset
fi

if [ -d "Resources" ]; then
  echo "Copying resources into .app bundle..."
  cp -r Resources/. "${RESOURCES_DIR}/"
fi

echo "Creating Info.plist..."
cat > "${PLIST_FILE}" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${TARGET_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>icon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
EOL

echo "Setting executable permissions..."
chmod +x "${MACOS_DIR}/${TARGET_NAME}"

# "-" = ad-hoc (local dev); set to a "Developer ID Application: ..." identity for distribution
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

if [ "${NOTARIZE}" = true ] && [ "${SIGN_IDENTITY}" = "-" ]; then
  echo "--notarize requires SIGN_IDENTITY to be a Developer ID Application identity" >&2
  exit 1
fi

echo "Signing the app (${SIGN_IDENTITY})..."
if [ "${SIGN_IDENTITY}" = "-" ]; then
  codesign --force --sign - "${APP_DIR}"
else
  # Hardened runtime + secure timestamp are required for notarization
  codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" "${APP_DIR}"
fi
codesign --verify --strict --verbose=2 "${APP_DIR}"

if [ "${NOTARIZE}" = true ]; then
    echo "Notarizing the app..."
    # CI authenticates with an App Store Connect API key; locally, a stored keychain profile
    if [ -n "${NOTARY_KEY_PATH:-}" ]; then
      NOTARY_AUTH=(--key "${NOTARY_KEY_PATH}" --key-id "${NOTARY_KEY_ID}" --issuer "${NOTARY_ISSUER}")
    else
      NOTARY_AUTH=(--keychain-profile "${NOTARY_PROFILE:-glimpse-notary}")
    fi
    ditto -c -k --keepParent "${APP_DIR}" "${APP_NAME}-notarize.zip"
    xcrun notarytool submit "${APP_NAME}-notarize.zip" "${NOTARY_AUTH[@]}" --wait
    rm -f "${APP_NAME}-notarize.zip"
    xcrun stapler staple "${APP_DIR}"
    spctl --assess --type execute --verbose=4 "${APP_DIR}"
fi

if [ -n "${INSTALL_DIR}" ]; then
    echo "Installing to ${INSTALL_DIR}..."
    mkdir -p "${INSTALL_DIR}"
    if pgrep -x "${TARGET_NAME}" >/dev/null; then
      echo "Quitting running ${APP_NAME}..."
      osascript -e "tell application \"${APP_NAME}\" to quit" 2>/dev/null || killall "${TARGET_NAME}" 2>/dev/null || true
    fi
    rm -rf "${INSTALL_DIR}/${APP_DIR}"
    cp -R "${APP_DIR}" "${INSTALL_DIR}/"
    echo "Installed to ${INSTALL_DIR}/${APP_DIR}"
fi

echo "Build complete: ${APP_DIR}"
