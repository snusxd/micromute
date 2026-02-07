import AppKit
import Carbon
import CoreAudio

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let mic = MicMuteController()
    private let indicator = MuteIndicatorWindowController()
    private let recorder = ShortcutRecorderWindowController()

    private let store = ShortcutStore()
    private var shortcuts: [Shortcut] = []

    private let sound = SoundManager(isEnabled: SoundPrefs.isEnabled, volume: SoundPrefs.volume)

    private let micDevices = MicrophoneDeviceManager()
    private var micMenuRefreshWorkItem: DispatchWorkItem?

    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        shortcuts = store.bootstrapIfMissing()
        applySavedInputDeviceIfPossible()

        statusBar = StatusBarController(
            onToggle: { [weak self] in self?.toggleMuteAndNotify() },
            onAddShortcut: { [weak self] in self?.addShortcut() },
            onRemoveShortcut: { [weak self] id in self?.removeShortcut(id: id) },

            onMicrophoneMenuWillOpen: { [weak self] in self?.refreshMicrophoneMenu() },
            onSelectInputUID: { [weak self] uid in self?.selectInput(uid: uid) },
            onMicVolumeChanged: { [weak self] v, isFinal in self?.setMicVolume(v, isFinal: isFinal) },

            onSoundsEnabledChanged: { [weak self] enabled in self?.setSoundsEnabled(enabled) },
            onVolumeChanged: { [weak self] v in self?.setSoundVolume(v) }
        )

        statusBar?.update(isMuted: mic.isMuted)
        statusBar?.updateShortcuts(shortcuts)
        statusBar?.updateSounds(isEnabled: sound.isEnabled, volume: sound.volume)

        refreshMicrophoneMenu()
        registerHotKeys()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func toggleMuteAndNotify() {
        mic.toggleMute()
        let muted = mic.isMuted

        statusBar?.update(isMuted: muted)
        indicator.show(status: muted ? .off : .on)

        if muted { sound.playOff() } else { sound.playOn() }
    }

    private func registerHotKeys() {
        do {
            try HotKeyManager.shared.register(shortcuts: shortcuts) { [weak self] in
                self?.toggleMuteAndNotify()
            }
        } catch {
            NSLog("HotKey register failed: \(error)")
        }
    }

    private func addShortcut() {
        recorder.present(
            currentKeyCode: UInt32(kVK_ANSI_M),
            currentModifiers: UInt32(cmdKey | shiftKey)
        ) { [weak self] keyCode, modifiers in
            guard let self else { return }
            self.shortcuts = self.store.add(keyCode: keyCode, modifiers: modifiers)
            self.statusBar?.updateShortcuts(self.shortcuts)
            self.registerHotKeys()
        }
    }

    private func removeShortcut(id: UUID) {
        shortcuts = store.remove(id: id)
        statusBar?.updateShortcuts(shortcuts)
        registerHotKeys()
    }

    private func setSoundsEnabled(_ enabled: Bool) {
        SoundPrefs.isEnabled = enabled
        sound.isEnabled = enabled
        statusBar?.updateSounds(isEnabled: sound.isEnabled, volume: sound.volume)
    }

    private func setSoundVolume(_ volume: Float) {
        SoundPrefs.volume = volume
        sound.volume = SoundPrefs.volume
        statusBar?.updateSounds(isEnabled: sound.isEnabled, volume: sound.volume)
    }

    // MARK: - Microphone menu

    private func refreshMicrophoneMenu() {
        let devices = micDevices.listInputDevices()
        let defaultID = (try? micDevices.getDefaultInputDeviceID()) ?? AudioDeviceID(0)
        let selectedUID = devices.first(where: { $0.id == defaultID })?.uid

        let volInfo: MicrophoneVolumeInfo?
        if defaultID != 0 {
            volInfo = micDevices.volumeInfo(deviceID: defaultID)
        } else {
            volInfo = nil
        }

        statusBar?.updateMicrophone(devices: devices, selectedUID: selectedUID, volumeInfo: volInfo)
    }

    private func selectInput(uid: String) {
        guard let id = micDevices.findDevice(byUID: uid) else { return }

        do {
            try micDevices.setDefaultInputDevice(deviceID: id)
            MicrophonePrefs.selectedInputUID = uid
        } catch {
            NSLog("Failed to set default input device: \(error)")
        }

        refreshMicrophoneMenu()
    }

    private func setMicVolume(_ v: Float, isFinal: Bool) {
        guard let deviceID = try? micDevices.getDefaultInputDeviceID() else { return }

        do {
            try micDevices.setVolume(deviceID: deviceID, volume: v)
        } catch {
            NSLog("Failed to set mic volume: \(error)")
        }

        // IMPORTANT:
        // Do not rebuild the microphone menu while dragging the slider,
        // it replaces the slider view and breaks smooth dragging.
        // Instead refresh after the user stops moving the slider.
        micMenuRefreshWorkItem?.cancel()
        guard isFinal else { return }

        let work = DispatchWorkItem { [weak self] in
            self?.refreshMicrophoneMenu()
        }
        micMenuRefreshWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private func applySavedInputDeviceIfPossible() {
        guard let uid = MicrophonePrefs.selectedInputUID else { return }
        guard let id = micDevices.findDevice(byUID: uid) else { return }

        do {
            try micDevices.setDefaultInputDevice(deviceID: id)
        } catch {
            NSLog("Failed to apply saved input device: \(error)")
        }
    }
}
