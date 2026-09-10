#!/bin/bash
# ------------------------------------------------------------------
# Color Hunt 検証用ハーネス
#
# ColorHunt_team.swiftpm の「いまのソース」をそのままコピーして、
# カメラの無い iOS シミュレータでも1画面ずつ見られる確認用アプリを作って起動する。
# 本体（ColorHunt_team.swiftpm）には一切手を加えない。
#
#   使い方:  ./harness.sh [画面名]
#
#   home     ホーム（COLOR HUNT / START / MY COLORS）
#   setup    保存先をえらぶ画面（シートとして表示）
#   hunt     さがす画面（3・2・1 → カメラ無しの状態）
#   found    RED をみつけた状態（合成した赤い色を流し込む）
#   preview  撮影後の確認画面（合成写真。保存とロイロ共有まで試せる）
#   gallery  MY COLORS（シートとして表示）
#
#   第2引数:
#   askcam   カメラ許可を「まだ聞いていない」状態にする（予告画面の確認）
#   denycam  「許可しない」を押した状態にする（先生向け案内の確認）
# ------------------------------------------------------------------
SCREEN="${1:-home}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/ColorHunt_team.swiftpm"
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

// ============================================================================
//  検証専用の入口。起動引数 -harnessScreen で表示する画面を切りかえる。
//
//  ★ 鉄則: コールバックに {} を書かないこと。
//    空にすると「押しても何も起きないボタン」ができ、本体のバグと区別が
//    つかなくなる。行き先が無い場合は必ず exit()（本体の RootView へ戻る）
//    を渡すこと。ビルド前にスクリプト側でも空クロージャを検査している。
// ============================================================================

@main
struct HarnessApp: App {
    @StateObject private var storage = StorageService()
    @StateObject private var camera = CameraService()
    @StateObject private var detector = ColorDetectionService(profile: ColorProfile.randomHuntColor(excluding: nil))
    @StateObject private var speech = SpeechService()
    @StateObject private var teamHunt = TeamHuntService()

    private var screen: String {
        UserDefaults.standard.string(forKey: "harnessScreen") ?? "home"
    }

    var body: some Scene {
        WindowGroup {
            HarnessContainer(screen: screen)
                .environmentObject(storage)
                .environmentObject(camera)
                .environmentObject(detector)
                .environmentObject(speech)
                .environmentObject(teamHunt)
                .preferredColorScheme(.light)
                .onAppear { storage.bootstrap() }
        }
    }

    /// カメラが無い環境用の、見つけた物に見立てた合成写真
    static func makeSamplePhoto(hue: Double = 356, variant: Int = 0) -> CapturedPhoto {
        let size = CGSize(width: 1200, height: 1600)
        let renderer = UIGraphicsImageRenderer(size: size)
        let rgb = RGBHSVConversion.rgb(HSVColor(h: hue, s: 0.75, v: 0.72))
        let image = renderer.image { context in
            UIColor(white: 0.90 - Double(variant % 3) * 0.04, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(white: 0.55, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 1300, width: size.width, height: 300))
            UIColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1).setFill()
            let w = 420.0 + Double(variant % 4) * 130
            let h = 320.0 + Double((variant + 1) % 3) * 150
            let x = 140.0 + Double(variant % 3) * 120
            let y = 420.0 + Double(variant % 2) * 200
            if variant % 3 == 0 {
                context.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: w, height: h))
            } else {
                UIBezierPath(roundedRect: CGRect(x: x, y: y, width: w, height: h),
                             cornerRadius: 40).fill()
            }
        }
        let data = image.jpegData(compressionQuality: 0.85) ?? Data()
        return CapturedPhoto(image: image, jpegData: data)
    }
}

enum HarnessSample {
    static let photo: CapturedPhoto = HarnessApp.makeSamplePhoto(hue: 356)
}

/// -harnessTeam 4 / -harnessPhotos 12 で班番号と枚数を変えられる
enum HarnessTeam {
    static var number: Int {
        let n = UserDefaults.standard.integer(forKey: "harnessTeam")
        return (1...TeamHuntConfiguration.teamCount).contains(n) ? n : 3
    }
    static var photoCount: Int {
        let n = UserDefaults.standard.integer(forKey: "harnessPhotos")
        return (1...40).contains(n) ? n : 8
    }
    static var autoFinish: Bool { UserDefaults.standard.bool(forKey: "harnessAutoFinish") }
    /// -harnessAutoExit YES で「もどる／ホーム」を3秒後に自動で押す（動作確認用）
    static var autoExit: Bool { UserDefaults.standard.bool(forKey: "harnessAutoExit") }
    static var release: Bool { UserDefaults.standard.bool(forKey: "harnessRelease") }
}

// ---------------------------------------------------------------------------

/// すべての単体画面の入れもの。
/// どの画面の「戻る／閉じる／ホーム」も、行き先が無ければ本体の RootView へ戻す。
/// これで空のコールバックを書く必要が無くなる。
struct HarnessContainer: View {
    let screen: String

    @EnvironmentObject private var storage: StorageService
    @EnvironmentObject private var detector: ColorDetectionService
    @EnvironmentObject private var teamHunt: TeamHuntService

    @State private var exited = false
    @State private var selectedTeam: Int?
    @State private var startedTeamHunt = false
    @State private var showGallery = false

    var body: some View {
        if exited {
            // 本体そのもの。ここから先は本番と完全に同じ導線。
            RootView()
        } else {
            current
                .sheet(isPresented: $showGallery) {
                    GalleryView(onClose: { showGallery = false })
                        .preferredColorScheme(.light)
                }
                .task {
                    guard HarnessTeam.autoExit else { return }
                    try? await Task.sleep(nanoseconds: 3_500_000_000)
                    exit()
                }
        }
    }

    private func exit() { exited = true }

    @ViewBuilder
    private var current: some View {
        switch screen {
        case "setup":
            Theme.background.ignoresSafeArea()
                .sheet(isPresented: .constant(true)) {
                    FolderSetupView(onClose: exit).preferredColorScheme(.light)
                }
        case "gallery":
            GalleryView(onClose: exit)
        case "hunt":
            HarnessSoloHunt(seedFound: false, onExit: exit, onGallery: { showGallery = true })
        case "found":
            HarnessSoloHunt(seedFound: true, onExit: exit, onGallery: { showGallery = true })
        case "preview":
            HarnessCaptureFlow(onExit: exit, onGallery: { showGallery = true })
        case "teamselect":
            teamSelectFlow
        case "teamready":
            teamReadyFlow
        case "teamhunt":
            TeamHarnessHunt(onExit: exit, onGallery: { showGallery = true })
        case "teamresult":
            TeamHarnessResult(openViewer: false, onExit: exit)
        case "teamphoto":
            TeamHarnessResult(openViewer: true, onExit: exit)
        default:
            RootView()
        }
    }

    /// 班をえらぶ → 確認画面へ（行き止まりを作らない）
    @ViewBuilder
    private var teamSelectFlow: some View {
        if let team = selectedTeam, let profile = TeamHuntConfiguration.profile(for: team) {
            TeamReadyView(teamNumber: team, profile: profile,
                          onStart: exit,
                          onBack: { selectedTeam = nil })
        } else {
            TeamSelectView(onSelect: { selectedTeam = $0 }, onBack: exit)
        }
    }

    /// 確認画面 → START でさがす画面へ
    @ViewBuilder
    private var teamReadyFlow: some View {
        if startedTeamHunt {
            TeamHarnessHunt(onExit: exit, onGallery: { showGallery = true })
        } else if let profile = TeamHuntConfiguration.profile(for: HarnessTeam.number) {
            TeamReadyView(teamNumber: HarnessTeam.number, profile: profile,
                          onStart: { startedTeamHunt = true },
                          onBack: exit)
        } else {
            Color.clear.onAppear(perform: exit)
        }
    }
}

// ---------------------------------------------------------------------------

/// SOLO のさがす画面
struct HarnessSoloHunt: View {
    let seedFound: Bool
    let onExit: () -> Void
    let onGallery: () -> Void

    @EnvironmentObject private var detector: ColorDetectionService

    var body: some View {
        HuntView(onClose: onExit, onOpenGallery: onGallery)
            .task { await seed() }
    }

    private func seed() async {
        guard seedFound else { return }
        for _ in 0..<60 {
            detector.ingest(HarnessSupport.sampleHSV(for: detector.activeProfile))
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        guard HarnessTeam.release else { return }
        for _ in 0..<120 {
            detector.ingest(HSVColor(h: 0, s: 0.02, v: 0.95))
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}

/// 撮影確認 → とりなおす／つぎをさがす
struct HarnessCaptureFlow: View {
    let onExit: () -> Void
    let onGallery: () -> Void

    @EnvironmentObject private var detector: ColorDetectionService
    @State private var isShowingPreview = true

    var body: some View {
        ZStack {
            HuntView(onClose: onExit, onOpenGallery: onGallery)
                .task {
                    for _ in 0..<80 {
                        detector.ingest(HarnessSupport.sampleHSV(for: detector.activeProfile))
                        try? await Task.sleep(nanoseconds: 50_000_000)
                    }
                }
            if isShowingPreview {
                CapturePreviewView(photo: HarnessSample.photo,
                                   onRetake: {
                                       detector.resume()
                                       isShowingPreview = false
                                   },
                                   onFinish: {
                                       detector.pickNextColor()
                                       detector.resume()
                                       isShowingPreview = false
                                   })
                    .task { await autoFinishIfNeeded() }
            }
        }
    }

    private func autoFinishIfNeeded() async {
        guard HarnessTeam.autoFinish else { return }
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        detector.pickNextColor()
        detector.resume()
        isShowingPreview = false
    }
}

/// TEAM のさがす画面（班の色・5分の時計つき）
struct TeamHarnessHunt: View {
    let onExit: () -> Void
    let onGallery: () -> Void

    @EnvironmentObject private var detector: ColorDetectionService
    @EnvironmentObject private var teamHunt: TeamHuntService
    @State private var ready = false

    var body: some View {
        Group {
            if ready {
                HuntView(onClose: onExit, onOpenGallery: onGallery, onFinishTeamHunt: onExit)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .task {
            let team = HarnessTeam.number
            guard let profile = TeamHuntConfiguration.profile(for: team) else { return }
            teamHunt.start(teamNumber: team, profile: profile)
            detector.activeProfile = profile
            detector.reset()
            ready = true
            for _ in 0..<120 {
                detector.ingest(HarnessSupport.sampleHSV(for: profile))
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
    }
}

/// RESULT / 写真の拡大表示（合成写真を実際に保存して本番と同じ経路で出す）
struct TeamHarnessResult: View {
    let openViewer: Bool
    let onExit: () -> Void

    @EnvironmentObject private var storage: StorageService
    @EnvironmentObject private var teamHunt: TeamHuntService
    @State private var ready = false

    var body: some View {
        Group {
            if ready, let session = teamHunt.session, let profile = session.profile {
                if openViewer {
                    TeamPhotoViewerView(captures: storage.captures(withIDs: session.captureIDs),
                                        profile: profile,
                                        startIndex: 2,
                                        onClose: onExit)
                } else {
                    TeamResultView(teamNumber: session.teamNumber,
                                   profile: profile,
                                   captureIDs: session.captureIDs,
                                   onHome: onExit)
                }
            } else {
                Color.clear
            }
        }
        .task {
            let team = HarnessTeam.number
            guard !ready, let profile = TeamHuntConfiguration.profile(for: team) else { return }
            teamHunt.start(teamNumber: team, profile: profile)
            let first = profile.hueRanges[0]
            let baseHue = first.from <= first.to ? (first.from + first.to) / 2 : first.from
            for i in 0..<HarnessTeam.photoCount {
                let photo = HarnessApp.makeSamplePhoto(hue: baseHue + Double(i) * 6 - 15, variant: i)
                if let c = storage.save(photo: photo, profile: profile,
                                        hsv: HSVColor(h: baseHue, s: 0.6, v: 0.5),
                                        mode: .team, teamNumber: team) {
                    teamHunt.record(c)
                }
            }
            teamHunt.finish()
            ready = true
        }
    }
}

enum HarnessSupport {
    /// そのプロファイルのど真ん中の色（どの色が出ても FOUND を再現できる）
    static func sampleHSV(for profile: ColorProfile) -> HSVColor {
        var hue: Double = 0
        if let first = profile.hueRanges.first {
            hue = first.from <= first.to ? (first.from + first.to) / 2 : first.from
        }
        return HSVColor(h: hue,
                        s: (profile.saturationRange.lower + profile.saturationRange.upper) / 2,
                        v: (profile.brightnessRange.lower + profile.brightnessRange.upper) / 2)
    }
}
SWIFT

# ★ 空のコールバックが残っていないか検査する。
#   ここで落としておかないと「押しても何も起きないボタン」が混ざる。
if grep -nE 'on[A-Za-z]+: *\{ *\}|onSelect: *\{ *_ +in *\}' "$PKG/HarnessApp.swift"; then
  echo "!! ハーネスに空のコールバックがあります（押しても反応しないボタンになります）"
  exit 1
fi

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
# 既定ではカメラを許可しておく（画面を見たいだけのことが多いため）。
# 権限まわりを試すときは第2引数で askcam / denycam を渡す。
case "${2:-}" in
  askcam)  xcrun simctl privacy "$UDID" reset  camera "$BUNDLE" >/dev/null 2>&1 ;;
  denycam) xcrun simctl privacy "$UDID" revoke camera "$BUNDLE" >/dev/null 2>&1 ;;
  *)       xcrun simctl privacy "$UDID" grant  camera "$BUNDLE" >/dev/null 2>&1 ;;
esac
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
case "${2:-}" in
  auto)    EXTRA=(-harnessAutoFinish YES) ;;
  release) EXTRA=(-harnessRelease YES) ;;
  team*)   EXTRA=(-harnessTeam "${2#team}" -harnessPhotos "${3:-8}") ;;
  autoexit) EXTRA=(-harnessAutoExit YES) ;;
  *)       EXTRA=() ;;
esac
xcrun simctl launch "$UDID" "$BUNDLE" -harnessScreen "$SCREEN" "${EXTRA[@]}"
echo "==> OK"
