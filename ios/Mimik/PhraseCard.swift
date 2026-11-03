import MimikCore
import SwiftUI

/// A phrase card: English, the phrase, romanization, phonetics and note, with play and slow
/// buttons; regional rows below it; and "What you'll hear" replies, collapsed. Tapping the text
/// of the phrase or of a regional row opens show mode.
struct PhraseCard: View {
    /// Already formed for the He / She setting.
    let phrase: Phrase
    let theme: LanguageTheme
    let onShow: (ShowItem) -> Void

    @State private var repliesOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(phrase.en).font(.system(size: 16)).foregroundStyle(Palette.muted)
                    PhraseLines(text: phrase.text, rom: phrase.rom, ph: phrase.ph, theme: theme, size: 30)
                    if let note = phrase.note {
                        Text(note).font(.system(size: 15)).foregroundStyle(Palette.muted).padding(.top, 6)
                    }
                }
                .showable { onShow(ShowItem(en: phrase.en, text: phrase.text)) }
                PlayButtons(utterance: Utterance(phrase), size: 58, theme: theme)
            }
            ForEach(phrase.alt) { a in
                Divider().overlay(Palette.line).padding(.vertical, 12)
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.tag)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 6).fill(theme.tag))
                        PhraseLines(text: a.text, rom: a.rom, ph: a.ph, theme: theme, size: 22)
                    }
                    .showable { onShow(ShowItem(en: "\(phrase.en) (\(a.tag))", text: a.text)) }
                    PlayButtons(utterance: Utterance(a, phrase: phrase), size: 46, theme: theme)
                }
            }
            if !phrase.replies.isEmpty {
                Divider().overlay(Palette.line).padding(.top, 12)
                DisclosureGroup(isExpanded: $repliesOpen) {
                    ForEach(phrase.replies) { r in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.text).font(.system(size: 20, weight: .bold)).foregroundStyle(Palette.text)
                                if let rom = r.rom { Text(rom).font(.system(size: 17)).foregroundStyle(Palette.text) }
                                Text(r.en).font(.system(size: 15)).foregroundStyle(Palette.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            PlayButtons(utterance: Utterance(r), size: 40, theme: theme)
                        }
                        .padding(.top, 10)
                    }
                } label: {
                    Text("What you'll hear").font(.system(size: 14)).foregroundStyle(Palette.muted)
                }
                .padding(.top, 6)
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 14))
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line))
    }
}

/// The phrase, its romanization where the script needs one (Japanese), and its phonetics.
struct PhraseLines: View {
    let text: String
    let rom: String?
    let ph: String
    let theme: LanguageTheme
    let size: CGFloat

    var body: some View {
        Text(text).font(.system(size: size, weight: .bold)).foregroundStyle(Palette.text)
        if let rom { Text(rom).font(.system(size: 17)).foregroundStyle(Palette.text) }
        Text(nonBreaking(ph)).font(.system(size: size > 24 ? 19 : 17)).foregroundStyle(theme.accent)
    }
}

struct PlayButtons: View {
    let utterance: Utterance
    let size: CGFloat
    let theme: LanguageTheme

    @EnvironmentObject private var speaker: Speaker

    var body: some View {
        VStack(spacing: 6) {
            Button { speaker.play(utterance, slow: false) } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: size * 0.36))
                    .foregroundStyle(theme.accentInk)
                    .frame(width: size, height: size)
                    .background(Circle().fill(theme.accent))
                    .opacity(speaker.active == PlayingKey(id: utterance.id, slow: false) ? 0.55 : 1)
            }
            .accessibilityLabel("Play: \(utterance.text)")
            Button("slow") { speaker.play(utterance, slow: true) }
                .font(.system(size: 13))
                .foregroundStyle(speaker.active == PlayingKey(id: utterance.id, slow: true) ? theme.accent : Palette.muted)
                .frame(minHeight: 28)
                .accessibilityLabel("Play slowly: \(utterance.text)")
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// The text side of a row opens show mode; the play buttons sit beside it.
    func showable(_ open: @escaping () -> Void) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: open)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Shows the phrase full screen")
    }
}
