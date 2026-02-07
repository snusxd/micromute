import AppKit

final class SoundVolumeMenuView: NSView {
    private let label = NSTextField(labelWithString: "")
    private let slider = NSSlider(value: 0.6, minValue: 0.0, maxValue: 1.0, target: nil, action: nil)

    var onChange: ((Float) -> Void)?

    init(volume: Float, isEnabled: Bool) {
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 28))

        label.stringValue = L("label_volume")
        label.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = NSColor.secondaryLabelColor

        slider.doubleValue = Double(max(0, min(volume, 1)))
        slider.isEnabled = isEnabled

        // Make slider update continuously while dragging.
        slider.isContinuous = true
        slider.sendAction(on: [.leftMouseDragged, .leftMouseUp])

        slider.target = self
        slider.action = #selector(sliderChanged)

        addSubview(label)
        addSubview(slider)

        label.translatesAutoresizingMaskIntoConstraints = false
        slider.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),

            slider.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { nil }

    func setVolume(_ v: Float) {
        slider.doubleValue = Double(max(0, min(v, 1)))
    }

    func setEnabled(_ enabled: Bool) {
        slider.isEnabled = enabled
    }

    func setLabel(_ text: String) {
        label.stringValue = text
    }

    @objc private func sliderChanged() {
        onChange?(Float(slider.doubleValue))
    }
}
