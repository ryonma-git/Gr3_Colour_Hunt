import SwiftUI

/// TEAM HUNT の結果画面。
///
/// この画面は Apple Classroom で教師機にミラーリングし、
/// 教室前方の大画面に映すことを前提に作ってある。
/// だから「見つけた数」を最も大きく、次に色、次に班番号の順で見せる。
///
/// 点数・順位はここでは出さない。撮った枚数という事実だけを見せ、
/// 得点は教師が黒板の上で決める。
struct TeamResultView: View {
    @EnvironmentObject private var storage: StorageService

    let teamNumber: Int
    let profile: ColorProfile
    let captureIDs: [String]
    let onHome: () -> Void

    @State private var viewerIndex: Int?

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 10)]

    private var captures: [ColorCapture] {
        storage.captures(withIDs: captureIDs)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                photoGrid
                footer
            }
        }
        .fullScreenCover(item: Binding(
            get: { viewerIndex.map { IndexBox(value: $0) } },
            set: { viewerIndex = $0?.value }
        )) { box in
            TeamPhotoViewerView(captures: captures,
                                profile: profile,
                                startIndex: box.value,
                                onClose: { viewerIndex = nil })
                .preferredColorScheme(.light)
        }
    }

    // MARK: - 上（教室後方からでも読める大きさ）

    private var header: some View {
        VStack(spacing: 2) {
            Text("TEAM \(teamNumber)")
                .font(Theme.display(44))
                .foregroundColor(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(profile.displayColor)
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.ink.opacity(0.18), lineWidth: 2)
                    )
                Text(profile.displayName)
                    .font(Theme.display(62))
                    .foregroundColor(profile.readableColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
            }

            Text("\(captures.count)")
                .font(.system(size: 150, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.top, 2)

            Text("FOUND")
                .font(Theme.display(34))
                .foregroundColor(Theme.subtle)
                .padding(.top, -8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("チーム \(teamNumber)、\(profile.displayName)、\(captures.count)こ みつけました")
    }

    // MARK: - 写真

    private var photoGrid: some View {
        ScrollView {
            if captures.isEmpty {
                Text("しゃしんは ありません")
                    .font(Theme.label(20))
                    .foregroundColor(Theme.subtle)
                    .padding(.top, 40)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(captures.enumerated()), id: \.element.id) { pair in
                        Button {
                            viewerIndex = pair.offset
                        } label: {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(ThumbnailImage(url: storage.imageURL(for: pair.element)))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(pair.offset + 1)まいめの しゃしん")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }
        }
    }

    // MARK: - 下（誤って結果を消すボタンは置かない）

    private var footer: some View {
        Button("ホームに もどる") {
            onHome()
        }
        .buttonStyle(SecondaryButtonStyle())
        .padding(.horizontal, 28)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }
}

/// `fullScreenCover(item:)` に Int を渡すための入れもの
private struct IndexBox: Identifiable {
    let value: Int
    var id: Int { value }
}
