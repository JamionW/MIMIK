import Foundation

/// Ids with a native speaker's recording, per voice: the "human" lists scripts/build.py writes.
public struct HumanRecordings: Decodable, Equatable, Sendable {
    public let m: Set<String>
    public let f: Set<String>

    public init(m: Set<String> = [], f: Set<String> = []) {
        self.m = m
        self.f = f
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        m = try c.decodeIfPresent(Set<String>.self, forKey: .m) ?? []
        f = try c.decodeIfPresent(Set<String>.self, forKey: .f) ?? []
    }

    enum CodingKeys: String, CodingKey { case m, f }

    public func has(_ id: String, voice: Gender) -> Bool {
        (voice == .f ? f : m).contains(id)
    }

    /// The clip's path inside the language's folder, as on the web: a human recording replaces
    /// the TTS clip for its own voice only.
    public func clipPath(_ id: String, voice: Gender) -> String {
        if has(id, voice: voice) {
            return voice == .f ? "audio-human/f/\(id).m4a" : "audio-human/\(id).m4a"
        }
        return voice == .f ? "audio/f/\(id).mp3" : "audio/\(id).mp3"
    }
}

/// How many of a language's clips are present. On the web this tracks what iOS has evicted;
/// in the app the clips are bundled, so a shortfall means the bundle step could not get them,
/// and those phrases play through the device voice.
public struct ClipInventory: Equatable, Sendable {
    public let total: Int
    public let missing: [String]

    public var present: Int { total - missing.count }
    public var isComplete: Bool { missing.isEmpty }

    /// Every clip the language references, in both voices, replies included.
    public static func expected(_ language: Language, human: HumanRecordings) -> [String] {
        language.utterances.flatMap { u in Gender.allCases.map { human.clipPath(u.id, voice: $0) } }
    }

    public init(_ language: Language, human: HumanRecordings, exists: (String) -> Bool) {
        let paths = Self.expected(language, human: human)
        total = paths.count
        missing = paths.filter { !exists($0) }
    }
}
