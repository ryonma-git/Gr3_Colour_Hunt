#!/bin/bash
# ------------------------------------------------------------------
# Color Hunt 検証用ハーネス
#
# ColorHunt.swiftpm の「いまのソース」をそのままコピーして、
# カメラの無い iOS シミュレータでも1画面ずつ見られる確認用アプリを作って起動する。
# 本体（ColorHunt.swiftpm）には一切手を加えない。
#
#   使い方:  ./harness.sh [画面名]
#
#   home     ホーム（COLOR HUNT / START / MY COLORS）
#   setup    保存先をえらぶ画面（シートとして表示）
#   hunt     さがす画面（3・2・1 → カメラ無しの状態）
#   found    RED をみつけた状態（合成した赤い色を流し込む）
#   preview  撮影後の確認画面（合成写真。保存とロイロ共有まで試せる）
#   gallery  MY COLORS（シートとして表示）
# ------------------------------------------------------------------
SCREEN="${1:-home}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/ColorHunt.swiftpm"
WORK="${TMPDIR:-/tmp}/ColorHuntHarness"
PKG="$WORK/Harness.swiftpm"
BUNDLE="com.example.colorhunt.harness"

echo "==> ソースをコピー"
rm -rf "$PKG"
mkdir -p "$PKG"
cp -R "$SRC/Models" "$SRC/Services" "$SRC/Views" "$SRC/Utilities" "$PKG/"

cat > "$PKG/Package.swift" <<'SWIFT'
// swift-tools-version: 5.6
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Harness",
    platforms: [.iOS("16.0")],
    products: [
        .iOSApplication(
            name: "Harness",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.colorhunt.harness",
            displayVersion: "1.0",
            bundleVersion: "1",
            accentColor: .presetColor(.red),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [.portrait, .landscapeRight, .landscapeLeft],
            capabilities: [.camera(purposeString: "harness")]
        )
    ],
    targets: [.executableTarget(name: "AppModule", path: ".")]
)
SWIFT

cat > "$PKG/HarnessApp.swift" <<'SWIFT'
import SwiftUI
import UIKit

/// 検証専用の入口。起動引数 -harnessScreen で表示する画面を切りかえる。
/// ColorHunt 本体の View / Service をそのまま使う。
///
/// 注意: ここは「本体の RootView の代わり」をする最小の器。
/// 本番のナビゲーションそのものを確かめたいときは、本体アプリ（Color Hunt）を
/// シミュレータで起動してください。カメラが無くても画面の行き来は全部動きます。
@main
struct HarnessApp: App {
    @StateObject private var storage = StorageService()
    @StateObject private var camera = CameraService()
    @StateObject private var detector = ColorDetectionService(profile: ColorProfile.red)
    @StateObject private var speech = SpeechService()

    private var screen: String {
        UserDefaults.standard.string(forKey: "harnessScreen") ?? "home"
    }

    var body: some Scene {
        WindowGroup {
            content
                .environmentObject(storage)
                .environmentObject(camera)
                .environmentObject(detector)
                .environmentObject(speech)
                .preferredColorScheme(.light)
                .onAppear { storage.bootstrap() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case "setup":
            Theme.background
                .ignoresSafeArea()
                .sheet(isPresented: .constant(true)) {
                    FolderSetupView(onClose: {})
                        .preferredColorScheme(.light)
                }
        case "gallery":
            Theme.background
                .ignoresSafeArea()
                .sheet(isPresented: .constant(true)) {
                    GalleryView(onClose: {})
                        .preferredColorScheme(.light)
                }
        case "hunt":
            HarnessShell(start: .hunt, seedFound: false)
        case "found":
            HarnessShell(start: .hunt, seedFound: true)
        case "preview":
            HarnessShell(start: .preview, seedFound: true)
        default:
            HarnessShell(start: .home, seedFound: false)
        }
    }

    /// カメラが無い環境用の、赤いものを写したことにする合成写真
    static func makeSamplePhoto() -> CapturedPhoto {
        let size = CGSize(width: 1200, height: 1600)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor(white: 0.90, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.82, green: 0.13, blue: 0.15, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 250, y: 550, width: 700, height: 500))
            UIColor(white: 0.55, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 1300, width: size.width, height: 300))
        }
        let data = image.jpegData(compressionQuality: 0.85) ?? Data()
        return CapturedPhoto(image: image, jpegData: data)
    }
}

/// 合成写真は1回だけ作る
enum HarnessSample {
    static let photo: CapturedPhoto = HarnessApp.makeSamplePhoto()
}

/// 本体 RootView と同じつなぎ方を最小限で再現した器。
/// ボタンが「押しても何も起きない」状態を作らないためのもの。
struct HarnessShell: View {
    enum Start {
        case home
        case hunt
        case preview
    }

    let seedFound: Bool

    @EnvironmentObject private var detector: ColorDetectionService

    @State private var isAtHome: Bool
    @State private var isShowingPreview: Bool
    @State private var showGallery = false
    @State private var showSetup = false

    init(start: Start, seedFound: Bool) {
        self.seedFound = seedFound
        _isAtHome = State(initialValue: start == .home)
        _isShowingPreview = State(initialValue: start == .preview)
    }

    /// -harnessAutoFinish YES を付けると3秒後に「つぎをさがす」を自動で押す
    private var autoFinish: Bool {
        UserDefaults.standard.bool(forKey: "harnessAutoFinish")
    }

    var body: some View {
        ZStack {
            if isAtHome {
                HomeView(onStart: {
                            detector.pickNextColor()
                            isAtHome = false
                         },
                         onOpenGallery: { showGallery = true },
                         onOpenFolderSetup: { showSetup = true })
            } else {
                HuntView(onClose: { isAtHome = true },
                         onOpenGallery: { showGallery = true })
                    .task { await seedFoundState() }
            }

            if !isAtHome && isShowingPreview {
                CapturePreviewView(photo: HarnessSample.photo,
                                   onRetake: {
                                       detector.resume()
                                       isShowingPreview = false
                                   },
                                   onFinish: {
                                       // 本体の finishCapture(): 色を変えて探し直す
                                       detector.pickNextColor()
                                       detector.resume()
                                       isShowingPreview = false
                                   })
                    .task { await autoFinishIfNeeded() }
            }
        }
        .sheet(isPresented: $showGallery) {
            GalleryView(onClose: { showGallery = false })
                .preferredColorScheme(.light)
        }
        .sheet(isPresented: $showSetup) {
            FolderSetupView(onClose: { showSetup = false })
                .preferredColorScheme(.light)
        }
    }

    /// 「RED をみつけた状態」を作る。
    /// -harnessRelease YES を付けると、そのあと赤以外を流し込んで
    /// 「みつけた状態が解除されて、また探し始められる」ことを確かめられる。
    private func seedFoundState() async {
        guard seedFound else { return }
        // いま出題されている色ちょうどの色を写しつづける → FOUND になる
        for _ in 0..<60 {
            detector.ingest(HarnessShell.sampleHSV(for: detector.activeProfile))
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        guard UserDefaults.standard.bool(forKey: "harnessRelease") else { return }
        // どの色にも当たらない白っぽいものに向けかえた → しばらくして FOUND が解ける
        for _ in 0..<120 {
            detector.ingest(HSVColor(h: 0, s: 0.02, v: 0.95))
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    /// そのプロファイルのど真ん中にあたる色をつくる（どの色が出ても FOUND を再現できる）
    static func sampleHSV(for profile: ColorProfile) -> HSVColor {
        var hue: Double = 0
        if let first = profile.hueRanges.first {
            hue = first.from <= first.to ? (first.from + first.to) / 2 : first.from
        }
        let s = (profile.saturationRange.lower + profile.saturationRange.upper) / 2
        let v = (profile.brightnessRange.lower + profile.brightnessRange.upper) / 2
        return HSVColor(h: hue, s: s, v: v)
    }

    private func autoFinishIfNeeded() async {
        guard autoFinish else { return }
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        detector.pickNextColor()
        detector.resume()
        isShowingPreview = false
    }
}
SWIFT

echo "==> シミュレータを用意"
UUID_RE='[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}'
UDID=$(xcrun simctl list devices booted | grep -oE "$UUID_RE" | head -1)
if [ -z "$UDID" ]; then
  UDID=$(xcrun simctl list devices available | grep "iPad" | grep -oE "$UUID_RE" | head -1)
  if [ -z "$UDID" ]; then
    echo "!! iPad シミュレータが見つかりません"
    exit 1
  fi
  echo "   boot: $UDID"
  xcrun simctl boot "$UDID"
  xcrun simctl bootstatus "$UDID" -b >/dev/null
fi
open -a Simulator

echo "==> ビルド"
cd "$PKG" || exit 1
if ! xcodebuild -scheme Harness \
      -destination "platform=iOS Simulator,id=$UDID" \
      -derivedDataPath "$WORK/dd" build > "$WORK/build.log" 2>&1; then
  echo "!! ビルド失敗:"
  grep -E "error:" "$WORK/build.log" | head -20
  exit 1
fi

echo "==> インストールして起動 (screen=$SCREEN)"
xcrun simctl install "$UDID" "$WORK/dd/Build/Products/Debug-iphonesimulator/Harness.app"
xcrun simctl privacy "$UDID" grant camera "$BUNDLE" >/dev/null 2>&1
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
case "${2:-}" in
  auto)    EXTRA=(-harnessAutoFinish YES) ;;
  release) EXTRA=(-harnessRelease YES) ;;
  *)       EXTRA=() ;;
esac
xcrun simctl launch "$UDID" "$BUNDLE" -harnessScreen "$SCREEN" "${EXTRA[@]}"
echo "==> OK"
