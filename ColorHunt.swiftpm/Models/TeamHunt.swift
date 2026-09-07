import Foundation

// ============================================================================
//  TEAM HUNT の設定。
//  ★ 班と担当色の対応を変えるときは、このファイルの assignments だけを直す。
//    View にはハードコードしない。
// ============================================================================

/// 班番号ひとつ分の担当色。
struct TeamColorAssignment: Identifiable, Hashable {
    let teamNumber: Int
    /// ColorProfile.id（例: "red"）
    let colorProfileID: String

    var id: Int { teamNumber }

    var profile: ColorProfile? {
        ColorProfile.profile(id: colorProfileID)
    }
}

/// TEAM HUNT 全体の設定。
enum TeamHuntConfiguration {

    /// 班の数
    static let teamCount = 8

    /// 1回の活動時間（5分固定）
    static let duration: TimeInterval = 5 * 60

    /// 残り時間がこれ以下になったら、色を変えて注意を促す（点滅はしない）
    static let warningThreshold: TimeInterval = 30

    // ------------------------------------------------------------------
    //  ★ 班と色の対応表。授業で組み合わせを変えるときはここだけ直す。
    //    ランダム割り当てはしない。同じ班番号なら全端末で必ず同じ色になる。
    //
    //    将来 Set B を足したくなったら、別の配列を用意して
    //    activeAssignments を差し替えられるようにしてある。
    //    （今回は教師用の切替UIは作らない）
    // ------------------------------------------------------------------
    static let setA: [TeamColorAssignment] = [
        TeamColorAssignment(teamNumber: 1, colorProfileID: "red"),
        TeamColorAssignment(teamNumber: 2, colorProfileID: "blue"),
        TeamColorAssignment(teamNumber: 3, colorProfileID: "green"),
        TeamColorAssignment(teamNumber: 4, colorProfileID: "yellow"),
        TeamColorAssignment(teamNumber: 5, colorProfileID: "orange"),
        TeamColorAssignment(teamNumber: 6, colorProfileID: "purple"),
        TeamColorAssignment(teamNumber: 7, colorProfileID: "pink"),
        TeamColorAssignment(teamNumber: 8, colorProfileID: "brown")
    ]

    /// いま使う対応表
    static let activeAssignments: [TeamColorAssignment] = setA

    static func assignment(for teamNumber: Int) -> TeamColorAssignment? {
        activeAssignments.first { $0.teamNumber == teamNumber }
    }

    static func profile(for teamNumber: Int) -> ColorProfile? {
        assignment(for: teamNumber)?.profile
    }
}

/// 1回の TEAM HUNT。アプリを終了するまでメモリ上に持つ。
///
/// 保存しないのは、写真そのものが library.json に mode / teamNumber つきで
/// 残るため、あとから班ごとに取り出せるから（過剰設計を避けた）。
struct TeamHuntSession: Identifiable {
    let id: String
    let teamNumber: Int
    let targetColorProfileID: String
    let startedAt: Date
    var endedAt: Date?
    /// この活動中に「この しゃしんに する」で保存された ColorCapture.id
    var captureIDs: [String]

    init(teamNumber: Int, profile: ColorProfile, startedAt: Date = Date()) {
        self.id = UUID().uuidString
        self.teamNumber = teamNumber
        self.targetColorProfileID = profile.id
        self.startedAt = startedAt
        self.endedAt = nil
        self.captureIDs = []
    }

    var profile: ColorProfile? {
        ColorProfile.profile(id: targetColorProfileID)
    }

    var foundCount: Int { captureIDs.count }
}

/// ColorCapture に記録する活動の種類。
enum HuntMode: String, Codable {
    case solo
    case team
}
