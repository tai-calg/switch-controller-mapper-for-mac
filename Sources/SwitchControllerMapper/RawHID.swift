import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Dispatch
import Foundation
import GameController
import IOKit.hid

struct HIDDeviceInfo {
    let manufacturer: String?
    let product: String?
    let vendorID: Int?
    let productID: Int?
    let usagePage: Int?
    let usage: Int?
    let maxInputReportSize: Int

    var displayName: String {
        product ?? manufacturer ?? "Unknown HID device"
    }

    var isLikelyNintendoSwitchController: Bool {
        if vendorID == 0x057E {
            return true
        }

        let searchableText = [manufacturer, product]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        return searchableText.contains("joy-con")
            || searchableText.contains("joycon")
            || searchableText.contains("switch")
            || searchableText.contains("nintendo")
    }

    var summary: String {
        let manufacturerText = manufacturer ?? "unknown"
        let productText = product ?? "unknown"
        let vendorText = vendorID.map { String(format: "0x%04X", $0) } ?? "unknown"
        let productIDText = productID.map { String(format: "0x%04X", $0) } ?? "unknown"
        let usagePageText = usagePage.map { String(format: "0x%04X", $0) } ?? "unknown"
        let usageText = usage.map { String(format: "0x%04X", $0) } ?? "unknown"

        return "manufacturer=\(manufacturerText), product=\(productText), vendorID=\(vendorText), productID=\(productIDText), usagePage=\(usagePageText), usage=\(usageText), maxInputReportSize=\(maxInputReportSize)"
    }
}

final class RawHIDReturnDeviceSession {
    private let info: HIDDeviceInfo
    private let keyboard: KeyboardEmitter
    private let mappingStore: MappingStore
    private let reportBuffer: UnsafeMutablePointer<UInt8>
    private let reportBufferLength: Int
    private var activeRawKeyCodesByInputID: [String: CGKeyCode] = [:]

    init(device: IOHIDDevice, info: HIDDeviceInfo, keyboard: KeyboardEmitter, mappingStore: MappingStore) {
        self.info = info
        self.keyboard = keyboard
        self.mappingStore = mappingStore
        reportBufferLength = max(64, info.maxInputReportSize)
        reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: reportBufferLength)
        reportBuffer.initialize(repeating: 0, count: reportBufferLength)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(
            device,
            reportBuffer,
            reportBufferLength,
            RawHIDReturnDeviceSession.reportCallback,
            context
        )
    }

    deinit {
        release()
        reportBuffer.deinitialize(count: reportBufferLength)
        reportBuffer.deallocate()
    }

    func release() {
        for keyCode in activeRawKeyCodesByInputID.values {
            keyboard.releaseKey(keyCode)
        }
        activeRawKeyCodesByInputID.removeAll()
    }

    private func handleReport(result: IOReturn, reportID: UInt32, report: UnsafeMutablePointer<UInt8>?, reportLength: CFIndex) {
        guard result == kIOReturnSuccess, let report else {
            return
        }

        let length = max(0, Int(reportLength))
        guard length > 2 else {
            return
        }

        let bytes = Array(UnsafeBufferPointer(start: report, count: length))
        let reportKind = bytes.first ?? UInt8(reportID & 0xFF)

        switch reportKind {
        case 0x3F:
            updateRawInput(ControllerInputID.shoulderR, pressed: (bytes[2] & 0x40) != 0)
            updateRawInput(ControllerInputID.triggerZR, pressed: (bytes[2] & 0x80) != 0)
        default:
            break
        }
    }

    private func updateRawInput(_ inputID: String, pressed: Bool) {
        if pressed {
            guard activeRawKeyCodesByInputID[inputID] == nil, let keyCode = mappingStore.keyCode(for: inputID) else {
                return
            }

            activeRawKeyCodesByInputID[inputID] = keyCode
            keyboard.pressKey(keyCode)
        } else if let keyCode = activeRawKeyCodesByInputID.removeValue(forKey: inputID) {
            keyboard.releaseKey(keyCode)
        }
    }

    private static let reportCallback: IOHIDReportCallback = { context, result, _, _, reportID, report, reportLength in
        guard let context else {
            return
        }

        let session = Unmanaged<RawHIDReturnDeviceSession>.fromOpaque(context).takeUnretainedValue()
        session.handleReport(result: result, reportID: reportID, report: report, reportLength: reportLength)
    }
}

final class RawHIDReturnMapper {
    private let keyboard: KeyboardEmitter
    private let mappingStore: MappingStore
    private let manager: IOHIDManager
    private var sessions: [String: RawHIDReturnDeviceSession] = [:]
    private var isStarted = false

    init(keyboard: KeyboardEmitter, mappingStore: MappingStore) {
        self.keyboard = keyboard
        self.mappingStore = mappingStore
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func start() {
        guard !isStarted else {
            return
        }

        isStarted = true

        IOHIDManagerSetDeviceMatchingMultiple(manager, matchingDictionaries() as CFArray)
        registerDeviceCallbacks()
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            print("Raw HID Return mapper could not open IOHIDManager: result=\(openResult)")
            return
        }

        matchedDevices().forEach(openReportMappingIfNeeded)
        print("Raw HID mapper: Nintendo Joy-Con raw inputs use configured desktop mappings.")
    }

    func releaseAll() {
        sessions.values.forEach { $0.release() }
    }

    private func registerDeviceCallbacks() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, RawHIDReturnMapper.deviceMatchedCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, RawHIDReturnMapper.deviceRemovedCallback, context)
    }

    private func matchedDevices() -> [IOHIDDevice] {
        guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return []
        }

        return Array(deviceSet)
    }

    private func openReportMappingIfNeeded(_ device: IOHIDDevice) {
        let info = deviceInfo(for: device)
        guard info.isLikelyNintendoSwitchController else {
            return
        }

        let key = deviceKey(device)
        guard sessions[key] == nil else {
            return
        }

        sessions[key] = RawHIDReturnDeviceSession(device: device, info: info, keyboard: keyboard, mappingStore: mappingStore)
        print("Raw HID Return mapper attached: \(info.summary)")
    }

    private func closeReportMapping(for device: IOHIDDevice) {
        let key = deviceKey(device)
        sessions[key]?.release()
        sessions[key] = nil
    }

    private func deviceInfo(for device: IOHIDDevice) -> HIDDeviceInfo {
        HIDDeviceInfo(
            manufacturer: stringProperty(kIOHIDManufacturerKey, device: device),
            product: stringProperty(kIOHIDProductKey, device: device),
            vendorID: intProperty(kIOHIDVendorIDKey, device: device),
            productID: intProperty(kIOHIDProductIDKey, device: device),
            usagePage: intProperty(kIOHIDPrimaryUsagePageKey, device: device),
            usage: intProperty(kIOHIDPrimaryUsageKey, device: device),
            maxInputReportSize: intProperty(kIOHIDMaxInputReportSizeKey, device: device) ?? 64
        )
    }

    private func stringProperty(_ key: String, device: IOHIDDevice) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }

    private func intProperty(_ key: String, device: IOHIDDevice) -> Int? {
        if let number = IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber {
            return number.intValue
        }

        return nil
    }

    private func deviceKey(_ device: IOHIDDevice) -> String {
        let pointer = Unmanaged.passUnretained(device).toOpaque()
        return String(UInt(bitPattern: pointer))
    }

    private func matchingDictionaries() -> [[String: Int]] {
        [
            [
                kIOHIDDeviceUsagePageKey: Int(kHIDPage_GenericDesktop),
                kIOHIDDeviceUsageKey: Int(kHIDUsage_GD_GamePad)
            ],
            [
                kIOHIDDeviceUsagePageKey: Int(kHIDPage_GenericDesktop),
                kIOHIDDeviceUsageKey: Int(kHIDUsage_GD_Joystick)
            ]
        ]
    }

    private static let deviceMatchedCallback: IOHIDDeviceCallback = { context, _, _, device in
        guard let context else {
            return
        }

        let mapper = Unmanaged<RawHIDReturnMapper>.fromOpaque(context).takeUnretainedValue()
        mapper.openReportMappingIfNeeded(device)
    }

    private static let deviceRemovedCallback: IOHIDDeviceCallback = { context, _, _, device in
        guard let context else {
            return
        }

        let mapper = Unmanaged<RawHIDReturnMapper>.fromOpaque(context).takeUnretainedValue()
        mapper.closeReportMapping(for: device)
    }
}

final class RawHIDDeviceSession {
    private let info: HIDDeviceInfo
    private let reportBuffer: UnsafeMutablePointer<UInt8>
    private let reportBufferLength: Int
    private let timestampFormatter: DateFormatter

    init(device: IOHIDDevice, info: HIDDeviceInfo) {
        self.info = info
        reportBufferLength = max(64, info.maxInputReportSize)
        reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: reportBufferLength)
        reportBuffer.initialize(repeating: 0, count: reportBufferLength)

        timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(
            device,
            reportBuffer,
            reportBufferLength,
            RawHIDDeviceSession.reportCallback,
            context
        )
    }

    deinit {
        reportBuffer.deinitialize(count: reportBufferLength)
        reportBuffer.deallocate()
    }

    private func handleReport(result: IOReturn, reportID: UInt32, report: UnsafeMutablePointer<UInt8>?, reportLength: CFIndex) {
        let timestamp = timestampFormatter.string(from: Date())

        guard result == kIOReturnSuccess else {
            print("[\(timestamp)] HID report error from \(info.displayName): result=\(result)")
            return
        }

        guard let report else {
            print("[\(timestamp)] HID report from \(info.displayName): empty report pointer")
            return
        }

        let length = max(0, Int(reportLength))
        let bytes = Array(UnsafeBufferPointer(start: report, count: length))
        let compactHex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        let indexedHex = bytes.enumerated()
            .map { index, byte in String(format: "%02d:%02X", index, byte) }
            .joined(separator: " ")

        print("[\(timestamp)] \(info.displayName) reportID=\(reportID) length=\(length) bytes=\(compactHex)")
        print("[\(timestamp)] \(info.displayName) indexed=\(indexedHex)")
    }

    private static let reportCallback: IOHIDReportCallback = { context, result, _, _, reportID, report, reportLength in
        guard let context else {
            return
        }

        let session = Unmanaged<RawHIDDeviceSession>.fromOpaque(context).takeUnretainedValue()
        session.handleReport(result: result, reportID: reportID, report: report, reportLength: reportLength)
    }
}

final class RawHIDDebugger {
    private let manager: IOHIDManager
    private var sessions: [String: RawHIDDeviceSession] = [:]
    private var traceOnlyLikelyNintendoDevices = false

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func start() {
        IOHIDManagerSetDeviceMatchingMultiple(manager, matchingDictionaries() as CFArray)

        let initialDevices = matchedDevices()
        let likelyNintendoDevices = initialDevices.filter { device in
            deviceInfo(for: device).isLikelyNintendoSwitchController
        }
        traceOnlyLikelyNintendoDevices = !likelyNintendoDevices.isEmpty

        print("Raw IOHID controller debugger is running.")
        print("Press Joy-Con/Switch buttons, especially R and ZR, and compare changed byte indexes between reports.")
        print("Stop with Ctrl-C.")

        if traceOnlyLikelyNintendoDevices {
            print("Found likely Nintendo Switch HID controller(s); filtering to those devices.")
        } else {
            print("No likely Nintendo Switch HID controller was identified; logging all matched HID game controller devices.")
        }

        registerDeviceCallbacks()
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            print("Failed to open IOHIDManager: result=\(openResult)")
            return
        }

        if initialDevices.isEmpty {
            print("No HID game controller devices are currently matched. Connect a controller or press a button to wake it.")
        }

        initialDevices.forEach(openReportLoggingIfNeeded)
    }

    private func registerDeviceCallbacks() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, RawHIDDebugger.deviceMatchedCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, RawHIDDebugger.deviceRemovedCallback, context)
    }

    private func matchedDevices() -> [IOHIDDevice] {
        guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return []
        }

        return deviceSet.sorted { left, right in
            let leftInfo = deviceInfo(for: left)
            let rightInfo = deviceInfo(for: right)
            return leftInfo.displayName.localizedCaseInsensitiveCompare(rightInfo.displayName) == .orderedAscending
        }
    }

    private func openReportLoggingIfNeeded(_ device: IOHIDDevice) {
        let info = deviceInfo(for: device)
        print("\nHID device matched: \(info.summary)")

        guard shouldTrace(info) else {
            print("Skipping non-Nintendo HID controller while likely Nintendo device filtering is active.")
            return
        }

        let key = deviceKey(device)
        guard sessions[key] == nil else {
            return
        }

        sessions[key] = RawHIDDeviceSession(device: device, info: info)
        print("Logging input reports for \(info.displayName).")
    }

    private func closeReportLogging(for device: IOHIDDevice) {
        let info = deviceInfo(for: device)
        sessions[deviceKey(device)] = nil
        print("\nHID device removed: \(info.summary)")
    }

    private func shouldTrace(_ info: HIDDeviceInfo) -> Bool {
        !traceOnlyLikelyNintendoDevices || info.isLikelyNintendoSwitchController
    }

    private func deviceInfo(for device: IOHIDDevice) -> HIDDeviceInfo {
        HIDDeviceInfo(
            manufacturer: stringProperty(kIOHIDManufacturerKey, device: device),
            product: stringProperty(kIOHIDProductKey, device: device),
            vendorID: intProperty(kIOHIDVendorIDKey, device: device),
            productID: intProperty(kIOHIDProductIDKey, device: device),
            usagePage: intProperty(kIOHIDPrimaryUsagePageKey, device: device),
            usage: intProperty(kIOHIDPrimaryUsageKey, device: device),
            maxInputReportSize: intProperty(kIOHIDMaxInputReportSizeKey, device: device) ?? 64
        )
    }

    private func stringProperty(_ key: String, device: IOHIDDevice) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }

    private func intProperty(_ key: String, device: IOHIDDevice) -> Int? {
        if let number = IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber {
            return number.intValue
        }

        return nil
    }

    private func deviceKey(_ device: IOHIDDevice) -> String {
        let pointer = Unmanaged.passUnretained(device).toOpaque()
        return String(UInt(bitPattern: pointer))
    }

    private func matchingDictionaries() -> [[String: Int]] {
        [
            [
                kIOHIDDeviceUsagePageKey: Int(kHIDPage_GenericDesktop),
                kIOHIDDeviceUsageKey: Int(kHIDUsage_GD_GamePad)
            ],
            [
                kIOHIDDeviceUsagePageKey: Int(kHIDPage_GenericDesktop),
                kIOHIDDeviceUsageKey: Int(kHIDUsage_GD_Joystick)
            ]
        ]
    }

    private static let deviceMatchedCallback: IOHIDDeviceCallback = { context, _, _, device in
        guard let context else {
            return
        }

        let debugger = Unmanaged<RawHIDDebugger>.fromOpaque(context).takeUnretainedValue()
        debugger.openReportLoggingIfNeeded(device)
    }

    private static let deviceRemovedCallback: IOHIDDeviceCallback = { context, _, _, device in
        guard let context else {
            return
        }

        let debugger = Unmanaged<RawHIDDebugger>.fromOpaque(context).takeUnretainedValue()
        debugger.closeReportLogging(for: device)
    }
}
