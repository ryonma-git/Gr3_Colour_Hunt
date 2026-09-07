import SwiftUI

/// 画面の行き来をまとめる。大きなNavigation構造は作らず、
/// 画面の切りかえと2つのシートだけにしている。
///
/// SOLO HUNT と TEAM HUNT は、さがす画面（HuntView）と撮影確認
/// （CapturePreviewView）を共有する。ちがうのは、
///   - TEAM は色が固定（班の担当色）で、写真ごとに色を変えない
///   - TEAM は5分の時計と Found count があり、終わると RESULT へ行く
/// という2点だけ。
struct RootView: View {
    enum Screen {
        case home
        case teamSelect
        case teamReady
        /// SOLO / TEAM 共通のさがす画面
        case hunt
        case preview
        case teamResult
    }

    @EnvironmentObject private var storage: StorageService
    @EnvironmentObject private var camera: CameraService
    @EnvironmentObject private var detector: ColorDetectionService
    @EnvironmentObject private var teamHunt: TeamHuntService

    @Environment(\.scenePhase) private var scenePhase

    @State private var screen: Screen = .home
    @State private var showGallery = false
    @State private var showFolderSetup = false
    @State private var didBootstrap = false
    @State private var pendingTeamNumber: Int?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            content

            if screen == .preview, let photo = camera.capturedPhoto {
                CapturePreviewView(photo: photo,
                                   onRetake: retake,
                                   onFinish: finishCapture)
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
            if hasPhoto && screen == .hunt {
                detector.pause()
                screen = .preview
            }
        }
        .onValueChange(of: teamHunt.isTimeUp) { timeUp in
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
            HomeView(onStartSolo: startSoloHunt,
                     onStartTeam: { screen = .teamSelect },
                     onOpenGallery: { showGallery = true },
                     onOpenFolderSetup: { showFolderSetup = true })

        case .teamSelect:
            TeamSelectView(onSelect: selectTeam,
                           onBack: { screen = .home })

        case .teamReady:
            teamReadyContent

        case .hunt, .preview:
            // 撮影確認のあいだも生かしておく。カメラを止めずにすみ、
            // 「とりなおす」がすぐできる。
            HuntView(onClose: closeSoloHunt,
                     onOpenGallery: { showGallery = true },
                     onFinishTeamHunt: finishTeamHunt)

        case .teamResult:
            teamResultContent
        }
    }

    @ViewBuilder
    private var teamReadyContent: some View {
        if let number = pendingTeamNumber,
           let profile = TeamHuntConfiguration.profile(for: number) {
            TeamReadyView(teamNumber: number,
                          profile: profile,
                          onStart: { startTeamHunt(teamNumber: number, profile: profile) },
                          onBack: { screen = .teamSelect })
        } else {
            // 対応表に無い番号だったときの逃げ道（ふつうは起きない）
            Color.clear.onAppear { screen = .teamSelect }
        }
    }

    @ViewBuilder
    private var teamResultContent: some View {
        if let session = teamHunt.session, let profile = session.profile {
            TeamResultView(teamNumber: session.teamNumber,
                           profile: profile,
                           captureIDs: session.captureIDs,
                           onHome: leaveTeamResult)
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

        if storage.shouldPromptFolderSetup {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showFolderSetup = true
            }
        }
    }

    // MARK: - SOLO HUNT（これまでどおり）

    private func startSoloHunt() {
        teamHunt.clear()
        camera.clearCapturedPhoto()
        detector.pickNextColor()
        screen = .hunt
    }

    private func closeSoloHunt() {
        camera.stop()
        camera.clearCapturedPhoto()
        detector.reset()
        teamHunt.clear()
        screen = .home
    }

    // MARK: - TEAM HUNT

    private func selectTeam(_ number: Int) {
        pendingTeamNumber = number
        screen = .teamReady
    }

    private func startTeamHunt(teamNumber: Int, profile: ColorProfile) {
        camera.clearCapturedPhoto()
        teamHunt.start(teamNumber: teamNumber, profile: profile)
        // 班の担当色をそのまま既存の判定へ渡す。判定処理は SOLO と同じもの。
        detector.activeProfile = profile
        detector.reset()
        screen = .hunt
    }

    /// FINISH または TIME'S UP。写真は消さない。
    private func finishTeamHunt() {
        camera.stop()
        camera.clearCapturedPhoto()
        detector.reset()
        teamHunt.finish()
        screen = .teamResult
    }

    private func leaveTeamResult() {
        teamHunt.clear()
        screen = .home
    }

    /// 5分たったとき。撮影確認の途中なら中断しない（保存を壊さないため）。
    private func handleTimeUp(_ timeUp: Bool) {
        guard timeUp, teamHunt.isActive else { return }
        guard screen == .hunt else { return }
        // TIME'S UP! を少し見せてから結果へ
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if screen == .hunt && teamHunt.isActive {
                finishTeamHunt()
            }
        }
    }

    // MARK: - 撮影確認からの戻り（SOLO / TEAM 共通）

    /// とりなおす: みつけた状態はそのままにして、カメラへもどる
    private func retake() {
        camera.clearCapturedPhoto()
        if teamHunt.isActive && teamHunt.isTimeUp {
            // もう時間がないので、撮り直さずに結果へ
            finishTeamHunt()
            return
        }
        detector.resume()
        screen = .hunt
    }

    /// SOLO: 色を変えてあたらしくさがす
    /// TEAM: 担当色は変えない。同じ色をさがし続ける。
    private func finishCapture() {
        camera.clearCapturedPhoto()

        if teamHunt.isActive {
            if teamHunt.isTimeUp {
                finishTeamHunt()
                return
            }
            detector.reset()
            detector.resume()
            screen = .hunt
            return
        }

        detector.pickNextColor()
        detector.resume()
        screen = .hunt
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if screen == .hunt || screen == .preview {
                camera.start()
            }
        case .background:
            camera.stop()
        default:
            break
        }
    }
}
