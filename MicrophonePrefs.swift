import Foundation

enum MicrophonePrefs {
    private static let selectedUIDKey = "microphone.input.uid.v1"

    static var selectedInputUID: String? {
        get { UserDefaults.standard.string(forKey: selectedUIDKey) }
        set { UserDefaults.standard.set(newValue, forKey: selectedUIDKey) }
    }
}
