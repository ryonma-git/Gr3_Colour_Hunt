import SwiftUI

/// 班番号をえらんだあとの確認画面。
/// ここで自分たちの担当色を知る。色名はタップすると英語で読み上げる。
struct TeamReadyView: View {
    @EnvironmentObject private var speech: SpeechService

    let teamNumber: Int
    let profile: ColorProfile
    let onStart: () -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        Label("もどる", systemImage: "chevron.left")
                            .font(Theme.label(20))
                            .foregroundColor(Theme.subtle)
                            .padding(.vertical, 10)
                            .padding(.trailing, 12)
                    }
                    .accessibilityLabel("はんを えらびなおす")
                    Spacer()
                }
                .padding(.horizontal, 20)

                Spacer()

                Text("TEAM \(teamNumber)")
                    .font(Theme.display(52))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                // 色名。色だけで伝えないよう、色見本と文字の両方を出す。
                Button {
                    speech.speak(profile.speechText)
                } label: {
                    HStack(spacing: 18) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(profile.displayColor)
                            .frame(width: 56, height: 56)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Theme.ink.opacity(0.18), lineWidth: 2)
                            )
                        Text(profile.displayName)
                            .font(Theme.display(84))
                            .foregroundColor(profile.readableColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(Theme.subtle)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
                .accessibilityLabel(profile.displayName)
                .accessibilityHint("タップすると えいごで よみます")

                Text("この いろの ものを さがそう")
                    .font(Theme.label(20))
                    .foregroundColor(Theme.subtle)
                    .padding(.top, 8)

                Spacer()

                Button("START") {
                    Feedback.tap()
                    onStart()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 28)

                Text("5ふんかん さがします")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.subtle)
                    .padding(.top, 12)

                Spacer(minLength: 20)
            }
            .padding(.vertical, 18)
        }
    }
}
