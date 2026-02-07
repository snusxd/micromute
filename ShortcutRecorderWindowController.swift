import AppKit
import Carbon

final class ShortcutRecorderWindowController: NSWindowController {
    private let panel: NSPanel
    private let infoLabel: NSTextField
    private let currentLabel: NSTextField
    private let recordButton: NSButton

    private var isRecording = false
    private var eventMonitor: Any?
    private var onSave: ((UInt32, UInt32) -> Void)?

    override init(window: NSWindow?) {
        self.panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 140),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.infoLabel = NSTextField(labelWithString: "Click Record, then press a new shortcut")
        self.currentLabel = NSTextField(labelWithString: "")
        self.recordButton = NSButton(title: "Record", target: nil, action: nil)

        super.init(window: panel)
        setupUI()
    }

    required init?(coder: NSCoder) { nil }

    func present(currentKeyCode: UInt32, currentModifiers: UInt32, onSave: @escaping (UInt32, UInt32) -> Void) {
        self.onSave = onSave
        currentLabel.stringValue = "Current: \(formatShortcut(keyCode: currentKeyCode, modifiers: currentModifiers))"

        isRecording = false
        recordButton.title = "Record"
        stopMonitoring()

        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    private func setupUI() {
        panel.title = "Change Shortcut"

        infoLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        currentLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)

        recordButton.bezelStyle = .rounded
        recordButton.target = self
        recordButton.action = #selector(toggleRecord)

        let stack = NSStackView(views: [infoLabel, currentLabel, recordButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
        ])

        panel.contentView = content
    }

    @objc private func toggleRecord() {
        isRecording.toggle()
        recordButton.title = isRecording ? "Press keys…" : "Record"
        if isRecording { startMonitoring() } else { stopMonitoring() }
    }

    private func startMonitoring() {
        stopMonitoring()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            if !self.isRecording { return event }

            // Esc cancels
            if Int(event.keyCode) == kVK_Escape {
                self.isRecording = false
                self.recordButton.title = "Record"
                self.stopMonitoring()
                return nil
            }

            let keyCode = UInt32(event.keyCode)
            let modifiers = self.carbonModifiers(from: event.modifierFlags)

            self.isRecording = false
            self.recordButton.title = "Record"
            self.stopMonitoring()

            self.onSave?(keyCode, modifiers)
            self.close()
            return nil
        }
    }

    private func stopMonitoring() {
        if let m = eventMonitor {
            NSEvent.removeMonitor(m)
            eventMonitor = nil
        }
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        let f = flags.intersection(.deviceIndependentFlagsMask)
        var m: UInt32 = 0
        if f.contains(.command) { m |= UInt32(cmdKey) }
        if f.contains(.shift) { m |= UInt32(shiftKey) }
        if f.contains(.option) { m |= UInt32(optionKey) }
        if f.contains(.control) { m |= UInt32(controlKey) }
        return m
    }

    private func formatShortcut(keyCode: UInt32, modifiers: UInt32) -> String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + keyName(keyCode)
    }

    private func keyName(_ keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        default: return "(\(keyCode))"
        }
    }

    deinit { stopMonitoring() }
}
