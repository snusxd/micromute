import Foundation

enum MicrophonePrefs {
    private static let selectedUIDKey = "microphone.input.uid.v1"
    private static let muteAllDevicesKey = "microphone.mute.all.devices.v1"

    static var selectedInputUID: String? {
        get { UserDefaults.standard.string(forKey: selectedUIDKey) }
        set { UserDefaults.standard.set(newValue, forKey: selectedUIDKey) }
    }

    static var muteAllDevices: Bool {
        get { UserDefaults.standard.bool(forKey: muteAllDevicesKey) }
        set { UserDefaults.standard.set(newValue, forKey: muteAllDevicesKey) }
    }
}
