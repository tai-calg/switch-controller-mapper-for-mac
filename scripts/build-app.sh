#!/bin/sh
set -eu

APP_VERSION="${APP_VERSION:-1.0.0}"
BUILD_VERSION="${BUILD_VERSION:-$(date +%Y%m%d%H%M%S)}"

swift build -c release

APP_DIR=".build/SwitchControllerMapper.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_SOURCE="logo_swi_controler.png"
ICONSET_DIR=".build/SwitchControllerMapper.iconset"
ICON_FILE="SwitchControllerMapper.icns"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp ".build/release/switch-controller-mapper" "$MACOS_DIR/SwitchControllerMapper"

if [ -f "$ICON_SOURCE" ] && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"
    sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
    sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
    sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
    sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
    sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
    sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
    sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
    sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
    sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/$ICON_FILE"
else
    printf 'Warning: %s missing, or sips/iconutil unavailable; app icon will not be generated.\n' "$ICON_SOURCE" >&2
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SwitchControllerMapper</string>
    <key>CFBundleIdentifier</key>
    <string>local.switch-controller-mapper</string>
    <key>CFBundleDisplayName</key>
    <string>Switch Controller Mapper</string>
    <key>CFBundleName</key>
    <string>Switch Controller Mapper</string>
    <key>CFBundleIconFile</key>
    <string>SwitchControllerMapper</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_VERSION</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

touch "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || {
    printf 'Warning: ad-hoc codesign failed. Accessibility may treat rebuilt app bundles inconsistently.\n' >&2
}
printf 'Built %s (version %s)\n' "$APP_DIR" "$BUILD_VERSION"
