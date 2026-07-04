#!/bin/sh
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
    printf 'This installer must be run on macOS.\n' >&2
    exit 1
fi

APP_NAME="SwitchControllerMapper.app"
SOURCE_APP="$(pwd)/.build/$APP_NAME"
TARGET_DIR="$HOME/Applications"
TARGET_APP="$TARGET_DIR/$APP_NAME"

sh scripts/build-app.sh

pkill -f 'switch-controller-mapper|SwitchControllerMapper' 2>/dev/null || true
mkdir -p "$TARGET_DIR"
rm -rf "$TARGET_APP"
cp -R "$SOURCE_APP" "$TARGET_APP"
codesign --force --deep --sign - "$TARGET_APP" >/dev/null 2>&1 || true

printf 'Installed %s\n' "$TARGET_APP"
printf 'Open Accessibility settings, remove old SwitchControllerMapper entries, then add this exact app if needed:\n%s\n' "$TARGET_APP"
open -n "$TARGET_APP"
