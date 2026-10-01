import Foundation

// ============================================================================
//  1回の活動（セッション）と、開始前の画面でえらぶ設定。
//
//  ★ 時間の選択肢を変えるときは、このファイルの HuntTimeOptions だけを直す。
//    View にはハードコードしない。
// ============================================================================

/// 1回ぶんの活動。アプリを終了するまでメモリ上に持つ。
///
/// 保存しないのは、写真そのものが library.json に
/// sessionID / mode / teamNumber / level つきで残るため。
/// あとから「どの活動で撮ったか」をたどれる（過剰設計を避けた）。
struct HuntRun: Identifiable {
    let id: String
    let mode: HuntMode
    /// TEAM HUNT のときの班番号。SOLO では nil。
    let teamNumber: Int?
    /// TEAM HUNT の担当色。SOLO では nil（色は1枚ごとに変わる）。
    let targetColorProfileID: String?
    /// SOLO の難易度。TEAM では nil（色が固定なので使わない）。
    let levelID: String?
    /// 制限時間（秒）。0 は「じかん なし」。
    let limitSeconds: TimeInterval
    let startedAt: Date
    var endedAt: Date?
    /// この活動中に保存された ColorCapture.id
    var captureIDs: [String]

    init(mode: HuntMode,
         teamNumber: Int? = nil,
         profile: ColorProfile? = nil,
         level: HuntDifficulty? = nil,
         limitSeconds: TimeInterval,
         startedAt: Date = Date()) {
        self.id = UUID().uuidString
        self.mode = mode
        self.teamNumber = teamNumber
        self.targetColorProfileID = profile?.id
        self.levelID = level?.id
        self.limitSeconds = limitSeconds
        self.startedAt = startedAt
        self.endedAt = nil
        self.captureIDs = []
    }

    /// TEAM HUNT の担当色
    var profile: ColorProfile? {
        targetColorProfileID.flatMap { ColorProfile.profile(id: $0) }
    }

    var level: HuntDifficulty? {
        levelID.map { HuntDifficulty.byID($0) }
    }

    var hasTimeLimit: Bool { limitSeconds > 0 }
    var foundCount: Int { captureIDs.count }
}

/// 時間制限の選択肢。
enum HuntTimeOptions {

    /// ★ 開始前の画面に並ぶボタン（分）。0 は「なし」。
    static let presetMinutes: [Int] = [0, 1, 2, 3, 5]

    /// 「そのほか」で −／＋ で選べる範囲（分）
    static let customRange: ClosedRange<Int> = 1...20

    /// はじめて使うときの既定（分）
    static func defaultMinutes(for mode: HuntMode) -> Int {
        mode == .team ? 5 : 3
    }

    /// 0（なし）か 1〜20分だけを通す
    static func clean(_ minutes: Int, fallback: Int) -> Int {
        if minutes == 0 { return 0 }
        return customRange.contains(minutes) ? minutes : fallback
    }

    /// 残りがこの秒数以下で、時計の色を変えて知らせる（点滅はしない）
    static let warningThreshold: TimeInterval = 30

    /// 「3ふん」「じかん なし」
    static func label(seconds: TimeInterval) -> String {
        seconds <= 0 ? "じかん なし" : "\(Int(seconds / 60))ふん"
    }
}

/// 前回えらんだ難易度と時間を端末におぼえておく。
/// 先生が毎回えらび直さなくてよいようにするだけの、ごく小さな記憶。
enum HuntSettings {

    private static let levelKey = "colorhunt.level"
    private static let soloLimitKey = "colorhunt.limit.solo"
    private static let teamLimitKey = "colorhunt.limit.team"

    static var level: HuntDifficulty {
        get { HuntDifficulty.byID(UserDefaults.standard.string(forKey: levelKey)) }
        set { UserDefaults.standard.set(newValue.id, forKey: levelKey) }
    }

    static func limitMinutes(for mode: HuntMode) -> Int {
        let key = mode == .team ? teamLimitKey : soloLimitKey
        let fallback = HuntTimeOptions.defaultMinutes(for: mode)
        guard UserDefaults.standard.object(forKey: key) != nil else { return fallback }
        return HuntTimeOptions.clean(UserDefaults.standard.integer(forKey: key), fallback: fallback)
    }

    static func setLimitMinutes(_ minutes: Int, for mode: HuntMode) {
        UserDefaults.standard.set(minutes, forKey: mode == .team ? teamLimitKey : soloLimitKey)
    }
}
