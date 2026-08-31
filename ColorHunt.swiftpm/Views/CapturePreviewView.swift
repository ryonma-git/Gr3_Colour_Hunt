import SwiftUI

/// 撮ったあとの確認画面。
/// 「この しゃしんに する」を押したときにはじめて正式保存する。
struct CapturePreviewView: View {
    @EnvironmentObject private var storage: StorageService
    @EnvironmentObject private var detector: ColorDetectionService

    let photo: CapturedPhoto
    let onRetake: () -> Void
    let onFinish: () -> Void

    @State private var savedCapture: ColorCapture?
    @State private var shareItem: ShareItem?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Text(detector.activeProfile.displayName)
                    .font(Theme.display(52))
                    .foregroundColor(.white)
                    .padding(.top, 10)

                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)
                    .padding(.horizontal, 16)

                if let message = errorMessage {
                    Text(message)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Theme.accent))
                }

                if savedCapture == nil {
                    reviewButtons
                } else {
                    savedButtons
                }
            }
            .padding(.bottom, 22)
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
    }

    // MARK: - 保存する前

    private var reviewButtons: some View {
        VStack(spacing: 14) {
            Button("この しゃしんに する") {
                save()
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("とりなおす") {
                onRetake()
            }
            .buttonStyle(SecondaryButtonStyle(tint: .white))
        }
        .padding(.horizontal, 28)
    }

    // MARK: - 保存したあと

    private var savedButtons: some View {
        VStack(spacing: 14) {
            Label("ほぞんしました", systemImage: "checkmark.circle.fill")
                .font(Theme.label(20))
                .foregroundColor(Theme.success)

            Button("ロイロノートに おくる") {
                share()
            }
            .buttonStyle(PrimaryButtonStyle(fill: Theme.success))

            Button("つぎを さがす") {
                onFinish()
            }
            .buttonStyle(SecondaryButtonStyle(tint: .white))
        }
        .padding(.horizontal, 28)
    }

    // MARK: - 動作

    private func save() {
        let profile = detector.activeProfile
        let hsv = detector.foundHSV ?? HSVColor.zero
        if let capture = storage.save(photo: photo, profile: profile, hsv: hsv) {
            savedCapture = capture
            errorMessage = nil
            Feedback.tap()
        } else {
            errorMessage = storage.lastErrorMessage ?? "ほぞんできませんでした。"
        }
    }

    private func share() {
        guard let capture = savedCapture else { return }
        let url = ShareService.makeShareURL(for: capture,
                                            imageURL: storage.imageURL(for: capture),
                                            profile: ColorProfile.profile(id: capture.targetColor))
        shareItem = ShareItem(url: url)
    }
}
