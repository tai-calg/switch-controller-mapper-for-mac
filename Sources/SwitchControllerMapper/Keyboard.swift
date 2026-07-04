import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Dispatch
import Foundation
import GameController
import IOKit.hid

final class KeyboardEmitter {
    weak var observer: ControllerInputObserver?
    private let eventSource: CGEventSource?
    private var activePressCounts: [CGKeyCode: Int] = [:]
    private var reportedEventCreationFailure = false

    init() {
        eventSource = CGEventSource(stateID: .hidSystemState)
    }

    func pressKey(_ keyCode: CGKeyCode) {
        let activeCount = activePressCounts[keyCode, default: 0]
        activePressCounts[keyCode] = activeCount + 1

        guard activeCount == 0 else {
            return
        }

        observer?.keyboardOutputChanged("Key down CGKeyCode \(keyCode)")
        postKey(keyCode, pressed: true)
    }

    func repeatKey(_ keyCode: CGKeyCode) {
        guard activePressCounts[keyCode, default: 0] > 0 else {
            return
        }

        observer?.keyboardOutputChanged("Key repeat CGKeyCode \(keyCode)")
        postKey(keyCode, pressed: true)
    }

    func releaseKey(_ keyCode: CGKeyCode) {
        let activeCount = activePressCounts[keyCode, default: 0]

        guard activeCount > 0 else {
            return
        }

        if activeCount == 1 {
            activePressCounts[keyCode] = nil
            observer?.keyboardOutputChanged("Key up CGKeyCode \(keyCode)")
            postKey(keyCode, pressed: false)
        } else {
            activePressCounts[keyCode] = activeCount - 1
        }
    }

    func releaseAllKeys() {
        let pressedKeys = Array(activePressCounts.keys)
        activePressCounts.removeAll()

        for keyCode in pressedKeys {
            postKey(keyCode, pressed: false)
        }
    }

    func canCreateEvent(for keyCode: CGKeyCode) -> Bool {
        CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true) != nil
    }

    private func postKey(_ keyCode: CGKeyCode, pressed: Bool) {
        guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: pressed) else {
            if !reportedEventCreationFailure {
                fputs("Failed to create CGEvent keyboard event; key injection is not working.\n", stderr)
                reportedEventCreationFailure = true
            }
            return
        }

        event.post(tap: .cgSessionEventTap)
    }
}

final class ButtonBinding {
    private struct RepeatSettings {
        let initialDelay: TimeInterval
        let interval: TimeInterval
    }

    private static let fastRepeat = RepeatSettings(initialDelay: 0.08, interval: 0.08)
    private static let faceButtonRepeat = RepeatSettings(initialDelay: 0.45, interval: 0.22)

    private let keyCode: CGKeyCode
    private let keyboard: KeyboardEmitter
    private let repeatSettings: RepeatSettings?
    private var isPressed = false
    private var repeatTimer: Timer?

    private init(keyCode: CGKeyCode, keyboard: KeyboardEmitter, repeatSettings: RepeatSettings?) {
        self.keyCode = keyCode
        self.keyboard = keyboard
        self.repeatSettings = repeatSettings
    }

    static func fastRepeating(keyCode: CGKeyCode, keyboard: KeyboardEmitter) -> ButtonBinding {
        ButtonBinding(keyCode: keyCode, keyboard: keyboard, repeatSettings: fastRepeat)
    }

    static func faceButtonRepeating(keyCode: CGKeyCode, keyboard: KeyboardEmitter) -> ButtonBinding {
        ButtonBinding(keyCode: keyCode, keyboard: keyboard, repeatSettings: faceButtonRepeat)
    }

    static func nonRepeating(keyCode: CGKeyCode, keyboard: KeyboardEmitter) -> ButtonBinding {
        ButtonBinding(keyCode: keyCode, keyboard: keyboard, repeatSettings: nil)
    }

    func update(pressed: Bool) {
        guard pressed != isPressed else {
            return
        }

        isPressed = pressed

        if pressed {
            keyboard.pressKey(keyCode)
            startRepeatingIfNeeded()
        } else {
            stopRepeating()
            keyboard.releaseKey(keyCode)
        }
    }

    func release() {
        guard isPressed else {
            stopRepeating()
            return
        }

        isPressed = false
        stopRepeating()
        keyboard.releaseKey(keyCode)
    }

    private func startRepeatingIfNeeded() {
        guard let repeatSettings, repeatTimer == nil else {
            return
        }

        repeatTimer = Timer.scheduledTimer(withTimeInterval: repeatSettings.initialDelay, repeats: false) { [weak self] _ in
            guard let self, self.isPressed else {
                return
            }

            self.keyboard.repeatKey(self.keyCode)
            self.repeatTimer = Timer.scheduledTimer(withTimeInterval: repeatSettings.interval, repeats: true) { [weak self] _ in
                guard let self, self.isPressed else {
                    return
                }

                self.keyboard.repeatKey(self.keyCode)
            }
        }
    }

    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}
