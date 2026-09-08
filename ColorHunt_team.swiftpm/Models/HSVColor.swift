import Foundation

/// カメラ中央から取り出した色を、色相・彩度・明度で表したもの。
///
/// - h: 色相 0...360（度）
/// - s: 彩度 0...1
/// - v: 明度 0...1
///
/// `library.json` にもこのキー名のまま保存される。
struct HSVColor: Codable, Hashable {
    var h: Double
    var s: Double
    var v: Double

    static let zero = HSVColor(h: 0, s: 0, v: 0)
}

extension HSVColor {
    /// デバッグ表示用（児童用UIでは使わない）
    var debugDescription: String {
        String(format: "H:%.1f  S:%.2f  V:%.2f", h, s, v)
    }
}
