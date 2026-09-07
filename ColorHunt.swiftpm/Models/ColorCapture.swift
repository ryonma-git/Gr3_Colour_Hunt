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

    // --- schemaVersion 2 で追加。古いデータには無いので optional にしてある。
    //     （optional なので schemaVersion 1 の library.json もそのまま読める）

    /// 活動の種類（HuntMode の rawValue: "solo" / "team"）。古いデータでは nil。
    let mode: String?
    /// TEAM HUNT のときの班番号。SOLO では nil。
    let teamNumber: Int?
}

extension ColorCapture {
    var huntMode: HuntMode {
        HuntMode(rawValue: mode ?? "") ?? .solo
    }
}

/// `library.json` そのもの。
struct ColorHuntLibrary: Codable {
    /// 2 = mode / teamNumber を追加した版。
    /// どちらも optional なので、schemaVersion 1 で書かれたファイルもそのまま読める。
    static let currentSchemaVersion = 2

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
