import Foundation

/// The He / She setting. It picks gendered forms and the voice; replies take the other voice.
public enum Gender: String, Codable, CaseIterable, Sendable {
    case m, f

    public var other: Gender { self == .m ? .f : .m }
}

/// One language's site/<code>/phrases.json.
public struct Language: Decodable, Sendable {
    public let name: String
    public let native: String
    public let color: String
    public let lang: String
    public let voices: [String: String]
    public let deviceVoice: String?
    public let deviceLangs: [String]?
    public let sections: [Section]

    public init(name: String, native: String, color: String, lang: String, voices: [String: String] = [:],
                deviceVoice: String? = nil, deviceLangs: [String]? = nil, sections: [Section]) {
        self.name = name
        self.native = native
        self.color = color
        self.lang = lang
        self.voices = voices
        self.deviceVoice = deviceVoice
        self.deviceLangs = deviceLangs
        self.sections = sections
    }

    public static func decode(_ data: Data) throws -> Language {
        try JSONDecoder().decode(Language.self, from: data)
    }

    /// Sections with hours, which the clock chooses between (Morning, Lunch, ...).
    public var timedSections: [Section] { sections.filter { $0.hours != nil } }

    /// Sections without hours, shown below the clock's section at all times.
    public var alwaysSections: [Section] { sections.filter { $0.hours == nil } }

    /// The timed section for an hour of the day, or the first one if none covers it.
    public func section(forHour hour: Int) -> Section? {
        let timed = timedSections
        return timed.first { $0.hours!.contains(hour: hour) } ?? timed.first
    }

    /// Every playable item: phrases, regional rows and replies. Ids are unique per language.
    public var utterances: [Utterance] {
        sections.flatMap { sec in
            sec.phrases.flatMap { p -> [Utterance] in
                [Utterance(p)] + p.alt.map { Utterance($0, phrase: p) } + p.replies.map { Utterance($0) }
            }
        }
    }
}

/// A section's [start, end) hours; a range like [19, 5] wraps past midnight.
public struct Hours: Decodable, Equatable, Sendable {
    public let start: Int
    public let end: Int

    public init(_ start: Int, _ end: Int) {
        self.start = start
        self.end = end
    }

    public init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        start = try c.decode(Int.self)
        end = try c.decode(Int.self)
    }

    public func contains(hour h: Int) -> Bool {
        start < end ? (h >= start && h < end) : (h >= start || h < end)
    }
}

public struct Section: Decodable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let hours: Hours?
    public let phrases: [Phrase]

    public init(id: String, title: String, hours: Hours? = nil, phrases: [Phrase]) {
        self.id = id
        self.title = title
        self.hours = hours
        self.phrases = phrases
    }
}

/// Fields a phrase's "f" object may override for the feminine form.
public struct Override: Decodable, Sendable {
    public let en: String?
    public let text: String?
    public let rom: String?
    public let ph: String?
    public let say: String?
    public let note: String?
}

public struct Phrase: Decodable, Identifiable, Sendable {
    public let id: String
    public let en: String
    public let text: String
    public let rom: String?
    public let ph: String
    public let say: String?
    public let note: String?
    public let f: Override?
    public let alt: [Alt]
    public let replies: [Reply]

    enum CodingKeys: String, CodingKey { case id, en, text, rom, ph, say, note, f, alt, replies }

    public init(id: String, en: String, text: String, rom: String? = nil, ph: String, say: String? = nil,
                note: String? = nil, f: Override? = nil, alt: [Alt] = [], replies: [Reply] = []) {
        self.id = id
        self.en = en
        self.text = text
        self.rom = rom
        self.ph = ph
        self.say = say
        self.note = note
        self.f = f
        self.alt = alt
        self.replies = replies
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        en = try c.decode(String.self, forKey: .en)
        text = try c.decode(String.self, forKey: .text)
        rom = try c.decodeIfPresent(String.self, forKey: .rom)
        ph = try c.decode(String.self, forKey: .ph)
        say = try c.decodeIfPresent(String.self, forKey: .say)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        f = try c.decodeIfPresent(Override.self, forKey: .f)
        alt = try c.decodeIfPresent([Alt].self, forKey: .alt) ?? []
        replies = try c.decodeIfPresent([Reply].self, forKey: .replies) ?? []
    }

    /// The phrase as shown for a gender: the "f" fields replace their masculine ones (obrigada).
    public func form(_ gender: Gender) -> Phrase {
        guard gender == .f, let o = f else { return self }
        return Phrase(id: id, en: o.en ?? en, text: o.text ?? text, rom: o.rom ?? rom, ph: o.ph ?? ph,
                      say: o.say ?? say, note: o.note ?? note, f: f, alt: alt, replies: replies)
    }
}

/// A regional form (Lisbon, Porto), shown as a tagged row with its own audio.
public struct Alt: Decodable, Identifiable, Sendable {
    public let id: String
    public let tag: String
    public let text: String
    public let rom: String?
    public let ph: String
    public let say: String?

    public init(id: String, tag: String, text: String, rom: String? = nil, ph: String, say: String? = nil) {
        self.id = id
        self.tag = tag
        self.text = text
        self.rom = rom
        self.ph = ph
        self.say = say
    }
}

/// What the other person is likely to say back. Heard, not said, so it has no phonetics.
public struct Reply: Decodable, Identifiable, Sendable {
    public let id: String
    public let text: String
    public let rom: String?
    public let en: String
    public let say: String?

    public init(id: String, text: String, rom: String? = nil, en: String, say: String? = nil) {
        self.id = id
        self.text = text
        self.rom = rom
        self.en = en
        self.say = say
    }
}

/// Anything with a clip: what to play, what to show on the lock screen, and whose voice it is.
public struct Utterance: Identifiable, Hashable, Sendable {
    public let id: String
    /// What the device voice reads when the clip is missing ("say" where the text has slashes).
    public let spoken: String
    public let text: String
    public let en: String
    public let isReply: Bool

    public init(id: String, spoken: String, text: String, en: String, isReply: Bool) {
        self.id = id
        self.spoken = spoken
        self.text = text
        self.en = en
        self.isReply = isReply
    }

    /// Pass the phrase already formed for the gender, so the feminine text is what is spoken.
    public init(_ p: Phrase) {
        self.init(id: p.id, spoken: p.say ?? p.text, text: p.text, en: p.en, isReply: false)
    }

    public init(_ a: Alt, phrase: Phrase) {
        self.init(id: a.id, spoken: a.say ?? a.text, text: a.text, en: "\(phrase.en) (\(a.tag))", isReply: false)
    }

    public init(_ r: Reply) {
        self.init(id: r.id, spoken: r.say ?? r.text, text: r.text, en: r.en, isReply: true)
    }

    /// Replies are the other person speaking, so they take the voice opposite the user's.
    public func voice(for gender: Gender) -> Gender {
        isReply ? gender.other : gender
    }
}

/// Non-breaking hyphens keep each phonetic word on one line.
public func nonBreaking(_ phonetic: String) -> String {
    phonetic.replacingOccurrences(of: "-", with: "\u{2011}")
}
