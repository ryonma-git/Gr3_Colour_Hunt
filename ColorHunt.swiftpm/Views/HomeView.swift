import SwiftUI

/// 最初の画面。ボタンは2つだけ。
struct HomeView: View {
    @EnvironmentObject private var storage: StorageService

    let onStartSolo: () -> Void
    let onStartTeam: () -> Void
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

                VStack(spacing: 18) {
                    // ひとりで さがす（これまでの START と同じ）
                    Button {
                        Feedback.tap()
                        onStartSolo()
                    } label: {
                        modeLabel(title: "SOLO HUNT",
                                  subtitle: "ひとりで さがす",
                                  icon: "person.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityLabel("ソロハント")
                    .accessibilityHint("ひとりで いろさがしを はじめます")

                    // はんで さがす
                    Button {
                        Feedback.tap()
                        onStartTeam()
                    } label: {
                        modeLabel(title: "TEAM HUNT",
                                  subtitle: "はんで さがす・5ふん",
                                  icon: "person.3.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle(fill: Theme.ink))
                    .accessibilityLabel("チームハント")
                    .accessibilityHint("はんで 5ふんかん いろさがしを します")

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

    /// アイコンだけに頼らず、英語の名前と短い日本語をならべる
    private func modeLabel(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .bold))
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                Text(subtitle)
                    .font(Theme.label(15))
                    .opacity(0.85)
            }
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
