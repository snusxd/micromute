import AppKit

final class MuteIndicatorWindowController: NSObject {
    enum Status { case on, off }

    // Change window size here (width/height):
    private static let windowSize = NSSize(width: 96, height: 48)

    private let panel: NSPanel
    private let blurView: NSVisualEffectView
    private let imageView: NSImageView
    private let label: NSTextField

    private var hideWorkItem: DispatchWorkItem?
    private var token: UInt64 = 0
    private var currentStatus: Status = .on
    private var appearanceObservation: NSKeyValueObservation?

    override init() {
        self.panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.windowSize.width, height: Self.windowSize.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.blurView = NSVisualEffectView()
        self.imageView = NSImageView(frame: .zero)
        self.label = NSTextField(labelWithString: "")

        super.init()
        setupWindow()
        setupUI()
        updateTheme()
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            self?.updateTheme()
        }
    }

    func show(status: Status) {
        // Invalidate any previous fade/hide cycle.
        token &+= 1
        let currentToken = token

        hideWorkItem?.cancel()
        hideWorkItem = nil

        apply(status: status)
        moveToCursorScreenTopCenter()
        updateTheme()

        // Cancel any in-flight window alpha animations and reset immediately.
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0
            panel.animator().alphaValue = 1
        }

        showAnimated()

        // Restart countdown from scratch.
        let work = DispatchWorkItem { [weak self] in
            self?.hideAnimated(expectedToken: currentToken)
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: work)
    }

    private func setupWindow() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false

        panel.alphaValue = 1
        panel.sharingType = .none
    }

    private func setupUI() {
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.blendingMode = .withinWindow
        blurView.state = .active
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = 16
        blurView.layer?.masksToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown

        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .left
        label.font = NSFont.systemFont(ofSize: 14, weight: .regular)

        let stack = NSStackView(views: [imageView, label])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 5 // gap between icon and ON/OFF

        let content = NSView()
        content.wantsLayer = true
        content.addSubview(blurView)
        blurView.addSubview(stack)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: content.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            stack.centerXAnchor.constraint(equalTo: blurView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: blurView.centerYAnchor),

            imageView.widthAnchor.constraint(equalToConstant: 22),
            imageView.heightAnchor.constraint(equalToConstant: 22),
        ])

        panel.contentView = content
    }

    private func apply(status: Status) {
        currentStatus = status
        let assets = MicMuteAssets.shared

        // OFF = muted, ON = unmuted
        let img = (status == .off) ? assets.popupMuted : assets.popupUnmuted
        img.isTemplate = true
        imageView.image = img

        label.stringValue = (status == .off) ? "OFF" : "ON"

        updateColors()
    }

    private func moveToCursorScreenTopCenter() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        guard let s = screen else { return }

        let vf = s.visibleFrame
        let size = panel.frame.size
        let margin: CGFloat = 14

        let x = vf.midX - size.width / 2
        let y = vf.maxY - size.height - margin

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func showAnimated() {
        // Optional: quick fade-in (even if it was mid-fade).
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.10
            panel.animator().alphaValue = 1
        }
    }

    private func hideAnimated(expectedToken: UInt64) {
        // If a newer show() happened, ignore this hide.
        guard expectedToken == token else { return }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self else { return }
            // If state changed during fade-out, do nothing.
            guard expectedToken == self.token else { return }

            self.panel.orderOut(nil)
            // Reset for the next show.
            self.panel.alphaValue = 1
        })
    }

    private func updateTheme() {
        let isDark = isDarkAppearance(panel.effectiveAppearance)
        blurView.material = isDark ? .hudWindow : .popover

        updateColors()
    }

    private func updateColors() {
        let palette = currentPalette()
        let tint = (currentStatus == .off) ? palette.off : palette.on
        imageView.contentTintColor = tint
        label.textColor = tint
    }

    private func currentPalette() -> (on: NSColor, off: NSColor) {
        let isDark = isDarkAppearance(panel.effectiveAppearance)
        if isDark {
            return (
                on: NSColor(white: 0.95, alpha: 0.96),
                off: NSColor.systemRed.withAlphaComponent(0.92)
            )
        }
        return (
            on: NSColor(white: 0.12, alpha: 0.94),
            off: NSColor.systemRed.withAlphaComponent(0.88)
        )
    }

    private func isDarkAppearance(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}
