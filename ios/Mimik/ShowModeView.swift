import SwiftUI
import UIKit

struct ShowItem: Identifiable {
    let id = UUID()
    let en: String
    let text: String
}

/// Show mode (Feature 2): the phrase alone, as large as fits, with the screen kept awake, for
/// turning the phone toward a waiter or clerk. A tap or swipe closes it.
struct ShowModeView: View {
    let item: ShowItem

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text(item.en).font(.system(size: 15)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            GeometryReader { geo in
                Text(item.text)
                    .font(.system(size: ShowFit.size(item.text, in: geo.size), weight: .bold))
                    .foregroundStyle(Palette.text)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            Text("Tap or swipe to close").font(.system(size: 13)).foregroundStyle(Palette.muted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.card.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .gesture(DragGesture(minimumDistance: 30).onEnded { _ in dismiss() })
        .accessibilityAction(.escape) { dismiss() }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .statusBarHidden()
    }
}

/// The largest font size at which the text fits without splitting a word, as fitShow() on the web.
/// Scripts written without spaces (Japanese) may break anywhere, so only their height is checked.
enum ShowFit {
    static func size(_ text: String, in area: CGSize) -> CGFloat {
        guard area.width > 0, area.height > 0 else { return 16 }
        let breaksAnywhere = text.unicodeScalars.contains { (0x3040...0x9FFF).contains($0.value) }
        let words = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        var lo: CGFloat = 16, hi = min(area.height, 320)
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: mid, weight: .bold)]
            let widest = breaksAnywhere ? 0 : words.map { ($0 as NSString).size(withAttributes: attrs).width }.max() ?? 0
            let height = (text as NSString).boundingRect(
                with: CGSize(width: area.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil).height
            if widest <= area.width && ceil(height) <= area.height { lo = mid } else { hi = mid }
        }
        return lo
    }
}
