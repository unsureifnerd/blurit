import AppKit

/// Renders optional centered text on top of the blur overlay.
class TextOverlayRenderer: NSView {

    private let containerView = NSView()
    private let textField = NSTextField(labelWithString: "")
    private let settings = SettingsManager.shared

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true

        // Container (optional pill background)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        addSubview(containerView)

        // Text field
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.alignment = .center
        textField.lineBreakMode = .byWordWrapping
        textField.maximumNumberOfLines = 0
        textField.isEditable = false
        textField.isSelectable = false
        textField.drawsBackground = false
        textField.isBordered = false
        containerView.addSubview(textField)

        NSLayoutConstraint.activate([
            // Center container in self
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40),

            // Text field fills container with padding
            textField.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            textField.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            textField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            textField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
        ])
    }

    func refresh() {
        let text = settings.overlayText
        isHidden = text.isEmpty

        guard !text.isEmpty else { return }

        // Font & color
        let font = NSFont.systemFont(ofSize: settings.fontSize, weight: .semibold)
        let color = settings.textColor

        // Shadow
        let shadow: NSShadow? = settings.showTextShadow ? {
            let s = NSShadow()
            s.shadowColor = NSColor.black.withAlphaComponent(0.6)
            s.shadowBlurRadius = 8
            s.shadowOffset = NSSize(width: 0, height: -2)
            return s
        }() : nil

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .shadow: shadow as Any
        ].compactMapValues { $0 }

        textField.attributedStringValue = NSAttributedString(string: text, attributes: attributes)

        // Background pill
        if settings.showTextBackground {
            containerView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor
            containerView.layer?.cornerRadius = (settings.fontSize / 2) + 12
        } else {
            containerView.layer?.backgroundColor = NSColor.clear.cgColor
            containerView.layer?.cornerRadius = 0
        }
    }
}
