#!/bin/bash
set -euo pipefail

# Builds ShopVaultMac as a proper .app bundle.
# This is necessary because `swift run` executables don't have a bundle
# identifier, which causes file pickers (NSOpenPanel) and other ViewBridge
# services to crash. A proper .app bundle fixes that.

cd "$(dirname "$0")"

APP_NAME="ShopVault Viewer"
BUNDLE_ID="com.shopvault.viewer"
EXECUTABLE_NAME="ShopVaultMac"
BUILD_CONFIG="release"
APP_PATH="./build/${APP_NAME}.app"

echo "→ Building executable (release)…"
swift build -c "${BUILD_CONFIG}" >/dev/null

EXECUTABLE_PATH=$(swift build -c "${BUILD_CONFIG}" --show-bin-path)/${EXECUTABLE_NAME}

if [ ! -f "${EXECUTABLE_PATH}" ]; then
    echo "✗ Executable not found: ${EXECUTABLE_PATH}"
    exit 1
fi

# Build icon if source SVG present and .icns missing or older than SVG
ICON_SVG="./icon.svg"
ICON_ICNS="./build/AppIcon.icns"
if [ -f "${ICON_SVG}" ]; then
    if [ ! -f "${ICON_ICNS}" ] || [ "${ICON_SVG}" -nt "${ICON_ICNS}" ]; then
        echo "→ Generating app icon…"
        ./make-icon.sh >/dev/null
    fi
fi

echo "→ Creating bundle structure…"
rm -rf "${APP_PATH}"
mkdir -p "${APP_PATH}/Contents/MacOS"
mkdir -p "${APP_PATH}/Contents/Resources"

echo "→ Copying executable…"
cp "${EXECUTABLE_PATH}" "${APP_PATH}/Contents/MacOS/${EXECUTABLE_NAME}"
chmod +x "${APP_PATH}/Contents/MacOS/${EXECUTABLE_NAME}"

if [ -f "${ICON_ICNS}" ]; then
    echo "→ Installing icon…"
    cp "${ICON_ICNS}" "${APP_PATH}/Contents/Resources/AppIcon.icns"
fi

echo "→ Writing Info.plist…"
cat > "${APP_PATH}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.business</string>
    <key>NSHumanReadableCopyright</key>
    <string>Privates Tool. Liest .shopvault Snapshots lokal.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>ShopVault Encrypted Export</string>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>shopvault</string>
            </array>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Owner</string>
        </dict>
    </array>
</dict>
</plist>
EOF

echo "→ Ad-hoc signing…"
codesign --force --deep --sign - "${APP_PATH}" 2>/dev/null || true

echo ""
echo "✓ Bundle built: ${APP_PATH}"
echo ""
echo "Run with:"
echo "  open '${APP_PATH}'"
echo ""
echo "Move to /Applications:"
echo "  cp -R '${APP_PATH}' /Applications/"
