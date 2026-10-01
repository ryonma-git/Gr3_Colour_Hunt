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

    // --- schemaVersion 3 で追加。1回の活動（セッション）の情報。
    //     これも optional なので、古い library.json はそのまま読める。

    /// 同じ活動で撮った写真には同じ id が入る（HuntRun.id）
    let sessionID: String?
    /// その活動を始めた時刻
    let sessionStartedAt: Date?
    /// SOLO の難易度（HuntDifficulty.id: "easy" / "normal" / "hard"）。TEAM では nil。
    let level: String?
    /// 制限時間（秒）。0 は「じかん なし」。古いデータでは nil。
    let limitSeconds: Double?
}

extension ColorCapture {
    var huntMode: HuntMode {
        HuntMode(rawValue: mode ?? "") ?? .solo
    }
}

/// `library.json` そのもの。
struct ColorHuntLibrary: Codable {
    /// 3 = sessionID / sessionStartedAt / level / limitSeconds を追加した版。
    /// 追加ぶんはすべて optional なので、schemaVersion 1・2 のファイルもそのまま読める。
    static let currentSchemaVersion = 3

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

/// library.json の日時。ミリ秒まで書く。
///
/// 秒までしか書かないと、同じ秒に撮った2枚の前後が
/// 読み込んだあとに分からなくなり、履歴の並びが崩れる。
/// Web 版（toISOString）もミリ秒まで書くので、形式もそろう。
enum ColorHuntDate {
    private static let withMilliseconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func string(from date: Date) -> String {
        withMilliseconds.string(from: date)
    }

    /// ミリ秒の無い古いファイルも読めるようにしてある
    static func date(from text: String) -> Date? {
        withMilliseconds.date(from: text) ?? plain.date(from: text)
    }
}

extension JSONEncoder {
    static func colorHunt() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ColorHuntDate.string(from: date))
        }
        return encoder
    }
}

extension JSONDecoder {
    static func colorHunt() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = ColorHuntDate.date(from: text) else {
                throw DecodingError.dataCorruptedError(in: container,
                                                       debugDescription: "日時の形式が読めません: " + text)
            }
            return date
        }
        return decoder
    }
}
