import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Dispatch
import Foundation
import GameController
import IOKit.hid

private let app = NSApplication.shared
private let mapperDelegate = AppDelegate()
private let debugDelegate = DebugAppDelegate()
private let hidDebugDelegate = HIDDebugAppDelegate()

if CommandLine.arguments.contains("--self-test") {
    runSelfTest()
} else if CommandLine.arguments.contains("--debug-input") {
    app.setActivationPolicy(.accessory)
    app.delegate = debugDelegate
    app.run()
} else if CommandLine.arguments.contains("--debug-hid") {
    app.setActivationPolicy(.accessory)
    app.delegate = hidDebugDelegate
    app.run()
} else {
    app.setActivationPolicy(.regular)
    app.delegate = mapperDelegate
    app.run()
}
