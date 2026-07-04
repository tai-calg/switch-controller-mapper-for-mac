#!/bin/sh
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
    printf 'This app runner must be run on macOS.\n' >&2
    exit 1
fi

command -v swift >/dev/null 2>&1 || {
    printf 'swift was not found. Install Xcode or the Swift toolchain.\n' >&2
    exit 1
}

pkill -f 'switch-controller-mapper|SwitchControllerMapper' 2>/dev/null || true

swift build -c release

EXECUTABLE_PATH="$(pwd)/.build/release/switch-controller-mapper"
printf 'Opening reliable executable path:\n%s\n' "$EXECUTABLE_PATH"
printf 'For Accessibility, allow the terminal app that launched this script if prompted.\n'
"$EXECUTABLE_PATH" &
