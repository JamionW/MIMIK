import Foundation

/// A device voice as the app sees it: AVSpeechSynthesisVoice's language and name.
public struct VoiceCandidate: Equatable, Sendable {
    public let language: String
    public let name: String
    public let identifier: String

    public init(language: String, name: String, identifier: String = "") {
        self.language = language
        self.name = name
        self.identifier = identifier
    }
}

/// The device voice used when a clip is missing, chosen as pickVoice() in app/index.html does:
/// the named voice for the exact locale (Joana for pt-PT), then any voice for that locale or the
/// listed stand-ins (hr-HR for Bosnian), then any voice for the language.
public func pickVoice(_ voices: [VoiceCandidate], lang: String, deviceLangs: [String]?, deviceVoice: String?) -> VoiceCandidate? {
    func norm(_ v: VoiceCandidate) -> String { v.language.replacingOccurrences(of: "_", with: "-").lowercased() }
    let want = ([lang] + (deviceLangs ?? [])).map { $0.lowercased() }
    if let name = deviceVoice, let v = voices.first(where: { norm($0) == want[0] && $0.name.contains(name) }) {
        return v
    }
    for l in want {
        if let v = voices.first(where: { norm($0) == l }) { return v }
    }
    let base = String(want[0].prefix(2))
    return voices.first { norm($0).hasPrefix(base) }
}
