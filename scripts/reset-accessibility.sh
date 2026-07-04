#!/bin/sh
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
    printf 'Accessibility reset must be run on macOS.\n' >&2
    exit 1
fi

pkill -f 'switch-controller-mapper|SwitchControllerMapper' 2>/dev/null || true

printf 'Resetting Accessibility permission for bundle id local.switch-controller-mapper...\n'
tccutil reset Accessibility local.switch-controller-mapper 2>/dev/null || true

printf 'If SwitchControllerMapper still appears in Accessibility, remove it manually, then add the app again.\n'
open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'
