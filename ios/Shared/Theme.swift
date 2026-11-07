import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: String) {
        let v = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    /// A colour that follows light and dark mode.
    static func dynamic(_ light: String, _ dark: String) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

/// The page colours from app/index.html.
enum Palette {
    static let bg = Color.dynamic("#f6f3ee", "#121212")
    static let card = Color.dynamic("#ffffff", "#1c1c1c")
    static let line = Color.dynamic("#e4dfd6", "#2c2c2c")
    static let text = Color.dynamic("#1a1a1a", "#f2efe9")
    static let muted = Color.dynamic("#6b665e", "#9a958c")
}

/// A language's accent, built from its colour the same way the web build does.
struct LanguageTheme {
    let accent: Color
    let accentInk: Color
    let tag: Color

    init(_ entry: LanguageEntry) {
        let l = entry.theme["light"], d = entry.theme["dark"]
        accent = .dynamic(l?.accent ?? entry.color, d?.accent ?? entry.color)
        accentInk = .dynamic(l?.accentInk ?? "#ffffff", d?.accentInk ?? "#000000")
        tag = .dynamic(l?.tag ?? "#e8eef8", d?.tag ?? "#1f2a3c")
    }

    init(accent: Color, accentInk: Color, tag: Color) {
        self.accent = accent
        self.accentInk = accentInk
        self.tag = tag
    }

    /// The picker's original blue.
    static let picker = LanguageTheme(accent: .dynamic("#1f4e9c", "#7fa8e8"),
                                      accentInk: .dynamic("#ffffff", "#0f1a2c"),
                                      tag: .dynamic("#e8eef8", "#1f2a3c"))
}
