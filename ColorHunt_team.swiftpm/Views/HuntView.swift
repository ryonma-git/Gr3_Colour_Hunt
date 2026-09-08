import SwiftUI
import UIKit

/// さがす画面。いちばん大事なのは
/// 上の「RED」・まん中のターゲット・下のシャッターの3つ。
struct HuntView: View {
    @EnvironmentObject private var camera: CameraService
    @EnvironmentObject private var detector: ColorDetectionService
    @EnvironmentObject private var speech: SpeechService
    /// TEAM HUNT のときだけ中身が入る。SOLO では isActive == false なので
    /// 下の分岐がすべて SOLO 側に倒れ、これまでの動きは変わらない。
    @EnvironmentObject private var teamHunt: TeamHuntService

    let onClose: () -> Void
    let onOpenGallery: () -> Void
    /// TEAM HUNT の FINISH を押したとき（SOLO では使わない）
    var onFinishTeamHunt: () -> Void = {}

    @State private var countdown: Int?
    @State private var interfaceOrientation: UIInterfaceOrientation = .portrait
    @State private var showFinishConfirm = false

    private var isTeam: Bool { teamHunt.isActive }

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

            if isTeam && teamHunt.isTimeUp {
                timesUpLayer
            }

            debugLayer
        }
        .confirmationDialog("Finish Team Hunt?",
                            isPresented: $showFinishConfirm,
                            titleVisibility: .visible) {
            Button("Finish", role: .destructive) { onFinishTeamHunt() }
            Button("Cancel", role: .cancel) {}
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
        // 保険: カウントダウンが終わったあとに班のセッションが有効になった場合でも
        // 時計が動き出すようにしておく（通常は runCountdown の最後で始まる）
        .onValueChange(of: teamHunt.isActive) { active in
            if active && countdown == nil {
                teamHunt.beginTiming()
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
                if isTeam {
                    finishButton
                } else {
                    closeButton
                }
                Spacer()
                if isTeam {
                    teamBadge
                } else {
                    galleryButton
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            targetColorButton
                .padding(.top, 6)

            if isTeam {
                teamStatusBar
                    .padding(.top, 10)
            }

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

    // MARK: - TEAM HUNT のときだけ出るもの

    /// あやまって押しにくいよう画面のすみに置き、確認をはさむ
    private var finishButton: some View {
        Button {
            showFinishConfirm = true
        } label: {
            Text("FINISH")
                .font(Theme.label(17))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Capsule().fill(Color.black.opacity(0.45)))
        }
        .accessibilityLabel("チームハントを おわる")
    }

    private var teamBadge: some View {
        Text("TEAM \(teamHunt.teamNumber ?? 0)")
            .font(Theme.label(17))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Capsule().fill(Color.black.opacity(0.45)))
            .accessibilityLabel("チーム \(teamHunt.teamNumber ?? 0)")
    }

    /// 残り時間と、みつけた数。時間のほうを大きくして優先度を示す。
    private var teamStatusBar: some View {
        HStack(spacing: 14) {
            HStack(spacing: 7) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 20, weight: .bold))
                Text(teamHunt.remainingText)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundColor(teamHunt.isWarning ? Theme.matching : .white)
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.black.opacity(0.45)))
            .accessibilityLabel("のこり " + teamHunt.remainingText)

            HStack(spacing: 7) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                Text("Found")
                    .font(Theme.label(17))
                Text("\(teamHunt.foundCount)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.black.opacity(0.45)))
            .accessibilityLabel("みつけた かず \(teamHunt.foundCount)")
        }
    }

    private var timesUpLayer: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("TIME'S UP!")
                    .font(Theme.display(64))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("Found \(teamHunt.foundCount)")
                    .font(Theme.display(40))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("じかんです。\(teamHunt.foundCount)こ みつけました")
    }

    // MARK: -

    private var canCapture: Bool {
        detector.phase == .found
            && !camera.isCapturingPhoto
            && camera.isSessionRunning
            && !(isTeam && teamHunt.isTimeUp)
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
        // あたらしい色になったら、まず英語で1回読み上げる（聞く → さがす）
        speech.speak(detector.activeProfile.speechText)
        for value in [3, 2, 1] {
            countdown = value
            Feedback.tap()
            try? await Task.sleep(nanoseconds: 700_000_000)
            if Task.isCancelled { return }
        }
        countdown = nil
        detector.resume()
        // 3・2・1 が終わってから5分を数え始める
        if isTeam {
            teamHunt.beginTiming()
        }
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
