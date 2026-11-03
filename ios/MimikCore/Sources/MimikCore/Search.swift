import Foundation

/// Search across every section, as in app/index.html: English, native text in both genders,
/// romanization, regional rows and replies. Accents and macrons on Latin letters are ignored
/// (Japanese voicing marks are kept) and doubled vowels collapsed, so "cafe" finds café and both
/// "kado" and "kaado" find kādo.
public enum Search {
    public static func fold(_ s: String) -> String {
        var stripped = String.UnicodeScalarView()
        var afterLatin = false
        for u in s.decomposedStringWithCanonicalMapping.unicodeScalars {
            if isMark(u) {
                if !afterLatin { stripped.append(u) }
                continue
            }
            afterLatin = isLatin(u)
            stripped.append(u)
        }
        var out = String.UnicodeScalarView()
        var prev: Unicode.Scalar?
        for u in String(stripped).lowercased().unicodeScalars {
            if u == prev, "aeiou".unicodeScalars.contains(u) { continue }
            out.append(u)
            prev = u
        }
        return String(out)
    }

    public static func haystack(_ p: Phrase) -> String {
        var parts: [String?] = [p.en, p.text, p.rom, p.f?.text]
        for a in p.alt { parts += [a.tag, a.text, a.rom] }
        for r in p.replies { parts += [r.en, r.text, r.rom] }
        return fold(parts.compactMap { $0 }.joined(separator: " \n "))
    }

    /// Sections with their matching phrases, in file order; empty when nothing matches.
    public static func results(_ language: Language, query: String) -> [(section: Section, phrases: [Phrase])] {
        let terms = fold(query).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !terms.isEmpty else { return [] }
        return language.sections.compactMap { sec -> (section: Section, phrases: [Phrase])? in
            let hits = sec.phrases.filter { p in
                let h = haystack(p)
                return terms.allSatisfy { h.contains($0) }
            }
            if hits.isEmpty { return nil }
            return (section: sec, phrases: hits)
        }
    }

    static func isMark(_ u: Unicode.Scalar) -> Bool {
        switch u.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark: return true
        default: return false
        }
    }

    // Unicode's Latin script blocks. Foundation on Linux has no script property, and after
    // decomposition nearly every accented letter has an ASCII base anyway.
    static func isLatin(_ u: Unicode.Scalar) -> Bool {
        switch u.value {
        case 0x41...0x5A, 0x61...0x7A, 0xAA, 0xBA, 0xC0...0xD6, 0xD8...0xF6, 0xF8...0x24F,
             0x250...0x2AF, 0x1D00...0x1D7F, 0x1E00...0x1EFF, 0x2C60...0x2C7F, 0xA720...0xA7FF,
             0xAB30...0xAB6F, 0xFF21...0xFF3A, 0xFF41...0xFF5A:
            return true
        default:
            return false
        }
    }
}
