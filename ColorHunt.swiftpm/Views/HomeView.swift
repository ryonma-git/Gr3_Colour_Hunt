import SwiftUI

/// 最初の画面。ボタンは2つだけ。
struct HomeView: View {
    @EnvironmentObject private var storage: StorageService

    let onStart: () -> Void
    let onOpenGallery: () -> Void
    let onOpenFolderSetup: () -> Void

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 8)

                VStack(spacing: 10) {
                    Text("COLOR HUNT")
                        .font(Theme.display(76))
                        .foregroundColor(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    Text("What colour is it?")
                        .font(Theme.label(28))
                        .foregroundColor(Theme.subtle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 20) {
                    Button("START") {
                        Feedback.tap()
                        onStart()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityHint("いろさがしを はじめます")

                    Button("MY COLORS") {
                        onOpenGallery()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityHint("とった しゃしんを みます")
                }
                .padding(.horizontal, 28)

                Spacer()

                storageFooter
                    .padding(.bottom, 8)
            }
            .padding(.vertical, 20)
        }
    }

    /// 先生向けの小さな案内。児童の操作のじゃまにならない大きさにしてある。
    private var storageFooter: some View {
        Button(action: onOpenFolderSetup) {
            HStack(spacing: 6) {
                Image(systemName: storage.needsFolderSelection ? "exclamationmark.circle" : "folder")
                Text("ほぞんさき: " + storage.locationDescription)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(storage.needsFolderSelection ? Theme.accent : Theme.subtle)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .accessibilityLabel("ほぞんさきの せってい")
    }
}
