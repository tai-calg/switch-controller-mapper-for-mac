import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Dispatch
import Foundation
import GameController
import IOKit.hid

struct MappingSummary {
    let controllerInput: String
    let macKey: String
    let keyCode: CGKeyCode
}

let extendedMappings = [
    MappingSummary(controllerInput: "D-pad Up", macKey: "Up Arrow", keyCode: KeyCode.upArrow),
    MappingSummary(controllerInput: "D-pad Down", macKey: "Down Arrow", keyCode: KeyCode.downArrow),
    MappingSummary(controllerInput: "D-pad Left", macKey: "Left Arrow", keyCode: KeyCode.leftArrow),
    MappingSummary(controllerInput: "D-pad Right", macKey: "Right Arrow", keyCode: KeyCode.rightArrow),
    MappingSummary(controllerInput: "Left thumbstick Up", macKey: "Up Arrow", keyCode: KeyCode.upArrow),
    MappingSummary(controllerInput: "Left thumbstick Down", macKey: "Down Arrow", keyCode: KeyCode.downArrow),
    MappingSummary(controllerInput: "Left thumbstick Left", macKey: "Left Arrow", keyCode: KeyCode.leftArrow),
    MappingSummary(controllerInput: "Left thumbstick Right", macKey: "Right Arrow", keyCode: KeyCode.rightArrow),
    MappingSummary(controllerInput: "Right thumbstick Up", macKey: "Up Arrow", keyCode: KeyCode.upArrow),
    MappingSummary(controllerInput: "Right thumbstick Down", macKey: "Down Arrow", keyCode: KeyCode.downArrow),
    MappingSummary(controllerInput: "Right thumbstick Left", macKey: "Left Arrow", keyCode: KeyCode.leftArrow),
    MappingSummary(controllerInput: "Right thumbstick Right", macKey: "Right Arrow", keyCode: KeyCode.rightArrow),
    MappingSummary(controllerInput: "Nintendo A / right face button", macKey: "Right Arrow", keyCode: KeyCode.rightArrow),
    MappingSummary(controllerInput: "Nintendo B / bottom face button", macKey: "Down Arrow", keyCode: KeyCode.downArrow),
    MappingSummary(controllerInput: "Nintendo Y / left face button", macKey: "Left Arrow", keyCode: KeyCode.leftArrow),
    MappingSummary(controllerInput: "Nintendo X / top face button", macKey: "Up Arrow", keyCode: KeyCode.upArrow),
    MappingSummary(controllerInput: "R / right shoulder", macKey: "Return", keyCode: KeyCode.returnKey),
    MappingSummary(controllerInput: "ZR / right trigger", macKey: "Return", keyCode: KeyCode.returnKey),
    MappingSummary(controllerInput: "L / left shoulder", macKey: "Return", keyCode: KeyCode.returnKey),
    MappingSummary(controllerInput: "ZL / left trigger", macKey: "Return", keyCode: KeyCode.returnKey),
    MappingSummary(controllerInput: "+ / menu button", macKey: "Escape", keyCode: KeyCode.escape)
]

let microMappings = [
    MappingSummary(controllerInput: "Vertical stick Up / micro D-pad Right", macKey: "Up Arrow", keyCode: KeyCode.upArrow),
    MappingSummary(controllerInput: "Vertical stick Down / micro D-pad Left", macKey: "Down Arrow", keyCode: KeyCode.downArrow),
    MappingSummary(controllerInput: "Vertical stick Left / micro D-pad Up", macKey: "Left Arrow", keyCode: KeyCode.leftArrow),
    MappingSummary(controllerInput: "Vertical stick Right / micro D-pad Down", macKey: "Right Arrow", keyCode: KeyCode.rightArrow),
    MappingSummary(controllerInput: "Nintendo A / micro Button X", macKey: "Right Arrow", keyCode: KeyCode.rightArrow),
    MappingSummary(controllerInput: "Nintendo B / physical Button B", macKey: "Down Arrow", keyCode: KeyCode.downArrow),
    MappingSummary(controllerInput: "Nintendo Y / physical Button Y", macKey: "Left Arrow", keyCode: KeyCode.leftArrow),
    MappingSummary(controllerInput: "Nintendo X / physical Button X", macKey: "Up Arrow", keyCode: KeyCode.upArrow),
    MappingSummary(controllerInput: "Physical Left/Right Shoulder or Trigger", macKey: "Return", keyCode: KeyCode.returnKey),
    MappingSummary(controllerInput: "+ / menu button", macKey: "Escape", keyCode: KeyCode.escape)
]

func isAccessibilityTrusted(prompt: Bool) -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}

func runSelfTest() {
    let keyboard = KeyboardEmitter()

    print("Switch Controller Mapper self-test")
    print("Accessibility trusted: \(isAccessibilityTrusted(prompt: false) ? "yes" : "no")")
    print("Extended gamepad mappings:")

    for mapping in extendedMappings {
        let eventStatus = keyboard.canCreateEvent(for: mapping.keyCode) ? "event ok" : "event failed"
        print("- \(mapping.controllerInput) -> \(mapping.macKey) (CGKeyCode \(mapping.keyCode), \(eventStatus))")
    }

    print("Micro gamepad fallback mappings:")

    for mapping in microMappings {
        let eventStatus = keyboard.canCreateEvent(for: mapping.keyCode) ? "event ok" : "event failed"
        print("- \(mapping.controllerInput) -> \(mapping.macKey) (CGKeyCode \(mapping.keyCode), \(eventStatus))")
    }
}
