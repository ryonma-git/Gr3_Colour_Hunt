import SwiftUI

/// おわったときの結果画面（SOLO / TEAM 共通）。
///
/// TEAM のときは Apple Classroom で教師機にミラーリングし、
/// 教室前方の大画面に映すことを前提にしている。
/// だから「見つけた数」を最も大きく、次に色、次に班番号の順で見せる。
///
/// SOLO のときは色がまざるので、写真ごとに色の名前を下に出す。
///
/// 点数・順位はここでは出さない。撮った枚数という事実だけを見せ、
/// 得点は教師が黒板の上で決める。
struct ResultView: View {
    @EnvironmentObject private var storage: StorageService

    let run: HuntRun
    let onHome: () -> Void

    @State private var viewerIndex: Int?

    /// 写真は大きめにする。発表のとき1枚ずつが見えることを優先し、
    /// 入りきらないぶんはスクロールで見せる。
    private let columns = [GridItem(.adaptive(minimum: 230), spacing: 14)]

    private var captures: [ColorCapture] {
        storage.captures(withIDs: run.captureIDs)
    }

    private var isTeam: Bool { run.mode == .team }

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
                                profile: isTeam ? run.profile : nil,
                                startIndex: box.value,
                                onClose: { viewerIndex = nil })
                .preferredColorScheme(.light)
        }
    }

    // MARK: - 上（教室後方からでも読める大きさ）

    private var header: some View {
        VStack(spacing: 2) {
            Text(isTeam ? "TEAM \(run.teamNumber ?? 0)" : "SOLO HUNT")
                .font(Theme.display(44))
                .foregroundColor(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if isTeam, let profile = run.profile {
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
            }

            Text(subtitle)
                .font(Theme.label(20))
                .foregroundColor(Theme.subtle)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

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
        .accessibilityLabel(accessibilitySummary)
    }

    /// 「かんたん（7いろ）・3ふん」／ TEAM は「5ふん」だけ
    private var subtitle: String {
        let time = HuntTimeOptions.label(seconds: run.limitSeconds)
        if isTeam { return time }
        let level = run.level ?? .easy
        return level.labelWithCount + "・" + time
    }

    private var accessibilitySummary: String {
        if isTeam {
            let name = run.profile?.displayName ?? ""
            return "チーム \(run.teamNumber ?? 0)、\(name)、\(captures.count)こ みつけました"
        }
        return "ソロハント、\(captures.count)こ みつけました"
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
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Array(captures.enumerated()), id: \.element.id) { pair in
                        Button {
                            viewerIndex = pair.offset
                        } label: {
                            photoCell(pair.element)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(pair.offset + 1)まいめ・\(pair.element.displayName)")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 12)
            }
        }
    }

    /// SOLO は色がまざるので、写真の下に色の名前を出す
    private func photoCell(_ capture: ColorCapture) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(ThumbnailImage(url: storage.imageURL(for: capture), maxPixel: 700))
            .overlay(alignment: .bottom) {
                if !isTeam {
                    Text(capture.displayName)
                        .font(Theme.label(15))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.52))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
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
