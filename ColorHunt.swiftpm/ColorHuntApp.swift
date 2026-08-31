import SwiftUI

/// Color Hunt — 小学3年生の外国語活動で「英語で言われた色」を教室の中からさがすアプリ。
///
/// 大事な考え方:
/// これは「カメラが物の色を教えるアプリ」ではない。
/// 児童が先に「これは青だと思う」と考えてカメラを向け、
/// アプリは指定された色の範囲に入っているかを確かめるだけ。判断するのは児童。
@main
struct ColorHuntApp: App {

    @StateObject private var storage = StorageService()
    @StateObject private var camera = CameraService()
    /// いまさがしている色は1つだけ持つ。
    /// 出題する色は ColorProfile.huntColors から毎回ランダムに選ばれる。
    @StateObject private var detector =
        ColorDetectionService(profile: ColorProfile.randomHuntColor(excluding: nil))
    @StateObject private var speech = SpeechService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(storage)
                .environmentObject(camera)
                .environmentObject(detector)
                .environmentObject(speech)
        }
    }
}
