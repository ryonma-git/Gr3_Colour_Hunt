import SwiftUI

/// 画面の行き来をまとめる。大きなNavigation構造は作らず、
/// 画面の切りかえと2つのシートだけにしている。
///
/// SOLO HUNT と TEAM HUNT は、はじめる前の画面（SetupView）・さがす画面（HuntView）・
/// けっか画面（ResultView）を共有する。ちがうのは、
///   - TEAM は色が固定（班の担当色）で、写真ごとに色を変えない
///   - SOLO は難易度（いろの かず）をえらび、1枚ごとに色が変わる
/// という2点だけ。時計と Found count は、どちらのモードにもある。
struct RootView: View {
    enum Screen {
        case home
        case teamSelect
        /// はじめる前（SOLO / TEAM 共通）。START を押すまで何も始まらない。
        case setup
        /// SOLO / TEAM 共通のさがす画面
        case hunt
        /// おわったあとのけっか（SOLO / TEAM 共通）
        case result
    }

    @EnvironmentObject private var storage: StorageService
    @EnvironmentObject private var camera: CameraService
    @EnvironmentObject private var detector: ColorDetectionService
    @EnvironmentObject private var hunt: HuntRunService

    @Environment(\.scenePhase) private var scenePhase

    @State private var screen: Screen = .home
    @State private var showGallery = false
    @State private var showFolderSetup = false
    @State private var didBootstrap = false
    @State private var setupMode: HuntMode = .solo
    @State private var pendingTeamNumber: Int?
    @State private var savedFlashImage: UIImage?
    @State private var saveFailed = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            content

            // 撮ったら確認画面は出さず、一瞬だけ知らせてすぐ探索へ戻る
            if let image = savedFlashImage {
                savedFlash(image)
            }
        }
        .preferredColorScheme(.light)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .sheet(isPresented: $showGallery) {
            GalleryView(onClose: { showGallery = false })
                .preferredColorScheme(.light)
        }
        .sheet(isPresented: $showFolderSetup) {
            FolderSetupView(onClose: { showFolderSetup = false })
                .preferredColorScheme(.light)
        }
        .onAppear(perform: bootstrap)
        .onValueChange(of: camera.capturedPhoto != nil) { hasPhoto in
            if hasPhoto && screen == .hunt, let photo = camera.capturedPhoto {
                autoSave(photo)
            }
        }
        .onValueChange(of: hunt.isTimeUp) { timeUp in
            handleTimeUp(timeUp)
        }
        .onValueChange(of: scenePhase) { phase in
            handleScenePhase(phase)
        }
    }

    // MARK: - 画面

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .home:
            HomeView(onStartSolo: { openSetup(.solo, teamNumber: nil) },
                     onStartTeam: { screen = .teamSelect },
                     onOpenGallery: { showGallery = true },
                     onOpenFolderSetup: { showFolderSetup = true })

        case .teamSelect:
            TeamSelectView(onSelect: { number in openSetup(.team, teamNumber: number) },
                           onBack: { screen = .home })

        case .setup:
            setupContent

        case .hunt:
            HuntView(onClose: leaveHunt,
                     onOpenGallery: { showGallery = true },
                     onFinish: finishRun)

        case .result:
            resultContent
        }
    }

    @ViewBuilder
    private var setupContent: some View {
        if setupMode == .team {
            // 色は開始前の画面には出さない。START のとき判定へ渡すためにだけ取り出す。
            if let number = pendingTeamNumber,
               let profile = TeamHuntConfiguration.profile(for: number) {
                SetupView(mode: .team,
                          teamNumber: number,
                          onStart: { _, minutes in
                              startRun(mode: .team,
                                       teamNumber: number,
                                       profile: profile,
                                       level: nil,
                                       minutes: minutes)
                          },
                          onBack: { screen = .teamSelect })
            } else {
                // 対応表に無い番号だったときの逃げ道（ふつうは起きない）
                Color.clear.onAppear { screen = .teamSelect }
            }
        } else {
            SetupView(mode: .solo,
                      onStart: { level, minutes in
                          startRun(mode: .solo,
                                   teamNumber: nil,
                                   profile: nil,
                                   level: level,
                                   minutes: minutes)
                      },
                      onBack: { screen = .home })
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        if let current = hunt.run {
            ResultView(run: current, onHome: leaveResult)
        } else {
            Color.clear.onAppear { screen = .home }
        }
    }

    // MARK: - 起動時

    private func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true

        // カメラが測った色を判定へ流す
        camera.onSample = { [detector] hsv in
            detector.ingest(hsv)
        }

        storage.bootstrap()
        // 初回のフォルダ選択は自動では出さない（児童が迷うため）。
        // 保存先は先生がホーム下の小さな「ほぞんさき」から選ぶ。
    }

    // MARK: - はじめる前 → START

    private func openSetup(_ mode: HuntMode, teamNumber: Int?) {
        hunt.clear()
        camera.clearCapturedPhoto()
        detector.reset()
        setupMode = mode
        pendingTeamNumber = teamNumber
        screen = .setup
    }

    /// START を押したとき。ここで初めてカメラと時計が動き出す。
    private func startRun(mode: HuntMode,
                          teamNumber: Int?,
                          profile: ColorProfile?,
                          level: HuntDifficulty?,
                          minutes: Int) {
        camera.clearCapturedPhoto()
        hunt.start(HuntRun(mode: mode,
                           teamNumber: teamNumber,
                           profile: profile,
                           level: level,
                           limitSeconds: Double(minutes) * 60))

        if mode == .team, let teamColor = profile {
            // 班の担当色をそのまま既存の判定へ渡す。判定処理は SOLO と同じもの。
            detector.activeProfile = teamColor
            detector.reset()
        } else {
            detector.difficulty = level ?? .easy
            detector.pickNextColor()
        }
        screen = .hunt
    }

    // MARK: - おわる

    /// FINISH（TEAM）・×（SOLO）・TIME'S UP。写真は消さない。
    private func finishRun() {
        camera.stop()
        camera.clearCapturedPhoto()
        detector.reset()
        hunt.finish()
        screen = .result
    }

    private func leaveResult() {
        hunt.clear()
        screen = .home
    }

    /// カメラが使えないときだけ。けっかを出さずにホームへ戻る。
    private func leaveHunt() {
        camera.stop()
        camera.clearCapturedPhoto()
        detector.reset()
        hunt.clear()
        screen = .home
    }

    /// 時間切れ。保存の途中なら中断しない（データを壊さないため）。
    private func handleTimeUp(_ timeUp: Bool) {
        guard timeUp, hunt.isActive else { return }
        guard screen == .hunt else { return }
        // TIME'S UP! を少し見せてから結果へ
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if screen == .hunt && hunt.isActive {
                finishRun()
            }
        }
    }

    // MARK: - 撮影 → 自動保存（SOLO / TEAM 共通）

    private func autoSave(_ photo: CapturedPhoto) {
        detector.pause()
        guard let current = hunt.run else {
            camera.clearCapturedPhoto()
            return
        }

        if let capture = storage.save(photo: photo,
                                      profile: detector.activeProfile,
                                      hsv: detector.foundHSV ?? HSVColor.zero,
                                      mode: current.mode,
                                      teamNumber: current.teamNumber,
                                      sessionID: current.id,
                                      sessionStartedAt: current.startedAt,
                                      level: current.levelID,
                                      limitSeconds: current.limitSeconds) {
            // Found count が増えるのは、ここ（保存できたとき）だけ
            hunt.record(capture)
            saveFailed = false
            Feedback.tap()
        } else {
            saveFailed = true
        }
        savedFlashImage = photo.image
        camera.clearCapturedPhoto()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            savedFlashImage = nil
            continueAfterSave()
        }
    }

    private func continueAfterSave() {
        guard screen == .hunt else { return }
        if hunt.isTimeUp {
            finishRun()
            return
        }
        if hunt.isTeam {
            detector.reset()         // 同じ色を、もう一度さがす
            detector.resume()
        } else {
            detector.pickNextColor() // SOLO は次の色へ（3・2・1 と読み上げが入る）
            detector.resume()
        }
    }

    private func savedFlash(_ image: UIImage) -> some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 520, maxHeight: 520)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white, lineWidth: 4))
                Text(saveFailed ? "ほぞん できませんでした" : "✓ ほぞんしました")
                    .font(Theme.display(34))
                    .foregroundColor(saveFailed ? Theme.accent : .white)
            }
            .padding(24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(saveFailed ? "ほぞん できませんでした" : "ほぞんしました")
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if screen == .hunt {
                camera.refreshAuthorization()
                if camera.authorization == .authorized {
                    camera.start()
                }
            }
        case .background:
            camera.stop()
        default:
            break
        }
    }
}
