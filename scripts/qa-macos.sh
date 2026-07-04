#!/bin/sh
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
    printf 'This QA script must be run on macOS.\n' >&2
    exit 1
fi

command -v swift >/dev/null 2>&1 || {
    printf 'swift was not found. Install Xcode or the Swift toolchain.\n' >&2
    exit 1
}

test -f scripts/run-app.sh || {
    printf 'scripts/run-app.sh is missing.\n' >&2
    exit 1
}

test -f scripts/package-app.sh || {
    printf 'scripts/package-app.sh is missing.\n' >&2
    exit 1
}

swift build
swift run switch-controller-mapper --self-test
sh scripts/build-app.sh

cat <<'CHECKLIST'

Manual controller QA checklist:
1. Connect the Switch controller before launch, then run: swift run switch-controller-mapper
2. Verify D-pad Up/Down/Left/Right sends the matching Mac arrow keys.
3. Verify stick Up/Down/Left/Right sends the matching Mac arrow keys in vertical holding orientation.
4. Verify vertical face buttons send arrows: A/right -> Right, B/bottom -> Down, Y/left -> Left, X/top -> Up.
5. Verify R/ZR sends Return. The mapper also reads raw HID report 0x3F byte 2 bits 0x40/0x80 for Joy-Con R/ZR when GameController does not expose those buttons.
6. Verify + sends Escape.
7. Verify holding a D-pad or stick direction repeats quickly, while A/B/X/Y moves once on a short press and repeats only after a longer hold.
8. Put another app in front and verify controller input still controls that frontmost app.
9. While holding an arrow input, disconnect the controller and verify the key is released.
10. While holding an arrow input, press Ctrl-C and verify the key is released.
11. Launch the recommended desktop app flow with: sh scripts/run-app.sh
12. Verify a desktop window appears and shows the mapper is running, an original Joy-Con schematic, configurable mapping dropdowns, Accessibility status, Apply & Save, Reset Defaults, and Quit Mapper.
13. Change one mapping, click Apply & Save, verify the new key mapping applies, then use Reset Defaults to restore the default mapping.
14. Verify the menu bar gamepad icon also appears, then quit from either the window Quit Mapper button or the menu bar Quit item while holding an arrow input and verify the key is released.
15. Grant Accessibility permission to Terminal/iTerm/VS Code for sh scripts/run-app.sh or swift run. Only grant SwitchControllerMapper.app if testing the optional .app bundle path.
16. If any physical button is wrong, run: sh scripts/debug-input.sh, then press A/B/X/Y/+, stick directions, and R/ZR/L/ZL and record the printed input names.
17. If R/ZR or + prints nothing in debug-input, run: sh scripts/debug-hid.sh, press/release the missing button one at a time, and record the nearby bytes= and indexed= report lines.
18. For release packaging, run: sh scripts/package-app.sh, then verify dist/SwitchControllerMapper.zip exists.
CHECKLIST
