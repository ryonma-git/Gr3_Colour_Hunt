import Foundation

/// 児童が「この写真にする」を押して、正式に保存された1枚。
/// `library.json` の captures 配列の1要素にそのまま対応する。
struct ColorCapture: Identifiable, Codable, Hashable {
    /// UUID 文字列
    let id: String
    /// ColorProfile.id （例: "red"）
    let targetColor: String
    /// 画面表示用（例: "RED"）
    let displayName: String
    /// ライブラリフォルダからの相対パス（例: "photos/xxxx.jpg"）
    let imageFile: String
    let capturedAt: Date
    /// ColorDifficulty の rawValue（例: "basic"）
    let difficulty: String
    /// 撮影時の ColorProfile.profileVersion
    let colorProfileVersion: Int
    /// 判定が成立したときに実際に測った色
    let sampledHSV: HSVColor
}

/// `library.json` そのもの。
struct ColorHuntLibrary: Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var captures: [ColorCapture]

    static let empty = ColorHuntLibrary(schemaVersion: currentSchemaVersion, captures: [])
}

extension ColorCapture {
    /// 撮影日時の表示（例: 2026/8/31 10:24）
    var capturedAtText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: capturedAt)
    }
}

extension JSONEncoder {
    static func colorHunt() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static func colorHunt() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
