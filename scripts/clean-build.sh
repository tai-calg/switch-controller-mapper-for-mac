#!/bin/sh
set -eu

pkill -f 'switch-controller-mapper|SwitchControllerMapper' 2>/dev/null || true

rm -rf .build
rm -rf dist

printf 'Cleaned build products: .build, dist\n'
printf 'Note: UserDefaults mappings and macOS Accessibility permissions are not removed.\n'
