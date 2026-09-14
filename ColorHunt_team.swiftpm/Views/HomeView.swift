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

                    Text("カメラを きかれたら「OK」を おしてね")
                        .font(Theme.label(16))
                        .foregroundColor(Theme.subtle)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 28)

                Spacer()

                Button("MY COLORS（とった しゃしん）") {
                    onOpenGallery()
                }
                .font(Theme.label(17))
                .foregroundColor(Theme.subtle)
                .padding(.bottom, 4)
                .accessibilityHint("とった しゃしんを みます")

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
            .font(.system(size: 13, weight: .medium))
            // 児童が不安にならないよう、赤にはしない（先生向けの小さな表示）
            .foregroundColor(Theme.subtle.opacity(0.8))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .accessibilityLabel("ほぞんさきの せってい")
    }
}
