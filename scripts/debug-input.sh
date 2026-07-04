#!/bin/sh
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
    printf 'This debug script must be run on macOS.\n' >&2
    exit 1
fi

command -v swift >/dev/null 2>&1 || {
    printf 'swift was not found. Install Xcode or the Swift toolchain.\n' >&2
    exit 1
}

swift run switch-controller-mapper --debug-input
