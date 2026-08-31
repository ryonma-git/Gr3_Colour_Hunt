import SwiftUI

/// 1枚を大きく見る画面。ここからロイロノートへ送る／けす。
struct GalleryDetailView: View {
    @EnvironmentObject private var storage: StorageService
    @Environment(\.dismiss) private var dismiss

    let capture: ColorCapture

    @State private var shareItem: ShareItem?
    @State private var showDeleteConfirmation = false

    private var profile: ColorProfile? {
        ColorProfile.profile(id: capture.targetColor)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 14) {
                Text(capture.displayName)
                    .font(Theme.display(48))
                    .foregroundColor(profile?.displayColor ?? Theme.ink)

                ThumbnailImage(url: storage.imageURL(for: capture),
                               maxPixel: 1400,
                               fillsFrame: false)
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)
                    .padding(.horizontal, 16)

                Text(capture.capturedAtText)
                    .font(.system(size: 16))
                    .foregroundColor(Theme.subtle)

                VStack(spacing: 12) {
                    Button("ロイロノートに おくる") {
                        share()
                    }
                    .buttonStyle(PrimaryButtonStyle(fill: Theme.success))

                    Button("けす") {
                        showDeleteConfirmation = true
                    }
                    .font(Theme.label(20))
                    .foregroundColor(Theme.accent)
                    .padding(.top, 2)
                }
                .padding(.horizontal, 28)
            }
            .padding(.vertical, 18)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .confirmationDialog("この しゃしんを けしますか？",
                            isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible) {
            Button("けす", role: .destructive) {
                storage.delete(capture)
                dismiss()
            }
            Button("やめる", role: .cancel) {}
        } message: {
            Text("けすと、もとに もどせません。")
        }
    }

    private func share() {
        let url = ShareService.makeShareURL(for: capture,
                                            imageURL: storage.imageURL(for: capture),
                                            profile: profile)
        shareItem = ShareItem(url: url)
    }
}
