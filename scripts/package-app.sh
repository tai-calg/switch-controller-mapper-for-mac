#!/bin/sh
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
    printf 'Packaging must be run on macOS.\n' >&2
    exit 1
fi

APP_NAME="SwitchControllerMapper.app"
DIST_DIR="dist"
ZIP_PATH="$DIST_DIR/SwitchControllerMapper.zip"

sh scripts/clean-build.sh
sh scripts/build-app.sh

mkdir -p "$DIST_DIR"
ditto -c -k --keepParent ".build/$APP_NAME" "$ZIP_PATH"

printf 'Packaged %s\n' "$ZIP_PATH"
codesign --verify --deep --strict ".build/$APP_NAME"
printf 'Code signature verified for .build/%s\n' "$APP_NAME"
