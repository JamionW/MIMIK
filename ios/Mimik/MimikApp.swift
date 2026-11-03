import MimikCore
import SwiftUI
import WidgetKit

@main
struct MimikApp: App {
    @StateObject private var speaker = Speaker()

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(speaker)
        }
    }
}

/// The picker, which forwards to the last language used, as the web root page does.
/// mimik://<code> (the widget's link) opens a language directly.
struct RootView: View {
    @AppStorage(SharedSettings.languageKey, store: SharedSettings.defaults) private var savedCode = ""
    @State private var path: [String] = []
    @State private var forwarded = false
    private let entries = Catalog.entries()

    var body: some View {
        NavigationStack(path: $path) {
            PickerView(entries: entries, onSelect: open)
                .navigationDestination(for: String.self) { code in
                    if let entry = entries.first(where: { $0.code == code }) {
                        LanguageView(entry: entry, onPick: { path = [] })
                    }
                }
        }
        .onAppear {
            guard !forwarded else { return }
            forwarded = true
            if entries.contains(where: { $0.code == savedCode }) { path = [savedCode] }
        }
        .onOpenURL { url in
            if let code = url.host, entries.contains(where: { $0.code == code }) { open(code) }
        }
    }

    private func open(_ code: String) {
        savedCode = code
        path = [code]
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct PickerView: View {
    let entries: [LanguageEntry]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Mimik").font(.system(size: 28, weight: .bold)).foregroundStyle(Palette.text)
                Text("Pick a language. Every phrase and clip is on the phone, so it works offline.")
                    .font(.system(size: 15)).foregroundStyle(Palette.muted).padding(.bottom, 10)
                if entries.isEmpty {
                    Text("No languages are bundled. Run scripts/bundle_ios.py before building.")
                        .foregroundStyle(Palette.muted)
                }
                ForEach(entries) { e in
                    Button { onSelect(e.code) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(e.native).font(.system(size: 24, weight: .bold)).foregroundStyle(Palette.text)
                            Spacer()
                            Text(e.name).font(.system(size: 15)).foregroundStyle(Palette.muted)
                        }
                        .padding(16)
                        .padding(.leading, 6)
                        .background(Palette.card)
                        .overlay(alignment: .leading) { Rectangle().fill(Color(UIColor(hex: e.color))).frame(width: 6) }
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.bg.ignoresSafeArea())
        .tint(LanguageTheme.picker.accent)
    }
}
