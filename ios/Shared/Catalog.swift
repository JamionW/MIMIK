import Foundation
import MimikCore

/// Settings the app writes and the widget reads, through the shared app group.
enum SharedSettings {
    static let appGroup = "group.com.jamionw.mimik"
    static let languageKey = "lang"
    static let genderKey = "gender"

    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }
}

struct ThemeColors: Decodable {
    let accent: String
    let accentInk: String
    let tag: String

    enum CodingKeys: String, CodingKey {
        case accent
        case accentInk = "accent-ink"
        case tag
    }
}

/// One row of Phrases/languages.json, written by scripts/bundle_ios.py.
struct LanguageEntry: Decodable, Identifiable, Hashable {
    let code: String
    let name: String
    let native: String
    let color: String
    let lang: String
    /// "light" and "dark" accents, computed by scripts/build.py's theme_tokens.
    let theme: [String: ThemeColors]
    let human: HumanRecordings

    var id: String { code }

    static func == (a: LanguageEntry, b: LanguageEntry) -> Bool { a.code == b.code }
    func hash(into h: inout Hasher) { h.combine(code) }
}

/// The bundled content: Phrases/ in the app and the widget, Audio/ in the app only.
enum Catalog {
    static func entries(in bundle: Bundle = .main) -> [LanguageEntry] {
        guard let url = bundle.url(forResource: "Phrases", withExtension: nil)?.appendingPathComponent("languages.json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([LanguageEntry].self, from: data)) ?? []
    }

    static func language(_ code: String, in bundle: Bundle = .main) -> Language? {
        guard let url = bundle.url(forResource: "Phrases", withExtension: nil)?.appendingPathComponent("\(code).json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? Language.decode(data)
    }

    /// The language's clip folder, laid out as on the web (audio/, audio/f/, audio-human/).
    static func audioRoot(_ code: String, in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: "Audio", withExtension: nil)?.appendingPathComponent(code)
    }
}
