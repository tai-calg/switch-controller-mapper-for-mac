import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Dispatch
import Foundation
import GameController
import IOKit.hid

final class ControllerInputDebugger {
    private var connectedControllers: [ObjectIdentifier: GCController] = [:]

    func start() {
        GCController.shouldMonitorBackgroundEvents = true

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

            self?.disconnect(controller)
        }

        GCController.controllers().forEach(configure)
        GCController.startWirelessControllerDiscovery()

        print("Switch controller input debugger is running.")
        print("Press Joy-Con buttons/sticks. Copy the lines printed for A/B/X/Y/R/ZR/L/ZL and stick directions.")
        print("Stop with Ctrl-C.")
    }

    private func configure(_ controller: GCController) {
        let controllerID = ObjectIdentifier(controller)
        connectedControllers[controllerID] = controller

        let name = controller.vendorName ?? "Unknown"
        print("\nController connected: \(name)")
        print("Profiles: extended=\(controller.extendedGamepad != nil), micro=\(controller.microGamepad != nil)")

        configurePhysicalInputProfile(controller.physicalInputProfile, controllerName: name)

        if let gamepad = controller.extendedGamepad {
            configureExtendedDebug(gamepad, controllerName: name)
        }

        if let gamepad = controller.microGamepad {
            configureMicroDebug(gamepad, controllerName: name)
        }
    }

    private func disconnect(_ controller: GCController) {
        connectedControllers[ObjectIdentifier(controller)] = nil
        print("\nController disconnected: \(controller.vendorName ?? "Unknown")")
    }

    private func configurePhysicalInputProfile(_ profile: GCPhysicalInputProfile, controllerName: String) {
        print("Physical input elements:")

        for key in profile.elements.keys.sorted() {
            guard let element = profile.elements[key] else {
                continue
            }

            let elementName = describe(element, fallback: key)
            print("- physical[\(key)] \(type(of: element)) aliases=\(Array(element.aliases).sorted())")

            if let button = element as? GCControllerButtonInput {
                button.pressedChangedHandler = { _, value, pressed in
                    print("physical button \(elementName): pressed=\(pressed) value=\(String(format: "%.3f", value))")
                }
            } else if let directionPad = element as? GCControllerDirectionPad {
                directionPad.valueChangedHandler = { _, xValue, yValue in
                    print("physical dpad \(elementName): x=\(String(format: "%.3f", xValue)) y=\(String(format: "%.3f", yValue))")
                }
            } else if let axis = element as? GCControllerAxisInput {
                axis.valueChangedHandler = { _, value in
                    print("physical axis \(elementName): value=\(String(format: "%.3f", value))")
                }
            }
        }
    }

    private func configureExtendedDebug(_ gamepad: GCExtendedGamepad, controllerName: String) {
        print("Extended profile available for \(controllerName)")

        bindDebug(gamepad.dpad.up, name: "extended.dpad.up")
        bindDebug(gamepad.dpad.down, name: "extended.dpad.down")
        bindDebug(gamepad.dpad.left, name: "extended.dpad.left")
        bindDebug(gamepad.dpad.right, name: "extended.dpad.right")
        bindDebug(gamepad.leftThumbstick.up, name: "extended.leftThumbstick.up")
        bindDebug(gamepad.leftThumbstick.down, name: "extended.leftThumbstick.down")
        bindDebug(gamepad.leftThumbstick.left, name: "extended.leftThumbstick.left")
        bindDebug(gamepad.leftThumbstick.right, name: "extended.leftThumbstick.right")
        bindDebug(gamepad.rightThumbstick.up, name: "extended.rightThumbstick.up")
        bindDebug(gamepad.rightThumbstick.down, name: "extended.rightThumbstick.down")
        bindDebug(gamepad.rightThumbstick.left, name: "extended.rightThumbstick.left")
        bindDebug(gamepad.rightThumbstick.right, name: "extended.rightThumbstick.right")
        bindDebug(gamepad.buttonA, name: "extended.buttonA")
        bindDebug(gamepad.buttonB, name: "extended.buttonB")
        bindDebug(gamepad.buttonX, name: "extended.buttonX")
        bindDebug(gamepad.buttonY, name: "extended.buttonY")
        bindDebug(gamepad.leftShoulder, name: "extended.leftShoulder")
        bindDebug(gamepad.rightShoulder, name: "extended.rightShoulder")
        bindDebug(gamepad.leftTrigger, name: "extended.leftTrigger")
        bindDebug(gamepad.rightTrigger, name: "extended.rightTrigger")
    }

    private func configureMicroDebug(_ gamepad: GCMicroGamepad, controllerName: String) {
        print("Micro profile available for \(controllerName)")

        bindDebug(gamepad.dpad.up, name: "micro.dpad.up")
        bindDebug(gamepad.dpad.down, name: "micro.dpad.down")
        bindDebug(gamepad.dpad.left, name: "micro.dpad.left")
        bindDebug(gamepad.dpad.right, name: "micro.dpad.right")
        bindDebug(gamepad.buttonA, name: "micro.buttonA")
        bindDebug(gamepad.buttonX, name: "micro.buttonX")
    }

    private func bindDebug(_ button: GCControllerButtonInput, name: String) {
        button.pressedChangedHandler = { _, value, pressed in
            print("\(name): pressed=\(pressed) value=\(String(format: "%.3f", value))")
        }
    }

    private func describe(_ element: GCControllerElement, fallback: String) -> String {
        if let localizedName = element.localizedName {
            return "\(fallback) / \(localizedName)"
        }

        return fallback
    }
}
