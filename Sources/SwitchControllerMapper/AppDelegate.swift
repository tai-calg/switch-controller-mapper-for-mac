import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Dispatch
import Foundation
import GameController
import IOKit.hid

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, ControllerInputObserver {
    private let mappingStore = MappingStore()
    private lazy var mapper = SwitchControllerMapper(mappingStore: mappingStore)
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?
    private var mappingPopupsByInputID: [String: NSPopUpButton] = [:]
    private var diagnosticsLabel: NSTextField?
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        mapper.observer = self
        mapper.start()
        installStatusItem()
        showMainWindow()
        installSignalHandlers()
    }

    func applicationWillTerminate(_ notification: Notification) {
        mapper.releaseAllBindings()
    }

    @objc private func quit(_ sender: Any?) {
        mapper.releaseAllBindings()
        NSApplication.shared.terminate(nil)
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "🎮"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Switch Controller Mapper", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    private func showMainWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 680),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Switch Controller Mapper"
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = makeMainContentView()
        window.makeKeyAndOrderFront(nil)
        mainWindow = window

        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func makeMainContentView() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        mappingPopupsByInputID.removeAll()

        let title = makeLabel("🎮 Switch Controller Mapper", font: .boldSystemFont(ofSize: 22), color: .labelColor)
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "debug"
        let status = makeLabel("Running — Joy-Con input is being mapped to Mac keys. Build: \(buildVersion)", font: .systemFont(ofSize: 14), color: .secondaryLabelColor)

        let permissionStatus = isAccessibilityTrusted(prompt: false) ? "Accessibility: Granted" : "Accessibility: Not granted yet"
        let permission = makeLabel(
            "\(permissionStatus)\nIf keys do not work, allow this app in System Settings → Privacy & Security → Accessibility.",
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor
        )

        let accessibilityButton = NSButton(title: "Open Accessibility Settings", target: self, action: #selector(openAccessibilitySettings(_:)))
        accessibilityButton.bezelStyle = .rounded
        accessibilityButton.translatesAutoresizingMaskIntoConstraints = false

        let diagnostics = makeLabel(
            "Diagnostics: waiting for controller input…",
            font: .monospacedSystemFont(ofSize: 11, weight: .regular),
            color: .secondaryLabelColor
        )
        diagnosticsLabel = diagnostics

        let diagram = JoyConSchematicView()
        diagram.translatesAutoresizingMaskIntoConstraints = false

        let mappingTitle = makeLabel("Button mappings", font: .boldSystemFont(ofSize: 15), color: .labelColor)
        let mappingHint = makeLabel("Choose the Mac key sent by each Joy-Con input. Advanced inputs work when macOS exposes them through GameController or raw HID.", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        let mappingsView = makeMappingsView()

        let applyButton = NSButton(title: "Apply & Save", target: self, action: #selector(applyMappings(_:)))
        applyButton.bezelStyle = .rounded
        applyButton.keyEquivalent = "s"
        applyButton.translatesAutoresizingMaskIntoConstraints = false

        let resetButton = NSButton(title: "Reset Defaults", target: self, action: #selector(resetMappings(_:)))
        resetButton.bezelStyle = .rounded
        resetButton.translatesAutoresizingMaskIntoConstraints = false

        let quitButton = NSButton(title: "Quit Mapper", target: self, action: #selector(quit(_:)))
        quitButton.bezelStyle = .rounded
        quitButton.keyEquivalent = "q"
        quitButton.translatesAutoresizingMaskIntoConstraints = false

        let headerStack = NSStackView(views: [title, status])
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 4
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        let leftStack = NSStackView(views: [diagram, permission, accessibilityButton, diagnostics])
        leftStack.orientation = .vertical
        leftStack.alignment = .leading
        leftStack.spacing = 14
        leftStack.translatesAutoresizingMaskIntoConstraints = false

        let controlsStack = NSStackView(views: [mappingTitle, mappingHint, mappingsView])
        controlsStack.orientation = .vertical
        controlsStack.alignment = .leading
        controlsStack.spacing = 8
        controlsStack.translatesAutoresizingMaskIntoConstraints = false

        let bodyStack = NSStackView(views: [leftStack, controlsStack])
        bodyStack.orientation = .horizontal
        bodyStack.alignment = .top
        bodyStack.spacing = 24
        bodyStack.translatesAutoresizingMaskIntoConstraints = false

        let buttonStack = NSStackView(views: [applyButton, resetButton, quitButton])
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.spacing = 10
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [headerStack, separator(), bodyStack, separator(), buttonStack])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -28),
            diagram.widthAnchor.constraint(equalToConstant: 220),
            diagram.heightAnchor.constraint(equalToConstant: 360),
            mappingsView.widthAnchor.constraint(equalToConstant: 500),
            mappingsView.heightAnchor.constraint(equalToConstant: 430),
            applyButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 110),
            resetButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 110),
            quitButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 110)
        ])

        return container
    }

    private func makeMappingsView() -> NSScrollView {
        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        var addedAdvancedHeader = false
        for spec in configurableInputSpecs {
            if spec.isAdvanced && !addedAdvancedHeader {
                let advancedHeader = makeLabel("Advanced / optional inputs", font: .boldSystemFont(ofSize: 13), color: .secondaryLabelColor)
                advancedHeader.identifier = NSUserInterfaceItemIdentifier("advanced-header")
                contentStack.addArrangedSubview(advancedHeader)
                addedAdvancedHeader = true
            }

            contentStack.addArrangedSubview(makeMappingRow(for: spec))
        }

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalToConstant: 480)
        ])

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .bezelBorder
        scrollView.documentView = documentView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }

    private func makeMappingRow(for spec: ControllerInputSpec) -> NSView {
        let label = makeLabel(spec.displayName, font: .systemFont(ofSize: 13), color: spec.isAdvanced ? .secondaryLabelColor : .labelColor)
        label.widthAnchor.constraint(equalToConstant: 190).isActive = true

        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.target = self
        popup.action = #selector(mappingPopupChanged(_:))
        for choice in MacKeyChoice.allCases {
            popup.addItem(withTitle: choice.displayName)
            popup.lastItem?.representedObject = choice.rawValue
        }

        let selected = mappingStore.keyChoice(for: spec.id)
        if let index = MacKeyChoice.allCases.firstIndex(of: selected) {
            popup.selectItem(at: index)
        }

        mappingPopupsByInputID[spec.id] = popup

        let row = NSStackView(views: [label, popup])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        popup.widthAnchor.constraint(equalToConstant: 210).isActive = true
        return row
    }

    @objc private func applyMappings(_ sender: Any?) {
        saveCurrentMappingsAndReload()
    }

    @objc private func mappingPopupChanged(_ sender: Any?) {
        saveCurrentMappingsAndReload()
    }

    private func saveCurrentMappingsAndReload() {
        for (inputID, popup) in mappingPopupsByInputID {
            guard let rawValue = popup.selectedItem?.representedObject as? String,
                  let choice = MacKeyChoice(rawValue: rawValue) else {
                continue
            }

            mappingStore.set(choice, for: inputID)
        }

        mappingStore.save()
        mapper.reloadMappings()
        keyboardOutputChanged("Mappings applied")
    }

    @objc private func openAccessibilitySettings(_ sender: Any?) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func resetMappings(_ sender: Any?) {
        mappingStore.resetToDefaults()

        for spec in configurableInputSpecs {
            guard let popup = mappingPopupsByInputID[spec.id],
                  let index = MacKeyChoice.allCases.firstIndex(of: spec.defaultKey) else {
                continue
            }

            popup.selectItem(at: index)
        }

        mapper.reloadMappings()
    }

    private func makeLabel(_ text: String, font: NSFont, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(greaterThanOrEqualToConstant: 380).isActive = true
        return box
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        quit(nil)
        return false
    }

    func controllerStatusChanged(_ status: String) {
        updateDiagnostics(status)
    }

    func controllerInputChanged(_ input: String, pressed: Bool) {
        updateDiagnostics("Input \(input): \(pressed ? "pressed" : "released")")
    }

    func keyboardOutputChanged(_ message: String) {
        updateDiagnostics(message)
    }

    private func updateDiagnostics(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            let accessibility = isAccessibilityTrusted(prompt: false) ? "Accessibility OK" : "Accessibility NOT granted"
            let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "debug"
            self?.diagnosticsLabel?.stringValue = "Diagnostics: \(message)\n\(accessibility) · Build \(buildVersion)"
        }
    }

    private func installSignalHandlers() {
        for signalNumber in [SIGINT, SIGTERM] {
            signal(signalNumber, SIG_IGN)

            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler { [weak self] in
                self?.mapper.releaseAllBindings()
                NSApplication.shared.terminate(nil)
            }
            source.resume()
            signalSources.append(source)
        }
    }
}

final class DebugAppDelegate: NSObject, NSApplicationDelegate {
    private let debugger = ControllerInputDebugger()

    func applicationDidFinishLaunching(_ notification: Notification) {
        debugger.start()
    }
}

final class HIDDebugAppDelegate: NSObject, NSApplicationDelegate {
    private let debugger = RawHIDDebugger()

    func applicationDidFinishLaunching(_ notification: Notification) {
        debugger.start()
    }
}

final class JoyConSchematicView: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = self.bounds.insetBy(dx: 12, dy: 10)
        let bodyRect = NSRect(x: bounds.midX - 56, y: bounds.minY + 12, width: 112, height: bounds.height - 24)
        let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 34, yRadius: 34)
        NSColor.systemTeal.withAlphaComponent(0.22).setFill()
        bodyPath.fill()
        NSColor.systemTeal.withAlphaComponent(0.85).setStroke()
        bodyPath.lineWidth = 2
        bodyPath.stroke()

        drawPill("ZR", rect: NSRect(x: bodyRect.minX + 14, y: bodyRect.minY + 12, width: 38, height: 20))
        drawPill("R", rect: NSRect(x: bodyRect.maxX - 52, y: bodyRect.minY + 12, width: 38, height: 20))

        let buttonRadius: CGFloat = 15
        let faceCenter = NSPoint(x: bodyRect.midX, y: bodyRect.minY + 112)
        drawCircle("X", center: NSPoint(x: faceCenter.x, y: faceCenter.y - 32), radius: buttonRadius, fill: .windowBackgroundColor)
        drawCircle("B", center: NSPoint(x: faceCenter.x, y: faceCenter.y + 32), radius: buttonRadius, fill: .windowBackgroundColor)
        drawCircle("Y", center: NSPoint(x: faceCenter.x - 32, y: faceCenter.y), radius: buttonRadius, fill: .windowBackgroundColor)
        drawCircle("A", center: NSPoint(x: faceCenter.x + 32, y: faceCenter.y), radius: buttonRadius, fill: .windowBackgroundColor)
        drawCircle("+", center: NSPoint(x: bodyRect.maxX - 22, y: bodyRect.minY + 66), radius: 11, fill: .controlBackgroundColor)

        drawStick(center: NSPoint(x: bodyRect.midX, y: bodyRect.minY + 220))
        drawCircle("⌂", center: NSPoint(x: bodyRect.midX, y: bodyRect.maxY - 34), radius: 13, fill: .controlBackgroundColor)

        drawRotatedPill("SR", rect: NSRect(x: bodyRect.minX - 38, y: bodyRect.minY + 124, width: 46, height: 20), degrees: -90)
        drawRotatedPill("SL", rect: NSRect(x: bodyRect.minX - 38, y: bodyRect.minY + 184, width: 46, height: 20), degrees: -90)
        drawLabel("Configure keys on the right", at: NSPoint(x: bounds.minX + 18, y: bodyRect.maxY + 4), size: 12, color: .secondaryLabelColor)
    }

    private func drawStick(center: NSPoint) {
        NSColor.controlAccentColor.withAlphaComponent(0.22).setFill()
        let outer = NSBezierPath(ovalIn: NSRect(x: center.x - 34, y: center.y - 34, width: 68, height: 68))
        outer.fill()
        NSColor.controlAccentColor.setStroke()
        outer.lineWidth = 2
        outer.stroke()

        NSColor.controlAccentColor.withAlphaComponent(0.65).setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 18, y: center.y - 18, width: 36, height: 36)).fill()
    }

    private func drawCircle(_ text: String, center: NSPoint, radius: CGFloat, fill: NSColor) {
        let rect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        fill.setFill()
        let path = NSBezierPath(ovalIn: rect)
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()
        drawLabel(text, at: NSPoint(x: rect.midX - 5, y: rect.midY - 8), size: 12, color: .labelColor)
    }

    private func drawPill(_ text: String, rect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        path.fill()
        NSColor.separatorColor.setStroke()
        path.stroke()
        drawLabel(text, at: NSPoint(x: rect.midX - 8, y: rect.midY - 7), size: 10, color: .labelColor)
    }

    private func drawRotatedPill(_ text: String, rect: NSRect, degrees: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: rect.midX, yBy: rect.midY)
        transform.rotate(byDegrees: degrees)
        transform.translateX(by: -rect.midX, yBy: -rect.midY)
        transform.concat()
        drawPill(text, rect: rect)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawLabel(_ text: String, at point: NSPoint, size: CGFloat, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: .medium),
            .foregroundColor: color
        ]
        text.draw(at: point, withAttributes: attributes)
    }
}
