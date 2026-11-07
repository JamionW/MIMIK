import Foundation
import XCTest
@testable import MimikCore

/// The real phrase files, read straight from site/, so these tests check the data the app ships.
enum Fixtures {
    static let site = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("site")

    static var codes: [String] {
        let all = (try? FileManager.default.contentsOfDirectory(atPath: site.path)) ?? []
        return all.filter { FileManager.default.fileExists(atPath: site.appendingPathComponent("\($0)/phrases.json").path) }.sorted()
    }

    static func language(_ code: String) throws -> Language {
        try Language.decode(Data(contentsOf: site.appendingPathComponent("\(code)/phrases.json")))
    }

    static func phrase(_ code: String, _ id: String) throws -> Phrase {
        let p = try language(code).sections.flatMap(\.phrases).first { $0.id == id }
        return try XCTUnwrap(p, "\(code)/\(id) is gone from phrases.json; pick another fixture")
    }
}

final class DataTests: XCTestCase {
    func testEveryLanguageDecodes() throws {
        XCTAssertGreaterThanOrEqual(Fixtures.codes.count, 7)
        for code in Fixtures.codes {
            let l = try Fixtures.language(code)
            XCTAssertFalse(l.timedSections.isEmpty, code)
            XCTAssertFalse(l.alwaysSections.isEmpty, code)
        }
    }

    // The app, widget and clip files all key on ids, so a duplicate would play the wrong clip.
    func testIdsAreUniquePerLanguage() throws {
        for code in Fixtures.codes {
            let ids = try Fixtures.language(code).utterances.map(\.id)
            XCTAssertEqual(ids.count, Set(ids).count, code)
        }
    }

    // Each hour belongs to exactly one timed section, so the clock never lands on a gap.
    func testEveryHourHasExactlyOneSection() throws {
        for code in Fixtures.codes {
            let l = try Fixtures.language(code)
            for h in 0..<24 {
                let n = l.timedSections.filter { $0.hours!.contains(hour: h) }.count
                XCTAssertEqual(n, 1, "\(code) hour \(h)")
            }
        }
    }
}

final class HoursTests: XCTestCase {
    func testPlainRange() {
        let lunch = Hours(12, 15)
        XCTAssertFalse(lunch.contains(hour: 11))
        XCTAssertTrue(lunch.contains(hour: 12))
        XCTAssertTrue(lunch.contains(hour: 14))
        XCTAssertFalse(lunch.contains(hour: 15))
    }

    func testRangeWrapsPastMidnight() {
        let evening = Hours(19, 5)
        for h in [19, 23, 0, 4] { XCTAssertTrue(evening.contains(hour: h), "\(h)") }
        for h in [5, 12, 18] { XCTAssertFalse(evening.contains(hour: h), "\(h)") }
    }

    func testPortugueseClock() throws {
        let pt = try Fixtures.language("pt")
        XCTAssertEqual(pt.section(forHour: 8)?.id, "morning")
        XCTAssertEqual(pt.section(forHour: 13)?.id, "lunch")
        XCTAssertEqual(pt.section(forHour: 2)?.id, "evening")
    }
}

final class ClockFollowerTests: XCTestCase {
    func testFollowsClockUntilChosen() {
        var c = ClockFollower()
        c.observe(nowID: "morning")
        XCTAssertEqual(c.shown(nowID: "morning"), "morning")
        c.choose("evening", nowID: "morning")
        XCTAssertEqual(c.shown(nowID: "morning"), "evening")
        // Ticks within the same bucket keep the choice.
        c.observe(nowID: "morning")
        XCTAssertEqual(c.shown(nowID: "morning"), "evening")
    }

    func testBucketChangeReturnsToClock() {
        var c = ClockFollower()
        c.observe(nowID: "morning")
        c.choose("evening", nowID: "morning")
        c.observe(nowID: "lunch")
        XCTAssertEqual(c.shown(nowID: "lunch"), "lunch")
    }

    func testChoosingTheClocksTabFollowsAgain() {
        var c = ClockFollower()
        c.choose("evening", nowID: "morning")
        c.choose("morning", nowID: "morning")
        XCTAssertNil(c.chosen)
    }
}

final class TimelineTests: XCTestCase {
    func testSectionChangesFollowTheHours() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let pt = try Fixtures.language("pt")
        // 10:30 in the morning section.
        let start = cal.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 10, minute: 30))!
        let changes = pt.sectionChanges(after: start, calendar: cal)
        XCTAssertEqual(changes.map { $0.section.id }, ["lunch", "afternoon", "evening", "morning"])
        XCTAssertEqual(changes.map { cal.component(.hour, from: $0.date) }, [12, 15, 19, 5])
    }
}

final class GenderTests: XCTestCase {
    func testFeminineFormReplacesTextAndPhonetics() throws {
        let p = try Fixtures.phrase("pt", "obrigado")
        XCTAssertEqual(p.form(.m).text, "Obrigado")
        XCTAssertEqual(p.form(.f).text, "Obrigada")
        XCTAssertEqual(p.form(.f).ph, "oh-bree-GAH-duh")
        XCTAssertEqual(p.form(.f).en, p.en)
    }

    func testOverrideOfTextOnlyKeepsPhonetics() throws {
        let p = try Fixtures.phrase("fr", "desole")
        XCTAssertEqual(p.form(.f).text, "Désolée")
        XCTAssertEqual(p.form(.f).ph, p.ph)
    }

    func testRepliesTakeTheOtherVoice() throws {
        let p = try Fixtures.phrase("pt", "um-cafe")
        let reply = try XCTUnwrap(p.replies.first)
        XCTAssertEqual(Utterance(reply).voice(for: .m), .f)
        XCTAssertEqual(Utterance(reply).voice(for: .f), .m)
        XCTAssertEqual(Utterance(p).voice(for: .f), .f)
    }

    func testAltRowsCarryTheirTagInEnglish() throws {
        let p = try Fixtures.phrase("pt", "um-cafe")
        let lisbon = try XCTUnwrap(p.alt.first { $0.tag == "Lisbon" })
        XCTAssertEqual(Utterance(lisbon, phrase: p).en, "\(p.en) (Lisbon)")
    }

    func testSpokenTextPrefersSay() {
        let p = Phrase(id: "x", en: "A ticket to ...", text: "Um bilhete para ...", ph: "oom", say: "Um bilhete para")
        XCTAssertEqual(Utterance(p).spoken, "Um bilhete para")
        XCTAssertEqual(Utterance(p).text, "Um bilhete para ...")
    }
}

final class ClipTests: XCTestCase {
    func testPathsMatchTheWebLayout() {
        let human = HumanRecordings(m: ["obrigado"], f: [])
        XCTAssertEqual(human.clipPath("obrigado", voice: .m), "audio-human/obrigado.m4a")
        XCTAssertEqual(human.clipPath("obrigado", voice: .f), "audio/f/obrigado.mp3")
        XCTAssertEqual(human.clipPath("ola", voice: .m), "audio/ola.mp3")
        let feminine = HumanRecordings(m: [], f: ["ola"])
        XCTAssertEqual(feminine.clipPath("ola", voice: .f), "audio-human/f/ola.m4a")
    }

    func testHumanListDecodesWithMissingVoice() throws {
        let h = try JSONDecoder().decode(HumanRecordings.self, from: Data(#"{"m": ["a"]}"#.utf8))
        XCTAssertTrue(h.has("a", voice: .m))
        XCTAssertFalse(h.has("a", voice: .f))
    }

    func testInventoryCountsBothVoicesOfEveryItem() throws {
        let pt = try Fixtures.language("pt")
        let all = ClipInventory(pt, human: HumanRecordings()) { _ in true }
        XCTAssertEqual(all.total, pt.utterances.count * 2)
        XCTAssertTrue(all.isComplete)
        let none = ClipInventory(pt, human: HumanRecordings()) { !$0.hasPrefix("audio/f/") }
        XCTAssertEqual(none.present, pt.utterances.count)
        XCTAssertFalse(none.isComplete)
    }
}

final class SearchTests: XCTestCase {
    // Expected values come from fold() in app/index.html, run in Node.
    func testFoldMatchesTheWebApp() {
        let cases: [(String, String)] = [
            ("Café", "cafe"), ("kādo de haraemasu ka", "kado de haraemasu ka"), ("KAADO", "kado"),
            ("Não, obrigada", "nao, obrigada"), ("Brötchen", "brotchen"), ("Désolée", "desole"),
            ("カード", "カード"), ("ohayō gozaimasu", "ohayo gozaimasu"), ("Ça", "ca"), ("AAa", "a"),
            ("Ñandú", "nandu"), ("x\u{301}", "x"),
        ]
        for (input, want) in cases { XCTAssertEqual(Search.fold(input), want, input) }
    }

    // Japanese voicing marks are not accents: ガ must not fold to カ.
    func testJapaneseVoicingMarksAreKept() {
        XCTAssertEqual(Array(Search.fold("ガ").unicodeScalars), ["\u{30AB}", "\u{3099}"])
        XCTAssertNotEqual(Search.fold("ガ"), Search.fold("カ"))
    }

    func testAccentFreeQueryFindsAccentedPhrase() throws {
        let ids = Search.results(try Fixtures.language("pt"), query: "cafe").flatMap { $0.phrases.map(\.id) }
        XCTAssertTrue(ids.contains("um-cafe"))
    }

    func testRomanizationWithAndWithoutMacrons() throws {
        let ja = try Fixtures.language("ja")
        for q in ["kado", "kaado", "kādo"] {
            let ids = Search.results(ja, query: q).flatMap { $0.phrases.map(\.id) }
            XCTAssertTrue(ids.contains("kaado"), q)
        }
    }

    func testFeminineTextAndRegionalTagsAreSearchable() throws {
        let pt = try Fixtures.language("pt")
        XCTAssertTrue(Search.results(pt, query: "obrigada").flatMap { $0.phrases.map(\.id) }.contains("obrigado"))
        XCTAssertTrue(Search.results(pt, query: "porto cafe").flatMap { $0.phrases.map(\.id) }.contains("um-cafe"))
    }

    func testEveryTermMustMatch() throws {
        let pt = try Fixtures.language("pt")
        XCTAssertTrue(Search.results(pt, query: "cafe zzzz").isEmpty)
        XCTAssertTrue(Search.results(pt, query: "   ").isEmpty)
    }
}

final class VoiceTests: XCTestCase {
    let voices = [
        VoiceCandidate(language: "pt-BR", name: "Luciana"),
        VoiceCandidate(language: "pt-PT", name: "Catarina"),
        VoiceCandidate(language: "pt-PT", name: "Joana (Enhanced)"),
        VoiceCandidate(language: "hr-HR", name: "Lana"),
    ]

    func testNamedVoiceForExactLocaleWins() {
        XCTAssertEqual(pickVoice(voices, lang: "pt-PT", deviceLangs: nil, deviceVoice: "Joana")?.name, "Joana (Enhanced)")
    }

    func testFallsBackToAnyVoiceForTheLocale() {
        XCTAssertEqual(pickVoice(voices, lang: "pt-PT", deviceLangs: nil, deviceVoice: "Nobody")?.name, "Catarina")
    }

    func testStandInLocale() {
        XCTAssertEqual(pickVoice(voices, lang: "bs-BA", deviceLangs: ["hr-HR"], deviceVoice: nil)?.name, "Lana")
    }

    func testAnyVoiceForTheLanguage() {
        XCTAssertEqual(pickVoice(voices, lang: "pt-AO", deviceLangs: nil, deviceVoice: nil)?.name, "Luciana")
        XCTAssertNil(pickVoice(voices, lang: "ja-JP", deviceLangs: nil, deviceVoice: nil))
    }

    func testUnderscoreLocalesAreNormalised() {
        let v = [VoiceCandidate(language: "pt_PT", name: "Joana")]
        XCTAssertEqual(pickVoice(v, lang: "pt-PT", deviceLangs: nil, deviceVoice: "Joana")?.name, "Joana")
    }
}
