import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Dispatch
import Foundation
import GameController
import IOKit.hid

final class SwitchControllerMapper {
    private let mappingStore: MappingStore
    private let keyboard = KeyboardEmitter()
    weak var observer: ControllerInputObserver? {
        didSet {
            keyboard.observer = observer
        }
    }
    private lazy var rawHIDReturnMapper = RawHIDReturnMapper(keyboard: keyboard, mappingStore: mappingStore)
    private var bindingsByController: [ObjectIdentifier: [ButtonBinding]] = [:]

    init(mappingStore: MappingStore) {
        self.mappingStore = mappingStore
    }

    func start() {
        GCController.shouldMonitorBackgroundEvents = true
        rawHIDReturnMapper.start()

        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else {
                return
            }

            self?.configure(controller)
        }

        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else {
                return
            }

            self?.releaseBindings(for: controller)
        }

        GCController.controllers().forEach(configure)
        GCController.startWirelessControllerDiscovery()

        print("Switch controller mapper is running.")
        print("Mappings: configurable in the desktop window. Defaults: arrows, Return, Escape.")
        print("Background controller input: enabled.")
        if isAccessibilityTrusted(prompt: true) {
            print("Accessibility permission: granted.")
        } else {
            print("Accessibility permission: not granted yet. Enable this app in System Settings -> Privacy & Security -> Accessibility.")
        }
    }

    private func configure(_ controller: GCController) {
        if let gamepad = controller.extendedGamepad {
            configureExtended(gamepad, controller: controller)
        } else if let gamepad = controller.microGamepad {
            configureMicro(gamepad, controller: controller)
        } else {
            print("Connected controller has no supported gamepad profile: \(controller.vendorName ?? "Unknown")")
        }
    }

    private func configureExtended(_ gamepad: GCExtendedGamepad, controller: GCController) {
        print("Configured controller: \(controller.vendorName ?? "Unknown")")
        observer?.controllerStatusChanged("Connected: \(controller.vendorName ?? "Unknown") / extended")
        releaseBindings(for: controller)

        bindingsByController[ObjectIdentifier(controller)] = [
            configuredBinding(gamepad.dpad.up, inputID: ControllerInputID.dpadUp),
            configuredBinding(gamepad.dpad.down, inputID: ControllerInputID.dpadDown),
            configuredBinding(gamepad.dpad.left, inputID: ControllerInputID.dpadLeft),
            configuredBinding(gamepad.dpad.right, inputID: ControllerInputID.dpadRight),
            configuredBinding(gamepad.leftThumbstick.up, inputID: ControllerInputID.stickUp),
            configuredBinding(gamepad.leftThumbstick.down, inputID: ControllerInputID.stickDown),
            configuredBinding(gamepad.leftThumbstick.left, inputID: ControllerInputID.stickLeft),
            configuredBinding(gamepad.leftThumbstick.right, inputID: ControllerInputID.stickRight),
            configuredBinding(gamepad.rightThumbstick.up, inputID: ControllerInputID.stickUp),
            configuredBinding(gamepad.rightThumbstick.down, inputID: ControllerInputID.stickDown),
            configuredBinding(gamepad.rightThumbstick.left, inputID: ControllerInputID.stickLeft),
            configuredBinding(gamepad.rightThumbstick.right, inputID: ControllerInputID.stickRight),
            configuredBinding(gamepad.buttonA, inputID: ControllerInputID.faceA),
            configuredBinding(gamepad.buttonB, inputID: ControllerInputID.faceB),
            configuredBinding(gamepad.buttonY, inputID: ControllerInputID.faceY),
            configuredBinding(gamepad.buttonX, inputID: ControllerInputID.faceX),
            configuredBinding(gamepad.rightShoulder, inputID: ControllerInputID.shoulderR),
            configuredBinding(gamepad.rightTrigger, inputID: ControllerInputID.triggerZR),
            configuredBinding(gamepad.leftShoulder, inputID: ControllerInputID.shoulderL),
            configuredBinding(gamepad.leftTrigger, inputID: ControllerInputID.triggerZL)
        ].compactMap { $0 }
    }

    private func configureMicro(_ gamepad: GCMicroGamepad, controller: GCController) {
        print("Configured vertical Joy-Con micro controller: \(controller.vendorName ?? "Unknown")")
        observer?.controllerStatusChanged("Connected: \(controller.vendorName ?? "Unknown") / micro")
        releaseBindings(for: controller)

        var bindings = [
            configuredBinding(gamepad.dpad.right, inputID: ControllerInputID.stickUp),
            configuredBinding(gamepad.dpad.left, inputID: ControllerInputID.stickDown),
            configuredBinding(gamepad.dpad.up, inputID: ControllerInputID.stickLeft),
            configuredBinding(gamepad.dpad.down, inputID: ControllerInputID.stickRight),
            configuredBinding(gamepad.buttonA, inputID: ControllerInputID.faceA),
            configuredBinding(gamepad.buttonX, inputID: ControllerInputID.faceA)
        ].compactMap { $0 }

        appendPhysicalButtonBinding(
            to: &bindings,
            profile: controller.physicalInputProfile,
            elementName: "Button A",
            inputID: ControllerInputID.faceA
        )
        appendPhysicalButtonBinding(
            to: &bindings,
            profile: controller.physicalInputProfile,
            elementName: "Button B",
            inputID: ControllerInputID.faceB
        )
        appendPhysicalButtonBinding(
            to: &bindings,
            profile: controller.physicalInputProfile,
            elementName: "Button Y",
            inputID: ControllerInputID.faceY
        )
        appendPhysicalButtonBinding(
            to: &bindings,
            profile: controller.physicalInputProfile,
            elementName: "Button X",
            inputID: ControllerInputID.faceX
        )
        appendPhysicalButtonBinding(
            to: &bindings,
            profile: controller.physicalInputProfile,
            elementName: "Right Shoulder",
            inputID: ControllerInputID.sr
        )
        appendPhysicalButtonBinding(
            to: &bindings,
            profile: controller.physicalInputProfile,
            elementName: "Right Trigger",
            inputID: ControllerInputID.triggerZR
        )
        appendPhysicalButtonBinding(
            to: &bindings,
            profile: controller.physicalInputProfile,
            elementName: "Left Shoulder",
            inputID: ControllerInputID.sl
        )
        appendPhysicalButtonBinding(
            to: &bindings,
            profile: controller.physicalInputProfile,
            elementName: "Left Trigger",
            inputID: ControllerInputID.triggerZL
        )
        appendPhysicalButtonBinding(
            to: &bindings,
            profile: controller.physicalInputProfile,
            elementName: "Button Menu",
            inputID: ControllerInputID.plus
        )
        appendPhysicalButtonBinding(
            to: &bindings,
            profile: controller.physicalInputProfile,
            elementName: "Menu Button",
            inputID: ControllerInputID.plus
        )
        appendPhysicalButtonBinding(
            to: &bindings,
            profile: controller.physicalInputProfile,
            elementName: "Button Options",
            inputID: ControllerInputID.plus
        )
        appendPhysicalButtonBinding(
            to: &bindings,
            profile: controller.physicalInputProfile,
            elementName: "Options Button",
            inputID: ControllerInputID.plus
        )
        appendPhysicalButtonBinding(
            to: &bindings,
            profile: controller.physicalInputProfile,
            elementName: "+",
            inputID: ControllerInputID.plus
        )
        appendPhysicalButtonBinding(
            to: &bindings,
            profile: controller.physicalInputProfile,
            elementName: "Plus",
            inputID: ControllerInputID.plus
        )
        appendPhysicalButtonBinding(
            to: &bindings,
            profile: controller.physicalInputProfile,
            elementName: "Button +",
            inputID: ControllerInputID.plus
        )
        appendPhysicalButtonBindingMatching(
            to: &bindings,
            profile: controller.physicalInputProfile,
            terms: ["+", "plus", "menu", "options"],
            inputID: ControllerInputID.plus
        )
        appendPhysicalButtonBindingMatching(to: &bindings, profile: controller.physicalInputProfile, terms: ["minus", "-"], inputID: ControllerInputID.minus)
        appendPhysicalButtonBindingMatching(to: &bindings, profile: controller.physicalInputProfile, terms: ["home"], inputID: ControllerInputID.home)
        appendPhysicalButtonBindingMatching(to: &bindings, profile: controller.physicalInputProfile, terms: ["capture", "share", "screenshot"], inputID: ControllerInputID.capture)
        appendPhysicalButtonBindingMatching(to: &bindings, profile: controller.physicalInputProfile, terms: ["sl"], inputID: ControllerInputID.sl)
        appendPhysicalButtonBindingMatching(to: &bindings, profile: controller.physicalInputProfile, terms: ["sr"], inputID: ControllerInputID.sr)
        appendPhysicalButtonBindingMatching(to: &bindings, profile: controller.physicalInputProfile, terms: ["left thumbstick button", "left stick button", "left stick press"], inputID: ControllerInputID.leftStickPress)
        appendPhysicalButtonBindingMatching(to: &bindings, profile: controller.physicalInputProfile, terms: ["right thumbstick button", "right stick button", "right stick press"], inputID: ControllerInputID.rightStickPress)

        bindingsByController[ObjectIdentifier(controller)] = bindings
    }

    private func appendPhysicalButtonBindingMatching(
        to bindings: inout [ButtonBinding],
        profile: GCPhysicalInputProfile,
        terms: [String],
        inputID: String
    ) {
        for key in profile.elements.keys.sorted() {
            guard let button = profile.elements[key] as? GCControllerButtonInput else {
                continue
            }

            let searchableText = ([key, button.localizedName] + Array(button.aliases))
                .compactMap { $0?.lowercased() }
                .joined(separator: " ")

            if terms.contains(where: { searchableText.contains($0) }) {
                if let binding = configuredBinding(button, inputID: inputID) {
                    bindings.append(binding)
                }
            }
        }
    }

    private func appendPhysicalButtonBinding(
        to bindings: inout [ButtonBinding],
        profile: GCPhysicalInputProfile,
        elementName: String,
        inputID: String
    ) {
        guard let button = profile.elements[elementName] as? GCControllerButtonInput else {
            return
        }

        if let binding = configuredBinding(button, inputID: inputID) {
            bindings.append(binding)
        }
    }

    private func configuredBinding(_ button: GCControllerButtonInput, inputID: String) -> ButtonBinding? {
        guard let keyCode = mappingStore.keyCode(for: inputID) else {
            button.pressedChangedHandler = nil
            return nil
        }

        let repeatMode = configurableInputSpecs.first { $0.id == inputID }?.repeatMode ?? .none
        switch repeatMode {
        case .none:
            return bind(button, inputID: inputID, keyCode: keyCode, repeats: false)
        case .fast:
            return bind(button, inputID: inputID, keyCode: keyCode, repeats: true)
        case .faceButton:
            return bindFaceButton(button, inputID: inputID, keyCode: keyCode)
        }
    }

    private func bind(_ button: GCControllerButtonInput, inputID: String, keyCode: CGKeyCode, repeats: Bool) -> ButtonBinding {
        let binding = repeats
            ? ButtonBinding.fastRepeating(keyCode: keyCode, keyboard: keyboard)
            : ButtonBinding.nonRepeating(keyCode: keyCode, keyboard: keyboard)

        button.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.observer?.controllerInputChanged(inputID, pressed: pressed)
            binding.update(pressed: pressed)
        }

        return binding
    }

    private func bindFaceButton(_ button: GCControllerButtonInput, inputID: String, keyCode: CGKeyCode) -> ButtonBinding {
        let binding = ButtonBinding.faceButtonRepeating(keyCode: keyCode, keyboard: keyboard)

        button.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.observer?.controllerInputChanged(inputID, pressed: pressed)
            binding.update(pressed: pressed)
        }

        return binding
    }

    private func releaseBindings(for controller: GCController) {
        let controllerID = ObjectIdentifier(controller)
        bindingsByController[controllerID]?.forEach { $0.release() }
        bindingsByController[controllerID] = nil
    }

    func releaseAllBindings() {
        bindingsByController.values.flatMap { $0 }.forEach { $0.release() }
        bindingsByController.removeAll()
        rawHIDReturnMapper.releaseAll()
        keyboard.releaseAllKeys()
    }

    func reloadMappings() {
        bindingsByController.values.flatMap { $0 }.forEach { $0.release() }
        bindingsByController.removeAll()
        rawHIDReturnMapper.releaseAll()
        keyboard.releaseAllKeys()
        GCController.controllers().forEach(configure)
    }
}
