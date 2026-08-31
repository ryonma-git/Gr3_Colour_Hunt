import SwiftUI

/// 画面の行き来をまとめる。大きなNavigation構造は作らず、
/// Home / Hunt の切りかえと、2つのシートだけにしている。
struct RootView: View {
    enum Screen {
        case home
        case hunt
        case preview
    }

    @EnvironmentObject private var storage: StorageService
    @EnvironmentObject private var camera: CameraService
    @EnvironmentObject private var detector: ColorDetectionService

    @Environment(\.scenePhase) private var scenePhase

    @State private var screen: Screen = .home
    @State private var showGallery = false
    @State private var showFolderSetup = false
    @State private var didBootstrap = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if screen == .home {
                HomeView(onStart: startHunt,
                         onOpenGallery: { showGallery = true },
                         onOpenFolderSetup: { showFolderSetup = true })
            } else {
                // Hunt は撮影確認のあいだも生かしておく。
                // こうするとカメラを止めずにすみ、「とりなおす」がすぐできる。
                HuntView(onClose: closeHunt,
                         onOpenGallery: { showGallery = true })
            }

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
        .onValueChange(of: scenePhase) { phase in
            handleScenePhase(phase)
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

    // MARK: - 画面の行き来

    private func startHunt() {
        camera.clearCapturedPhoto()
        detector.pickNextColor()
        screen = .hunt
    }

    private func closeHunt() {
        camera.stop()
        camera.clearCapturedPhoto()
        detector.reset()
        screen = .home
    }

    /// とりなおす: みつけた状態はそのままにして、カメラへもどる
    private func retake() {
        camera.clearCapturedPhoto()
        detector.resume()
        screen = .hunt
    }

    /// つぎを さがす: 色を変えて、あたらしく さがしはじめる
    private func finishCapture() {
        camera.clearCapturedPhoto()
        detector.pickNextColor()
        detector.resume()
        screen = .hunt
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if screen != .home {
                camera.start()
            }
        case .background:
            camera.stop()
        default:
            break
        }
    }
}
