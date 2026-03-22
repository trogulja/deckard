import AppKit

/// Holds terminal theme colors and derives chrome colors for the UI.
struct ThemeColors {
    let background: NSColor
    let foreground: NSColor
    let isDark: Bool

    // Derived chrome colors
    let sidebarBackground: NSColor
    let tabBarBackground: NSColor
    let primaryText: NSColor
    let secondaryText: NSColor
    let selectedBackground: NSColor

    init(background: NSColor, foreground: NSColor) {
        self.background = background
        self.foreground = foreground
        self.isDark = background.luminance <= 0.5

        if isDark {
            sidebarBackground = background.adjustedBrightness(by: 0.04)
            tabBarBackground = background.adjustedBrightness(by: 0.02)
            primaryText = foreground
            secondaryText = foreground.withAlphaComponent(0.6)
            selectedBackground = foreground.withAlphaComponent(0.12)
        } else {
            sidebarBackground = .windowBackgroundColor
            tabBarBackground = .windowBackgroundColor
            primaryText = .labelColor
            secondaryText = .secondaryLabelColor
            selectedBackground = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.3)
        }
    }

    /// Default system appearance colors (used before any theme is loaded).
    static let `default` = ThemeColors(
        background: .windowBackgroundColor,
        foreground: .labelColor
    )
}

// MARK: - NSColor helpers

extension NSColor {
    /// Relative luminance (WCAG formula).
    var luminance: Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard let rgb = usingColorSpace(.sRGB) else { return 0 }
        rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
    }

    /// Returns the color with brightness shifted by `delta` (clamped to 0…1).
    func adjustedBrightness(by delta: CGFloat) -> NSColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard let hsb = usingColorSpace(.sRGB) else { return self }
        hsb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return NSColor(hue: h, saturation: s, brightness: min(max(b + delta, 0), 1), alpha: a)
    }
}
