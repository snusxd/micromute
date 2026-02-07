import Foundation

enum SoundPrefs {
    private static let enabledKey = "sounds.enabled.v1"
    private static let volumeKey = "sounds.volume.v1"

    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: enabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var volume: Float {
        get {
            if UserDefaults.standard.object(forKey: volumeKey) == nil { return 0.6 }
            return UserDefaults.standard.float(forKey: volumeKey)
        }
        set { UserDefaults.standard.set(max(0, min(newValue, 1)), forKey: volumeKey) }
    }
}
