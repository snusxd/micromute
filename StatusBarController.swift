import AppKit
import Carbon

final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem

    private let toggleItem: NSMenuItem

    // Shortcuts
    private let shortcutsRootItem: NSMenuItem
    private let shortcutsMenu: NSMenu
    private let addShortcutItem: NSMenuItem

    // Microphone
    private let microphoneRootItem: NSMenuItem
    private let microphoneMenu: NSMenu
    private let micInputRootItem: NSMenuItem
    private let micInputMenu: NSMenu
    private let micVolumeItem: NSMenuItem
    private var micVolumeView: MicrophoneVolumeMenuView?

    // Sounds
    private let soundsRootItem: NSMenuItem
    private let soundsMenu: NSMenu
    private let soundsEnabledItem: NSMenuItem
    private let volumeItem: NSMenuItem
    private var volumeView: SoundVolumeMenuView?

    private let quitItem: NSMenuItem

    private let onToggle: () -> Void
    private let onAddShortcut: () -> Void
    private let onRemoveShortcut: (UUID) -> Void

    private let onMicrophoneMenuWillOpen: () -> Void
    private let onSelectInputUID: (String) -> Void
    private let onMicVolumeChanged: (Float) -> Void

    private let onSoundsEnabledChanged: (Bool) -> Void
    private let onVolumeChanged: (Float) -> Void

    init(
        onToggle: @escaping () -> Void,
        onAddShortcut: @escaping () -> Void,
        onRemoveShortcut: @escaping (UUID) -> Void,

        onMicrophoneMenuWillOpen: @escaping () -> Void,
        onSelectInputUID: @escaping (String) -> Void,
        onMicVolumeChanged: @escaping (Float) -> Void,

        onSoundsEnabledChanged: @escaping (Bool) -> Void,
        onVolumeChanged: @escaping (Float) -> Void
    ) {
        self.onToggle = onToggle
        self.onAddShortcut = onAddShortcut
        self.onRemoveShortcut = onRemoveShortcut

        self.onMicrophoneMenuWillOpen = onMicrophoneMenuWillOpen
        self.onSelectInputUID = onSelectInputUID
        self.onMicVolumeChanged = onMicVolumeChanged

        self.onSoundsEnabledChanged = onSoundsEnabledChanged
        self.onVolumeChanged = onVolumeChanged

        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        self.toggleItem = NSMenuItem(title: "Toggle Mute", action: #selector(toggleClicked), keyEquivalent: "")

        self.shortcutsRootItem = NSMenuItem(title: "Shortcuts", action: nil, keyEquivalent: "")
        self.shortcutsMenu = NSMenu(title: "Shortcuts")
        self.addShortcutItem = NSMenuItem(title: "+ Add Shortcut…", action: #selector(addShortcutClicked), keyEquivalent: "")

        self.microphoneRootItem = NSMenuItem(title: "Microphone", action: nil, keyEquivalent: "")
        self.microphoneMenu = NSMenu(title: "Microphone")
        self.micInputRootItem = NSMenuItem(title: "Devices", action: nil, keyEquivalent: "")
        self.micInputMenu = NSMenu(title: "Devices")
        self.micVolumeItem = NSMenuItem()

        self.soundsRootItem = NSMenuItem(title: "Sounds", action: nil, keyEquivalent: "")
        self.soundsMenu = NSMenu(title: "Sounds")
        self.soundsEnabledItem = NSMenuItem(title: "Sounds", action: #selector(toggleSoundsEnabled), keyEquivalent: "")
        self.volumeItem = NSMenuItem()

        self.quitItem = NSMenuItem(title: "Quit", action: #selector(quitClicked), keyEquivalent: "q")

        super.init()

        toggleItem.target = self
        addShortcutItem.target = self
        quitItem.target = self

        soundsEnabledItem.target = self

        shortcutsRootItem.submenu = shortcutsMenu

        microphoneRootItem.submenu = microphoneMenu
        microphoneMenu.delegate = self
        micInputRootItem.submenu = micInputMenu

        soundsRootItem.submenu = soundsMenu

        let menu = NSMenu()
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(shortcutsRootItem)
        menu.addItem(microphoneRootItem)
        menu.addItem(soundsRootItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)

        statusItem.menu = menu

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.toolTip = "Mic Mute"
        }

        rebuildShortcutsMenu([])
        rebuildMicrophoneMenu(devices: [], selectedUID: nil, volumeInfo: nil)
        rebuildSoundsMenu(isEnabled: true, volume: 0.6)
    }

    // MARK: - Public updates

    func update(isMuted: Bool) {
        let assets = MicMuteAssets.shared
        statusItem.button?.image = isMuted ? assets.trayMuted : assets.trayUnmuted
        toggleItem.title = isMuted ? "Unmute Microphone" : "Mute Microphone"
        statusItem.button?.toolTip = isMuted ? "Microphone: Muted" : "Microphone: On"
    }

    func updateShortcuts(_ shortcuts: [Shortcut]) {
        rebuildShortcutsMenu(shortcuts)
    }

    func updateMicrophone(devices: [MicrophoneInputDevice], selectedUID: String?, volumeInfo: MicrophoneVolumeInfo?) {
        rebuildMicrophoneMenu(devices: devices, selectedUID: selectedUID, volumeInfo: volumeInfo)
    }

    func updateSounds(isEnabled: Bool, volume: Float) {
        soundsEnabledItem.state = isEnabled ? .on : .off
        volumeView?.setVolume(volume)
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        if menu === microphoneMenu {
            onMicrophoneMenuWillOpen()
        }
    }

    // MARK: - Build menus

    private func rebuildShortcutsMenu(_ shortcuts: [Shortcut]) {
        shortcutsMenu.removeAllItems()

        if shortcuts.isEmpty {
            let empty = NSMenuItem(title: "No shortcuts", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            shortcutsMenu.addItem(empty)
        } else {
            for s in shortcuts {
                let title = "✕  " + ShortcutFormatter.format(keyCode: s.keyCode, modifiers: s.modifiers)
                let item = NSMenuItem(title: title, action: #selector(removeShortcut(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = s.id.uuidString
                shortcutsMenu.addItem(item)
            }
        }

        shortcutsMenu.addItem(.separator())
        shortcutsMenu.addItem(addShortcutItem)
    }

    private func rebuildMicrophoneMenu(devices: [MicrophoneInputDevice], selectedUID: String?, volumeInfo: MicrophoneVolumeInfo?) {
        microphoneMenu.removeAllItems()

        // Input submenu
        micInputMenu.removeAllItems()
        if devices.isEmpty {
            let empty = NSMenuItem(title: "No input devices", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            micInputMenu.addItem(empty)
        } else {
            for d in devices {
                let item = NSMenuItem(title: d.name, action: #selector(selectInputDevice(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = d.uid
                item.state = (d.uid == selectedUID) ? .on : .off
                micInputMenu.addItem(item)
            }
        }

        microphoneMenu.addItem(micInputRootItem)

        // Volume slider
        let vol = volumeInfo?.volume ?? 0.5
        let settable = volumeInfo?.isSettable ?? false

        let view = MicrophoneVolumeMenuView(volume: vol, isEnabled: settable)
        view.onChange = { [weak self] v in self?.onMicVolumeChanged(v) }
        micVolumeView = view

        micVolumeItem.view = view
        microphoneMenu.addItem(micVolumeItem)
    }

    private func rebuildSoundsMenu(isEnabled: Bool, volume: Float) {
        soundsMenu.removeAllItems()

        soundsEnabledItem.state = isEnabled ? .on : .off
        soundsMenu.addItem(soundsEnabledItem)

        let view = SoundVolumeMenuView(volume: volume)
        view.onChange = { [weak self] v in
            self?.onVolumeChanged(v)
        }
        volumeView = view

        volumeItem.view = view
        soundsMenu.addItem(volumeItem)
    }

    // MARK: - Actions

    @objc private func toggleClicked() { onToggle() }
    @objc private func addShortcutClicked() { onAddShortcut() }

    @objc private func removeShortcut(_ sender: NSMenuItem) {
        guard let s = sender.representedObject as? String, let id = UUID(uuidString: s) else { return }
        onRemoveShortcut(id)
    }

    @objc private func selectInputDevice(_ sender: NSMenuItem) {
        guard let uid = sender.representedObject as? String else { return }
        onSelectInputUID(uid)
    }

    @objc private func toggleSoundsEnabled() {
        let newValue = (soundsEnabledItem.state != .on)
        soundsEnabledItem.state = newValue ? .on : .off
        onSoundsEnabledChanged(newValue)
    }

    @objc private func quitClicked() { NSApp.terminate(nil) }
}

enum ShortcutFormatter {
    static func format(keyCode: UInt32, modifiers: UInt32) -> String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + keyName(keyCode)
    }

    private static func keyName(_ keyCode: UInt32) -> String {
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
}
