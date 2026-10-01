import SwiftUI

/// RESULT の写真を大きく見る画面。発表のときに使う。
/// 左右スワイプで前後の写真へ移動できる。
///
/// 「これは何？」「いくつ？」は教師と児童が教室で話す。
/// アプリは写真と色名だけを見せて、答えを言ってしまわない。
struct TeamPhotoViewerView: View {
    @EnvironmentObject private var storage: StorageService

    let captures: [ColorCapture]
    /// TEAM は班の担当色。SOLO は写真ごとに色がちがうので nil を渡す。
    let profile: ColorProfile?
    let startIndex: Int
    let onClose: () -> Void

    @State private var index: Int = 0
    @State private var shareItem: ShareItem?

    /// いま見ている写真の色（SOLO は1枚ごとに変わる）
    private var currentProfile: ColorProfile? {
        if let profile = profile { return profile }
        guard index >= 0, index < captures.count else { return nil }
        return ColorProfile.profile(id: captures[index].targetColor)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 10) {
                HStack {
                    Button(action: onClose) {
                        Label("もどる", systemImage: "chevron.left")
                            .font(Theme.label(20))
                            .foregroundColor(Theme.subtle)
                            .padding(.vertical, 10)
                            .padding(.trailing, 12)
                    }
                    .accessibilityLabel("いちらんに もどる")
                    Spacer()
                    // 共有は主役にしない。小さく置くだけ。
                    Button(action: share) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Theme.subtle)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("この しゃしんを ロイロノートに おくる")
                }
                .padding(.horizontal, 20)

                if let shown = currentProfile {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(shown.displayColor)
                            .frame(width: 28, height: 28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Theme.ink.opacity(0.18), lineWidth: 2)
                            )
                        Text(shown.displayName)
                            .font(Theme.display(46))
                            .foregroundColor(shown.readableColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }

                TabView(selection: $index) {
                    ForEach(Array(captures.enumerated()), id: \.element.id) { pair in
                        ThumbnailImage(url: storage.imageURL(for: pair.element),
                                       maxPixel: 1600,
                                       fillsFrame: false)
                            .padding(.horizontal, 14)
                            .tag(pair.offset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Text("\(index + 1) / \(captures.count)")
                    .font(Theme.display(30))
                    .foregroundColor(Theme.ink)
                    .padding(.bottom, 14)
                    .accessibilityLabel("\(captures.count)まいちゅう \(index + 1)まいめ")
            }
            .padding(.vertical, 12)
        }
        .onAppear {
            index = min(max(0, startIndex), max(0, captures.count - 1))
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
    }

    private func share() {
        guard index >= 0, index < captures.count else { return }
        let capture = captures[index]
        let shown = ColorProfile.profile(id: capture.targetColor) ?? profile ?? .red
        let url = ShareService.makeShareURL(for: capture,
                                            imageURL: storage.imageURL(for: capture),
                                            profile: shown)
        shareItem = ShareItem(url: url)
    }
}
