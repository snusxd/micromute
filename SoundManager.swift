import AppKit

final class SoundManager {
    var isEnabled: Bool
    var volume: Float

    init(isEnabled: Bool, volume: Float) {
        self.isEnabled = isEnabled
        self.volume = max(0, min(volume, 1))
    }

    func playOn() {
        play(preferredNames: ["Purr"])
    }

    func playOff() {
        play(preferredNames: ["Tink"])
    }

    private func play(preferredNames: [String]) {
        guard isEnabled else { return }

        if let sound = loadSound(preferredNames: preferredNames) {
            sound.volume = volume
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func loadSound(preferredNames: [String]) -> NSSound? {
        for name in preferredNames {
            if let s = loadSystemSoundFile(named: name) { return s }
            if let s = NSSound(named: NSSound.Name(name)) { return s }
        }
        return nil
    }

    private func loadSystemSoundFile(named name: String) -> NSSound? {
        let candidates: [URL] = [
            URL(fileURLWithPath: "/System/Library/Sounds/\(name).aiff"),
            URL(fileURLWithPath: "/System/Library/Sounds/\(name).wav"),
            URL(fileURLWithPath: "/Library/Sounds/\(name).aiff"),
            URL(fileURLWithPath: "/Library/Sounds/\(name).wav"),
        ]

        for url in candidates {
            if FileManager.default.fileExists(atPath: url.path),
               let s = NSSound(contentsOf: url, byReference: true) {
                return s
            }
        }
        return nil
    }
}
