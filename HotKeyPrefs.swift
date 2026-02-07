import Foundation
import Carbon

enum HotKeyPrefs {
    private static let keyCodeKey = "hotkey.keyCode"
    private static let modifiersKey = "hotkey.modifiers"

    static let defaultKeyCode: UInt32 = UInt32(kVK_ANSI_M)
    static let defaultModifiers: UInt32 = UInt32(cmdKey | shiftKey)

    static func load() -> (keyCode: UInt32, modifiers: UInt32) {
        let d = UserDefaults.standard
        if d.object(forKey: keyCodeKey) == nil || d.object(forKey: modifiersKey) == nil {
            return (defaultKeyCode, defaultModifiers)
        }
        let keyCode = UInt32(d.integer(forKey: keyCodeKey))
        let modifiers = UInt32(d.integer(forKey: modifiersKey))
        return (keyCode, modifiers)
    }

    static func save(keyCode: UInt32, modifiers: UInt32) {
        let d = UserDefaults.standard
        d.set(Int(keyCode), forKey: keyCodeKey)
        d.set(Int(modifiers), forKey: modifiersKey)
    }
}
