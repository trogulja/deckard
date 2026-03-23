import AppKit

/// A flipped NSView subclass so that subviews lay out from top to bottom.
private class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// A card that renders a mini terminal preview using a theme's actual colors.
class ThemeCardView: NSView {
    let themeName: String
    let themePath: String?  // nil = System Default

    var isSelectedTheme: Bool = false {
        didSet {
            updateBorder()
        }
    }

    var onSelect: ((ThemeCardView) -> Void)?

    // Cached parsed scheme (nil for System Default — we use system colors instead)
    private var cachedScheme: TerminalColorScheme?
    private var schemeParsed = false

    private let nameLabel = NSTextField(labelWithString: "")
    private let previewView = NSView()

    init(name: String, path: String?) {
        self.themeName = name
        self.themePath = path
        super.init(frame: .zero)
        setupView()
        parseThemeIfNeeded()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 0
        layer?.masksToBounds = true

        // Preview area
        previewView.wantsLayer = true
        previewView.layer?.cornerRadius = 4
        previewView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(previewView)

        // Name label
        nameLabel.stringValue = themeName
        nameLabel.font = .systemFont(ofSize: 11)
        nameLabel.textColor = .labelColor
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.drawsBackground = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            previewView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            previewView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),

            nameLabel.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 3),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            nameLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -3),
            nameLabel.heightAnchor.constraint(equalToConstant: 14),
        ])
    }

    private func parseThemeIfNeeded() {
        guard !schemeParsed else { return }
        schemeParsed = true
        if let path = themePath {
            cachedScheme = TerminalColorScheme.parse(from: path)
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw the card background
        let bg: NSColor = cachedScheme != nil
            ? cachedScheme!.background
            : (themePath == nil ? NSColor.windowBackgroundColor : NSColor(white: 0.1, alpha: 1))
        bg.setFill()
        let bgRect = previewView.frame
        NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4).fill()

        // Draw sample terminal lines
        let scheme = cachedScheme
        let fg = scheme?.foreground ?? (themePath == nil ? NSColor.labelColor : NSColor(white: 0.9, alpha: 1))
        let palette = scheme?.palette ?? []

        let monoFont = NSFont(name: "SF Mono", size: 10)
            ?? NSFont(name: "Menlo", size: 10)
            ?? NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)

        let green = palette.count > 2 ? palette[2] : NSColor(red: 0, green: 0.8, blue: 0, alpha: 1)
        let red = palette.count > 1 ? palette[1] : NSColor(red: 0.8, green: 0, blue: 0, alpha: 1)
        let cyan = palette.count > 6 ? palette[6] : NSColor(red: 0, green: 0.8, blue: 0.8, alpha: 1)
        let blue = palette.count > 4 ? palette[4] : NSColor(red: 0, green: 0, blue: 0.8, alpha: 1)
        let yellow = palette.count > 3 ? palette[3] : NSColor(red: 0.8, green: 0.8, blue: 0, alpha: 1)
        let dimColor = palette.count > 0 ? palette[0] : NSColor(white: 0.5, alpha: 1)

        let lineHeight: CGFloat = 13
        let leftPad: CGFloat = bgRect.origin.x + 6
        let topPad: CGFloat = bgRect.origin.y + 5

        // Line 1: ~ $ ls -la
        let line1Parts: [(String, NSColor)] = [
            ("~ ", green),
            ("$ ", fg),
            ("ls -la", cyan),
        ]
        drawLine(line1Parts, font: monoFont, x: leftPad, y: topPad)

        // Line 2: drwxr-xr-x 5 user
        let line2Parts: [(String, NSColor)] = [
            ("drwxr-xr-x ", dimColor),
            ("5 ", blue),
            ("user", yellow),
        ]
        drawLine(line2Parts, font: monoFont, x: leftPad, y: topPad + lineHeight)

        // Line 3: error: something
        let line3Parts: [(String, NSColor)] = [
            ("error: ", red),
            ("something", fg),
        ]
        drawLine(line3Parts, font: monoFont, x: leftPad, y: topPad + lineHeight * 2)

        // Line 4: ~ $ cursor
        let cursorGreen = green.withAlphaComponent(0.7)
        let line4Parts: [(String, NSColor)] = [
            ("~ ", green),
            ("$ ", fg),
        ]
        drawLine(line4Parts, font: monoFont, x: leftPad, y: topPad + lineHeight * 3)

        // Draw cursor block
        let cursorX = leftPad + measureWidth(line4Parts, font: monoFont)
        let cursorRect = NSRect(x: cursorX, y: topPad + lineHeight * 3, width: 7, height: lineHeight)
        cursorGreen.setFill()
        NSBezierPath(rect: cursorRect).fill()
    }

    private func drawLine(_ parts: [(String, NSColor)], font: NSFont, x: CGFloat, y: CGFloat) {
        var currentX = x
        for (text, color) in parts {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
            ]
            let str = NSAttributedString(string: text, attributes: attrs)
            str.draw(at: NSPoint(x: currentX, y: y))
            currentX += str.size().width
        }
    }

    private func measureWidth(_ parts: [(String, NSColor)], font: NSFont) -> CGFloat {
        var width: CGFloat = 0
        for (text, color) in parts {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
            ]
            width += NSAttributedString(string: text, attributes: attrs).size().width
        }
        return width
    }

    // MARK: - Selection Border

    private func updateBorder() {
        if isSelectedTheme {
            layer?.borderWidth = 2
            layer?.borderColor = NSColor.controlAccentColor.cgColor
        } else {
            layer?.borderWidth = 0.5
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }

    // MARK: - Click Handling

    override func mouseDown(with event: NSEvent) {
        onSelect?(self)
    }

    override func updateLayer() {
        super.updateLayer()
        updateBorder()
    }
}
