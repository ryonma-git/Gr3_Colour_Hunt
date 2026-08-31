import SwiftUI
import UIKit

/// さがす画面。いちばん大事なのは
/// 上の「RED」・まん中のターゲット・下のシャッターの3つ。
struct HuntView: View {
    @EnvironmentObject private var camera: CameraService
    @EnvironmentObject private var detector: ColorDetectionService
    @EnvironmentObject private var speech: SpeechService

    let onClose: () -> Void
    let onOpenGallery: () -> Void

    @State private var countdown: Int?
    @State private var interfaceOrientation: UIInterfaceOrientation = .portrait

    private let ringSize: CGFloat = 230

    var body: some View {
        ZStack {
            cameraLayer

            if camera.authorization == .denied {
                permissionLayer
            } else {
                reticleLayer
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                controlsLayer
            }

            if let value = countdown {
                countdownLayer(value)
            }

            debugLayer
        }
        // 色が変わるたびにカウントダウンをやり直し、あたらしい色を大きく知らせる
        .task(id: detector.activeProfile.id) {
            await runCountdown()
        }
        .onAppear {
            camera.start()
        }
        .onDisappear {
            detector.pause()
        }
        .onValueChange(of: detector.phase) { phase in
            if phase == .found {
                Feedback.success()
            }
        }
    }

    // MARK: - カメラ

    private var cameraLayer: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if camera.authorization == .authorized {
                CameraPreview(session: camera.session) { orientation in
                    interfaceOrientation = orientation
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - まん中のターゲット

    private var reticleColor: Color {
        if detector.phase == .found { return Theme.success }
        return detector.isMatchingNow ? Theme.matching : .white
    }

    private var reticleLayer: some View {
        ZStack {
            // 大きな円
            Circle()
                .stroke(reticleColor, lineWidth: detector.phase == .found ? 12 : 7)
                .frame(width: ringSize, height: ringSize)
                .shadow(color: .black.opacity(0.45), radius: 5)

            // まん中の小さな点（ここの色を見ている）
            Circle()
                .fill(reticleColor)
                .frame(width: 16, height: 16)
                .shadow(color: .black.opacity(0.45), radius: 3)

            if detector.phase == .found {
                foundBadge
                    .offset(y: -(ringSize / 2 + 62))
                foundMessage
                    .offset(y: ringSize / 2 + 58)
            }
        }
        .animation(.easeOut(duration: 0.18), value: detector.isMatchingNow)
        .animation(.easeOut(duration: 0.18), value: detector.phase)
        .allowsHitTesting(false)
    }

    private var foundBadge: some View {
        ZStack {
            Circle()
                .fill(Theme.success)
                .frame(width: 84, height: 84)
            Image(systemName: "checkmark")
                .font(.system(size: 44, weight: .black))
                .foregroundColor(.white)
        }
        .shadow(color: .black.opacity(0.35), radius: 6)
        .accessibilityHidden(true)
    }

    private var foundMessage: some View {
        Text("You found " + detector.activeProfile.displayName + "!")
            .font(Theme.label(30))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Capsule().fill(Theme.success.opacity(0.92)))
            .shadow(color: .black.opacity(0.3), radius: 4)
    }

    // MARK: - 上と下のボタン

    private var controlsLayer: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                closeButton
                Spacer()
                galleryButton
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            targetColorButton
                .padding(.top, 6)

            Spacer()

            if let message = camera.problemMessage {
                problemBanner(message)
                    .padding(.bottom, 10)
            }

            statusLine
                .padding(.bottom, 14)

            shutterButton
                .padding(.bottom, 22)
        }
    }

    /// タップすると英語で読み上げる
    private var targetColorButton: some View {
        Button {
            speech.speak(detector.activeProfile.speechText)
        } label: {
            HStack(spacing: 16) {
                Text(detector.activeProfile.displayName)
                    .font(Theme.display(80))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.black.opacity(0.45)))
        }
        .accessibilityLabel(detector.activeProfile.displayName)
        .accessibilityHint("タップすると えいごで よみます")
    }

    private var closeButton: some View {
        Button {
            onClose()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Color.black.opacity(0.45)))
        }
        .accessibilityLabel("ホームに もどる")
    }

    private var galleryButton: some View {
        Button {
            onOpenGallery()
        } label: {
            Text("MY COLORS")
                .font(Theme.label(18))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(Capsule().fill(Color.black.opacity(0.45)))
        }
        .accessibilityLabel("とった しゃしんを みる")
    }

    private var statusLine: some View {
        Group {
            if detector.phase == .found {
                Text("しゃしんを とろう")
            } else {
                Text("まん中に あわせてね")
            }
        }
        .font(Theme.label(20))
        .foregroundColor(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.black.opacity(0.35)))
    }

    private var canCapture: Bool {
        detector.phase == .found && !camera.isCapturingPhoto && camera.isSessionRunning
    }

    private var shutterButton: some View {
        Button {
            camera.capturePhoto(interfaceOrientation: interfaceOrientation)
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 6)
                    .frame(width: 96, height: 96)
                Circle()
                    .fill(Color.white)
                    .frame(width: 78, height: 78)
            }
        }
        .disabled(!canCapture)
        .opacity(canCapture ? 1 : 0.35)
        .animation(.easeOut(duration: 0.2), value: canCapture)
        .accessibilityLabel("しゃしんを とる")
    }

    private func problemBanner(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Capsule().fill(Theme.accent.opacity(0.9)))
            .padding(.horizontal, 24)
    }

    // MARK: - 3 2 1

    private func countdownLayer(_ value: Int) -> some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 0) {
                // これからさがす色を、カウントダウン中も大きく見せる
                Text(detector.activeProfile.displayName)
                    .font(Theme.display(96))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.horizontal, 24)
                Text("\(value)")
                    .font(.system(size: 165, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .id(value)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: value)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(detector.activeProfile.displayName + " " + String(value))
    }

    private func runCountdown() async {
        detector.pause()
        for value in [3, 2, 1] {
            countdown = value
            Feedback.tap()
            try? await Task.sleep(nanoseconds: 700_000_000)
            if Task.isCancelled { return }
        }
        countdown = nil
        detector.resume()
    }

    // MARK: - カメラが使えないとき

    private var permissionLayer: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 26) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 64))
                    .foregroundColor(Theme.subtle)
                Text("カメラを つかうために\nきょかが ひつようです")
                    .font(Theme.label(28))
                    .foregroundColor(Theme.ink)
                    .multilineTextAlignment(.center)
                Text("「せってい」→「Color Hunt」→「カメラ」を\nオンにしてください。")
                    .font(.system(size: 17))
                    .foregroundColor(Theme.subtle)
                    .multilineTextAlignment(.center)

                Button("せっていを ひらく") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("ホームに もどる") {
                    onClose()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.horizontal, 30)
        }
    }

    // MARK: - 先生用のかくれた表示

    /// 左下すみを1.5秒ながおしすると、HSV の数値が出る。
    /// 児童のふつうの操作では出ない。README「RED判定値の調整場所」参照。
    private var debugLayer: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    if detector.isDebugEnabled {
                        Text(debugText)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.6)))
                    }
                    Color.clear
                        .frame(width: 64, height: 64)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 1.5) {
                            detector.isDebugEnabled.toggle()
                            Feedback.tap()
                        }
                }
                Spacer()
            }
            .padding(.leading, 6)
        }
    }

    private var debugText: String {
        guard let hsv = detector.debugHSV else { return "no sample" }
        let matched = detector.activeProfile.matches(hsv)
        return hsv.debugDescription + "\nmatched: \(matched)"
    }
}
