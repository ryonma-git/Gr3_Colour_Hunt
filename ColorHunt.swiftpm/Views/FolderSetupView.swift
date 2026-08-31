import SwiftUI
import UniformTypeIdentifiers

/// 保存先をえらぶ画面。えらぶことは3つだけにしてある。
///
/// 1. フォルダを えらぶ        …「ファイル」アプリに Color Hunt/ を作る（おすすめ）
/// 2. ほぞん せず はじめる      … 決めずに授業を始める（写真はアプリの中に残る）
/// 3. まえの データを ひらく    … 前に使っていた Color Hunt フォルダを開き直す
struct FolderSetupView: View {
    @EnvironmentObject private var storage: StorageService

    let onClose: () -> Void

    @State private var isImporting = false
    @State private var message: String?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("しゃしんを どこに\nほぞんしますか？")
                    .font(Theme.label(28))
                    .foregroundColor(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 28)

                if let message = message {
                    Text(message)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent))
                        .padding(.top, 16)
                }

                Spacer(minLength: 12)

                // 1. おすすめ
                VStack(spacing: 8) {
                    Button("フォルダを えらぶ") {
                        isImporting = true
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Text("おすすめ:「このiPad内」→「Color Hunt」")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.subtle)
                }

                // 2. 決めずに始める
                secondChoice
                    .padding(.top, 30)

                Spacer()

                // 3. 復元（先生向けなので小さく）
                Button("まえの データを ひらく") {
                    isImporting = true
                }
                .font(Theme.label(18))
                .foregroundColor(Theme.subtle)

                Text("いまの ほぞんさき: " + storage.locationDescription)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.subtle)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .padding(.bottom, 22)
            }
            .padding(.horizontal, 28)
        }
        .fileImporter(isPresented: $isImporting,
                      allowedContentTypes: [.folder],
                      allowsMultipleSelection: false) { result in
            handle(result)
        }
    }

    @ViewBuilder
    private var secondChoice: some View {
        if storage.isUsingExternalFolder {
            Button("とじる") {
                onClose()
            }
            .buttonStyle(SecondaryButtonStyle())
        } else {
            VStack(spacing: 8) {
                Button("ほぞん せず はじめる") {
                    storage.startWithoutFolder()
                    onClose()
                }
                .buttonStyle(SecondaryButtonStyle())

                Text("しゃしんは アプリの中に のこります。\nアプリを つくりなおすと きえます。")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.subtle)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func handle(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            if storage.adoptFolder(url) {
                onClose()
            } else {
                message = storage.lastErrorMessage ?? "そのフォルダは つかえませんでした。"
            }
        case .failure:
            message = "フォルダを えらべませんでした。もういちど ためしてください。"
        }
    }
}
