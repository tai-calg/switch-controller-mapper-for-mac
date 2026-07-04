import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Dispatch
import Foundation
import GameController
import IOKit.hid

enum KeyCode {
    static let escape: CGKeyCode = 53
    static let returnKey: CGKeyCode = 36
    static let tab: CGKeyCode = 48
    static let space: CGKeyCode = 49
    static let delete: CGKeyCode = 51
    static let leftArrow: CGKeyCode = 123
    static let rightArrow: CGKeyCode = 124
    static let downArrow: CGKeyCode = 125
    static let upArrow: CGKeyCode = 126
}

enum MacKeyChoice: String, CaseIterable {
    case disabled
    case upArrow
    case downArrow
    case leftArrow
    case rightArrow
    case `return`
    case escape
    case tab
    case space
    case delete

    var displayName: String {
        switch self {
        case .disabled: "Disabled"
        case .upArrow: "↑ Up Arrow"
        case .downArrow: "↓ Down Arrow"
        case .leftArrow: "← Left Arrow"
        case .rightArrow: "→ Right Arrow"
        case .return: "Return / Enter"
        case .escape: "Escape"
        case .tab: "Tab"
        case .space: "Space"
        case .delete: "Delete / Backspace"
        }
    }

    var keyCode: CGKeyCode? {
        switch self {
        case .disabled: nil
        case .upArrow: KeyCode.upArrow
        case .downArrow: KeyCode.downArrow
        case .leftArrow: KeyCode.leftArrow
        case .rightArrow: KeyCode.rightArrow
        case .return: KeyCode.returnKey
        case .escape: KeyCode.escape
        case .tab: KeyCode.tab
        case .space: KeyCode.space
        case .delete: KeyCode.delete
        }
    }
}

enum RepeatMode {
    case none
    case fast
    case faceButton
}

struct ControllerInputSpec {
    let id: String
    let displayName: String
    let defaultKey: MacKeyChoice
    let repeatMode: RepeatMode
    let isAdvanced: Bool
}

protocol ControllerInputObserver: AnyObject {
    func controllerStatusChanged(_ status: String)
    func controllerInputChanged(_ input: String, pressed: Bool)
    func keyboardOutputChanged(_ message: String)
}

enum ControllerInputID {
    static let dpadUp = "dpad.up"
    static let dpadDown = "dpad.down"
    static let dpadLeft = "dpad.left"
    static let dpadRight = "dpad.right"
    static let stickUp = "stick.up"
    static let stickDown = "stick.down"
    static let stickLeft = "stick.left"
    static let stickRight = "stick.right"
    static let faceA = "face.a"
    static let faceB = "face.b"
    static let faceY = "face.y"
    static let faceX = "face.x"
    static let shoulderR = "shoulder.r"
    static let triggerZR = "trigger.zr"
    static let shoulderL = "shoulder.l"
    static let triggerZL = "trigger.zl"
    static let plus = "button.plus"
    static let minus = "button.minus"
    static let home = "button.home"
    static let capture = "button.capture"
    static let sl = "button.sl"
    static let sr = "button.sr"
    static let leftStickPress = "stick.left.press"
    static let rightStickPress = "stick.right.press"
}

let configurableInputSpecs: [ControllerInputSpec] = [
    ControllerInputSpec(id: ControllerInputID.dpadUp, displayName: "D-pad Up", defaultKey: .upArrow, repeatMode: .fast, isAdvanced: false),
    ControllerInputSpec(id: ControllerInputID.dpadDown, displayName: "D-pad Down", defaultKey: .downArrow, repeatMode: .fast, isAdvanced: false),
    ControllerInputSpec(id: ControllerInputID.dpadLeft, displayName: "D-pad Left", defaultKey: .leftArrow, repeatMode: .fast, isAdvanced: false),
    ControllerInputSpec(id: ControllerInputID.dpadRight, displayName: "D-pad Right", defaultKey: .rightArrow, repeatMode: .fast, isAdvanced: false),
    ControllerInputSpec(id: ControllerInputID.stickUp, displayName: "Stick Up", defaultKey: .upArrow, repeatMode: .fast, isAdvanced: false),
    ControllerInputSpec(id: ControllerInputID.stickDown, displayName: "Stick Down", defaultKey: .downArrow, repeatMode: .fast, isAdvanced: false),
    ControllerInputSpec(id: ControllerInputID.stickLeft, displayName: "Stick Left", defaultKey: .leftArrow, repeatMode: .fast, isAdvanced: false),
    ControllerInputSpec(id: ControllerInputID.stickRight, displayName: "Stick Right", defaultKey: .rightArrow, repeatMode: .fast, isAdvanced: false),
    ControllerInputSpec(id: ControllerInputID.faceA, displayName: "A / right face button", defaultKey: .rightArrow, repeatMode: .faceButton, isAdvanced: false),
    ControllerInputSpec(id: ControllerInputID.faceB, displayName: "B / bottom face button", defaultKey: .downArrow, repeatMode: .faceButton, isAdvanced: false),
    ControllerInputSpec(id: ControllerInputID.faceY, displayName: "Y / left face button", defaultKey: .leftArrow, repeatMode: .faceButton, isAdvanced: false),
    ControllerInputSpec(id: ControllerInputID.faceX, displayName: "X / top face button", defaultKey: .upArrow, repeatMode: .faceButton, isAdvanced: false),
    ControllerInputSpec(id: ControllerInputID.shoulderR, displayName: "R", defaultKey: .return, repeatMode: .none, isAdvanced: false),
    ControllerInputSpec(id: ControllerInputID.triggerZR, displayName: "ZR", defaultKey: .return, repeatMode: .none, isAdvanced: false),
    ControllerInputSpec(id: ControllerInputID.shoulderL, displayName: "L", defaultKey: .return, repeatMode: .none, isAdvanced: false),
    ControllerInputSpec(id: ControllerInputID.triggerZL, displayName: "ZL", defaultKey: .return, repeatMode: .none, isAdvanced: false),
    ControllerInputSpec(id: ControllerInputID.plus, displayName: "+ / menu", defaultKey: .escape, repeatMode: .none, isAdvanced: false),
    ControllerInputSpec(id: ControllerInputID.minus, displayName: "- / minus", defaultKey: .disabled, repeatMode: .none, isAdvanced: true),
    ControllerInputSpec(id: ControllerInputID.home, displayName: "Home", defaultKey: .disabled, repeatMode: .none, isAdvanced: true),
    ControllerInputSpec(id: ControllerInputID.capture, displayName: "Capture", defaultKey: .disabled, repeatMode: .none, isAdvanced: true),
    ControllerInputSpec(id: ControllerInputID.sl, displayName: "SL", defaultKey: .disabled, repeatMode: .none, isAdvanced: true),
    ControllerInputSpec(id: ControllerInputID.sr, displayName: "SR", defaultKey: .disabled, repeatMode: .none, isAdvanced: true),
    ControllerInputSpec(id: ControllerInputID.leftStickPress, displayName: "Left stick press", defaultKey: .disabled, repeatMode: .none, isAdvanced: true),
    ControllerInputSpec(id: ControllerInputID.rightStickPress, displayName: "Right stick press", defaultKey: .disabled, repeatMode: .none, isAdvanced: true)
]

final class MappingStore {
    private let defaultsKey = "SwitchControllerMapper.Mappings.v1"
    private let defaults: UserDefaults
    private var choicesByInputID: [String: MacKeyChoice] = [:]

    init(defaults: UserDefaults = UserDefaults(suiteName: "local.switch-controller-mapper") ?? .standard) {
        self.defaults = defaults
        load()
    }

    func keyChoice(for inputID: String) -> MacKeyChoice {
        if let choice = choicesByInputID[inputID] {
            return choice
        }

        return configurableInputSpecs.first { $0.id == inputID }?.defaultKey ?? .disabled
    }

    func keyCode(for inputID: String) -> CGKeyCode? {
        keyChoice(for: inputID).keyCode
    }

    func set(_ choice: MacKeyChoice, for inputID: String) {
        choicesByInputID[inputID] = choice
    }

    func resetToDefaults() {
        choicesByInputID = Dictionary(uniqueKeysWithValues: configurableInputSpecs.map { ($0.id, $0.defaultKey) })
        save()
    }

    func save() {
        let rawValues = choicesByInputID.mapValues { $0.rawValue }
        defaults.set(rawValues, forKey: defaultsKey)
    }

    private func load() {
        let saved = loadSavedMappings()
        choicesByInputID = Dictionary(uniqueKeysWithValues: configurableInputSpecs.map { spec in
            let savedChoice = saved[spec.id].flatMap(MacKeyChoice.init(rawValue:))
            return (spec.id, savedChoice ?? spec.defaultKey)
        })
    }

    private func loadSavedMappings() -> [String: String] {
        if let saved = defaults.dictionary(forKey: defaultsKey) as? [String: String], !saved.isEmpty {
            return saved
        }

        if let standardSaved = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String], !standardSaved.isEmpty {
            defaults.set(standardSaved, forKey: defaultsKey)
            return standardSaved
        }

        if let legacySaved = CFPreferencesCopyAppValue(defaultsKey as CFString, "switch-controller-mapper" as CFString) as? [String: String], !legacySaved.isEmpty {
            defaults.set(legacySaved, forKey: defaultsKey)
            return legacySaved
        }

        return [:]
    }
}
