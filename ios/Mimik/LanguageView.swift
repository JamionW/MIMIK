import MimikCore
import SwiftUI

/// One language: the clock's section with its time tabs, then the sections shown at all times.
/// Mirrors the web page (app/index.html), header included.
struct LanguageView: View {
    let entry: LanguageEntry
    let onPick: () -> Void

    @EnvironmentObject private var speaker: Speaker
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SharedSettings.genderKey, store: SharedSettings.defaults) private var genderRaw = Gender.m.rawValue
    @State private var language: Language?
    @State private var inventory: ClipInventory?
    @State private var follower = ClockFollower()
    @State private var now = Date()
    @State private var searching = false
    @State private var query = ""
    @State private var showing: ShowItem?
    @FocusState private var searchFocused: Bool

    private let ticker = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

    private var gender: Gender { Gender(rawValue: genderRaw) ?? .m }
    private var theme: LanguageTheme { LanguageTheme(entry) }

    var body: some View {
        Group {
            if let language {
                page(language)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .tint(theme.accent)
        .onAppear(perform: load)
        .onReceive(ticker) { tick($0) }
        .onChange(of: scenePhase) { if scenePhase == .active { tick(Date()) } }
        .onChange(of: genderRaw) { speaker.gender = gender }
        .fullScreenCover(item: $showing) { ShowModeView(item: $0) }
    }

    private func load() {
        guard language == nil, let l = Catalog.language(entry.code) else { return }
        language = l
        speaker.configure(entry: entry, language: l)
        speaker.gender = gender
        if let root = Catalog.audioRoot(entry.code) {
            inventory = ClipInventory(l, human: entry.human) { FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path) }
        }
        tick(Date())
    }

    private func nowID(_ l: Language) -> String {
        l.section(forHour: Calendar.current.component(.hour, from: now))?.id ?? ""
    }

    private func tick(_ date: Date) {
        now = date
        if let language { follower.observe(nowID: nowID(language)) }
    }

    private func page(_ l: Language) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10, pinnedViews: [.sectionHeaders]) {
                SwiftUI.Section {
                    if searching && !query.trimmingCharacters(in: .whitespaces).isEmpty {
                        results(l)
                    } else {
                        let shownID = follower.shown(nowID: nowID(l))
                        if let s = l.timedSections.first(where: { $0.id == shownID }) { section(s) }
                        ForEach(l.alwaysSections) { section($0) }
                    }
                } header: {
                    header(l)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func header(_ l: Language) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Picker("Speaker", selection: $genderRaw) {
                    Text("He").tag(Gender.m.rawValue)
                    Text("She").tag(Gender.f.rawValue)
                }
                .pickerStyle(.segmented)
                .frame(width: 104)
                Button(entry.native, action: onPick)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.muted)
                    .accessibilityLabel("Change language")
                Button { searching ? closeSearch() : openSearch() } label: {
                    Image(systemName: "magnifyingglass")
                }
                .foregroundStyle(Palette.muted)
                .accessibilityLabel("Search")
                Spacer()
                Text(now, format: .dateTime.hour().minute())
                    .font(.system(size: 22, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.text)
            }
            if let inventory, !inventory.isComplete {
                // On the web this flags clips iOS evicted; here it means the bundle step missed some.
                Text("Offline: \(inventory.present)/\(inventory.total) clips bundled. The rest use the device voice.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if searching {
                HStack {
                    TextField("Search every section", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .focused($searchFocused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Button("Cancel", action: closeSearch)
                }
            } else {
                tabs(l)
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(Palette.bg)
    }

    private func tabs(_ l: Language) -> some View {
        let clock = nowID(l)
        let shown = follower.shown(nowID: clock)
        return HStack(spacing: 6) {
            ForEach(l.timedSections) { s in
                let selected = s.id == shown
                Button { follower.choose(s.id, nowID: clock) } label: {
                    HStack(spacing: 4) {
                        Text(s.title).lineLimit(1).minimumScaleFactor(0.8)
                        if s.id == clock { Text("\u{2022}").foregroundStyle(selected ? theme.accentInk : theme.accent) }
                    }
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .foregroundStyle(selected ? theme.accentInk : (s.id == clock ? Palette.text : Palette.muted))
                    .background(RoundedRectangle(cornerRadius: 10).fill(selected ? theme.accent : Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? theme.accent : Palette.line))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private func results(_ l: Language) -> some View {
        let groups = Search.results(l, query: query).map { SectionHits(section: $0.section, phrases: $0.phrases) }
        if groups.isEmpty {
            Text("Nothing matches \u{201C}\(query.trimmingCharacters(in: .whitespaces))\u{201D}.")
                .foregroundStyle(Palette.muted)
                .padding(.top, 16)
        }
        ForEach(groups) { g in
            sectionTitle(g.section.title)
            ForEach(g.phrases) { card($0) }
        }
    }

    @ViewBuilder
    private func section(_ s: MimikCore.Section) -> some View {
        sectionTitle(s.title)
        ForEach(s.phrases) { card($0) }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .tracking(1)
            .foregroundStyle(Palette.muted)
            .padding(.top, 16)
    }

    private func card(_ p: Phrase) -> some View {
        PhraseCard(phrase: p.form(gender), theme: theme, onShow: { showing = $0 })
    }

    private func openSearch() {
        searching = true
        searchFocused = true
    }

    private func closeSearch() {
        query = ""
        searching = false
        searchFocused = false
    }
}

private struct SectionHits: Identifiable {
    let section: MimikCore.Section
    let phrases: [Phrase]
    var id: String { section.id }
}
