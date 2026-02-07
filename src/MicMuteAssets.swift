import AppKit

final class MicMuteAssets {
    static let shared = MicMuteAssets()

    let trayMuted: NSImage
    let trayUnmuted: NSImage
    let popupMuted: NSImage
    let popupUnmuted: NSImage

    private init() {
        let discovered = Self.discoverPngsInAssets()

        self.trayMuted = Self.pick(kind: .tray, state: .muted, from: discovered)
            ?? Self.sfSymbol("mic.slash.fill", template: true)
        self.trayUnmuted = Self.pick(kind: .tray, state: .unmuted, from: discovered)
            ?? Self.sfSymbol("mic.fill", template: true)

        self.popupMuted = Self.pick(kind: .popup, state: .muted, from: discovered)
            ?? Self.sfSymbol("mic.slash.fill", template: false)
        self.popupUnmuted = Self.pick(kind: .popup, state: .unmuted, from: discovered)
            ?? Self.sfSymbol("mic.fill", template: false)
    }

    private enum Kind { case tray, popup }
    private enum State { case muted, unmuted }

    private static func sfSymbol(_ name: String, template: Bool) -> NSImage {
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
        img.isTemplate = template
        return img
    }

    private static func discoverPngsInAssets() -> [URL] {
        guard let resources = Bundle.main.resourceURL else { return [] }
        let assetsDir = resources.appendingPathComponent("assets", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(at: assetsDir, includingPropertiesForKeys: nil) else {
            return []
        }

        var urls: [URL] = []
        for case let url as URL in enumerator {
            if url.pathExtension.lowercased() == "png" {
                urls.append(url)
            }
        }
        return urls
    }

    private static func pick(kind: Kind, state: State, from urls: [URL]) -> NSImage? {
        let scored = urls
            .map { ($0, score(url: $0, kind: kind, state: state)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }

        guard let best = scored.first?.0 else { return nil }
        guard let img = NSImage(contentsOf: best) else { return nil }

        if kind == .tray {
            img.isTemplate = true
        }
        return img
    }

    private static func score(url: URL, kind: Kind, state: State) -> Int {
        let name = url.lastPathComponent.lowercased()
        let path = url.path.lowercased()

        func hasAny(_ needles: [String], in s: String) -> Bool {
            needles.contains { s.contains($0) }
        }

        var s = 0

        // kind hints
        switch kind {
        case .tray:
            if hasAny(["tray", "menubar", "status", "statusbar"], in: path) { s += 30 }
            if hasAny(["icon"], in: name) { s += 5 }
        case .popup:
            if hasAny(["popup", "window", "indicator", "overlay", "hud"], in: path) { s += 30 }
            if hasAny(["popup", "window", "indicator", "overlay", "hud"], in: name) { s += 10 }
        }

        // state hints
        switch state {
        case .muted:
            if hasAny(["muted", "mute", "off", "disabled", "slash"], in: name) { s += 30 }
            if hasAny(["unmuted", "on", "enabled"], in: name) { s -= 20 }
        case .unmuted:
            if hasAny(["unmuted", "unmute", "on", "enabled", "active"], in: name) { s += 30 }
            if hasAny(["muted", "mute", "off", "disabled", "slash"], in: name) { s -= 20 }
        }

        // prefer smaller tray icons (часто 16/18/24) — грубая эвристика по имени
        if kind == .tray, hasAny(["16", "18", "20", "24"], in: name) { s += 5 }

        return s
    }
}
