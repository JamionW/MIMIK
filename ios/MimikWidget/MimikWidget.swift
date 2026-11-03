import MimikCore
import SwiftUI
import WidgetKit

/// "Phrases for now": the clock's section in the last language opened, on the home screen and
/// lock screen. The timeline holds an entry for each point in the next day where the section
/// changes, so it stays current without the app running.
@main
struct MimikWidgets: WidgetBundle {
    var body: some Widget {
        CurrentPhrasesWidget()
    }
}

struct CurrentPhrasesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CurrentPhrases", provider: Provider()) { entry in
            PhraseWidgetView(entry: entry)
        }
        .configurationDisplayName("Phrases for now")
        .description("The phrases for this time of day, in the language you last opened.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct PhraseEntry: TimelineEntry {
    struct Line: Hashable {
        let en: String
        let text: String
    }

    let date: Date
    let code: String
    let section: String
    let lines: [Line]
    let theme: LanguageTheme

    static let sample = PhraseEntry(date: Date(), code: "pt", section: "Morning",
                                    lines: [Line(en: "Good morning", text: "Bom dia"),
                                            Line(en: "A coffee, please", text: "Um café, por favor"),
                                            Line(en: "Thank you", text: "Obrigado")],
                                    theme: .picker)
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> PhraseEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (PhraseEntry) -> Void) {
        completion(load().map { entry(at: Date(), section: $0.language.section(forHour: hour(Date())), $0) } ?? .sample)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PhraseEntry>) -> Void) {
        let now = Date()
        guard let loaded = load() else {
            completion(Timeline(entries: [.sample], policy: .after(now.addingTimeInterval(3600))))
            return
        }
        var entries = [entry(at: now, section: loaded.language.section(forHour: hour(now)), loaded)]
        for change in loaded.language.sectionChanges(after: now) {
            entries.append(entry(at: change.date, section: change.section, loaded))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private struct Loaded {
        let info: LanguageEntry
        let language: Language
        let gender: Gender
    }

    private func hour(_ d: Date) -> Int { Calendar.current.component(.hour, from: d) }

    private func load() -> Loaded? {
        let entries = Catalog.entries()
        let saved = SharedSettings.defaults.string(forKey: SharedSettings.languageKey)
        guard let info = entries.first(where: { $0.code == saved }) ?? entries.first(where: { $0.code == "pt" }) ?? entries.first,
              let language = Catalog.language(info.code) else { return nil }
        let gender = Gender(rawValue: SharedSettings.defaults.string(forKey: SharedSettings.genderKey) ?? "") ?? .m
        return Loaded(info: info, language: language, gender: gender)
    }

    private func entry(at date: Date, section: MimikCore.Section?, _ l: Loaded) -> PhraseEntry {
        let lines = (section?.phrases ?? []).prefix(3).map { p -> PhraseEntry.Line in
            let formed = p.form(l.gender)
            return PhraseEntry.Line(en: formed.en, text: formed.text)
        }
        return PhraseEntry(date: date, code: l.info.code, section: section?.title ?? "", lines: Array(lines),
                           theme: LanguageTheme(l.info))
    }
}

struct PhraseWidgetView: View {
    let entry: PhraseEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(URL(string: "mimik://\(entry.code)"))
            .containerBackground(for: .widget) { Palette.card }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Text("\(entry.section): \(entry.lines.first?.text ?? "")")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.section.uppercased()).font(.caption2.weight(.semibold))
                if let first = entry.lines.first {
                    Text(first.text).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                    Text(first.en).font(.caption).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemMedium:
            VStack(alignment: .leading, spacing: 6) {
                title
                ForEach(entry.lines, id: \.self) { line in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(line.text).font(.system(size: 17, weight: .bold)).foregroundStyle(Palette.text).lineLimit(1).minimumScaleFactor(0.7)
                        Text(line.en).font(.system(size: 12)).foregroundStyle(Palette.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 4) {
                title
                Spacer(minLength: 0)
                if let first = entry.lines.first {
                    Text(first.text).font(.system(size: 22, weight: .bold)).foregroundStyle(Palette.text).minimumScaleFactor(0.5)
                    Text(first.en).font(.system(size: 13)).foregroundStyle(Palette.muted).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var title: some View {
        Text(entry.section.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(1)
            .foregroundStyle(entry.theme.accent)
    }
}
