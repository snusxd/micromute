import Foundation

final class LanguageManager {
    static let shared = LanguageManager()
    static let didChangeNotification = Notification.Name("LanguageManager.didChange")

    private let fallbackCode = "en"
    private var languages: [String: [String: String]] = [:]
    private var languageNames: [String: String] = [:]

    private(set) var currentCode: String = "en"

    private init() {
        loadLanguages()

        let saved = LanguagePrefs.code
        if let saved, languages[saved] != nil {
            currentCode = saved
        } else if let system = pickSystemLanguage() {
            currentCode = system
            LanguagePrefs.code = system
        } else if languages[fallbackCode] != nil {
            currentCode = fallbackCode
        } else if let first = languages.keys.sorted().first {
            currentCode = first
        } else {
            currentCode = fallbackCode
            languages[fallbackCode] = ["language_name": "English"]
            languageNames[fallbackCode] = "English"
        }
    }

    func availableLanguages() -> [(code: String, name: String)] {
        let items = languages.keys.map { code in
            (code: code, name: languageNames[code] ?? code)
        }
        return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func setCurrent(code: String) {
        guard languages[code] != nil else { return }
        guard currentCode != code else { return }
        currentCode = code
        LanguagePrefs.code = code
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    func t(_ key: String) -> String {
        if let value = languages[currentCode]?[key], !value.isEmpty { return value }
        if let value = languages[fallbackCode]?[key], !value.isEmpty { return value }
        return key
    }

    func reload() {
        let oldCode = currentCode
        loadLanguages()
        if languages[currentCode] == nil {
            if languages[fallbackCode] != nil {
                currentCode = fallbackCode
            } else if let first = languages.keys.sorted().first {
                currentCode = first
            }
        }
        if currentCode != oldCode {
            LanguagePrefs.code = currentCode
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }

    private func loadLanguages() {
        languages.removeAll()
        languageNames.removeAll()

        guard let dir = langsDirectory() else { return }

        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }

        for url in urls where url.pathExtension.lowercased() == "json" {
            let code = url.deletingPathExtension().lastPathComponent
            guard let data = try? Data(contentsOf: url) else { continue }
            guard let obj = try? JSONSerialization.jsonObject(with: data) else { continue }
            guard let dict = obj as? [String: Any] else { continue }

            var strings: [String: String] = [:]
            for (k, v) in dict {
                if let s = v as? String { strings[k] = s }
            }

            if strings.isEmpty { continue }
            languages[code] = strings
            languageNames[code] = strings["language_name"] ?? code
        }
    }

    private func langsDirectory() -> URL? {
        let fm = FileManager.default

        if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("langs"),
           fm.fileExists(atPath: resourceURL.path) {
            return resourceURL
        }

        let cwdURL = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("langs")
        if fm.fileExists(atPath: cwdURL.path) {
            return cwdURL
        }

        return nil
    }

    private func pickSystemLanguage() -> String? {
        for id in Locale.preferredLanguages {
            if languages[id] != nil { return id }
            if let base = id.split(separator: "-").first.map(String.init),
               languages[base] != nil {
                return base
            }
            if let base = id.split(separator: "_").first.map(String.init),
               languages[base] != nil {
                return base
            }
        }
        return nil
    }
}
