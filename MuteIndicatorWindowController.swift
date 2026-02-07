import AppKit

final class MuteIndicatorWindowController: NSObject {
    enum Status { case on, off }

    // Change window size here (width/height):
    private static let windowSize = NSSize(width: 96, height: 48)

    private let panel: NSPanel
    private let imageView: NSImageView
    private let label: NSTextField

    private var hideWorkItem: DispatchWorkItem?
    private var token: UInt64 = 0

    override init() {
        self.panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.windowSize.width, height: Self.windowSize.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.imageView = NSImageView(frame: .zero)
        self.label = NSTextField(labelWithString: "")

        super.init()
        setupWindow()
        setupUI()
    }

    func show(status: Status) {
        // Invalidate any previous fade/hide cycle.
        token &+= 1
        let currentToken = token

        hideWorkItem?.cancel()
        hideWorkItem = nil

        apply(status: status)
        moveToCursorScreenTopCenter()

        // Cancel any in-flight view animations and reset opacity immediately.
        if let cv = panel.contentView {
            cv.layer?.removeAllAnimations()
            cv.alphaValue = 1
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

        // Keep window alpha stable; we animate contentView alpha instead.
        panel.alphaValue = 1
        panel.sharingType = .none
    }

    private func setupUI() {
        let blur = NSVisualEffectView()
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.material = .hudWindow
        blur.blendingMode = .withinWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 16
        blur.layer?.masksToBounds = true

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
        content.alphaValue = 1

        content.addSubview(blur)
        blur.addSubview(stack)

        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            blur.topAnchor.constraint(equalTo: content.topAnchor),
            blur.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            stack.centerXAnchor.constraint(equalTo: blur.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: blur.centerYAnchor),

            imageView.widthAnchor.constraint(equalToConstant: 22),
            imageView.heightAnchor.constraint(equalToConstant: 22),
        ])

        panel.contentView = content
    }

    private func apply(status: Status) {
        let assets = MicMuteAssets.shared

        // OFF = muted, ON = unmuted
        let img = (status == .off) ? assets.popupMuted : assets.popupUnmuted
        img.isTemplate = true
        imageView.image = img

        label.stringValue = (status == .off) ? "OFF" : "ON"

        let onColor = NSColor.white
        let offColor = NSColor.systemRed.withAlphaComponent(0.92)
        let tint = (status == .off) ? offColor : onColor

        imageView.contentTintColor = tint
        label.textColor = tint
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
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }

        guard let cv = panel.contentView else { return }

        // Optional: quick fade-in (even if it was mid-fade).
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.10
            cv.animator().alphaValue = 1
        }
    }

    private func hideAnimated(expectedToken: UInt64) {
        // If a newer show() happened, ignore this hide.
        guard expectedToken == token else { return }
        guard let cv = panel.contentView else { return }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            cv.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self else { return }
            // If state changed during fade-out, do nothing.
            guard expectedToken == self.token else { return }

            self.panel.orderOut(nil)
            // Reset for the next show.
            self.panel.contentView?.alphaValue = 1
        })
    }
}
