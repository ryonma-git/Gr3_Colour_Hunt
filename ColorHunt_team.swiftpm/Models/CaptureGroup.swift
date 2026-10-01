import Foundation

/// MY COLORS を「1回の活動（セッション）」ごとに見せるためのまとまり。
///
/// 色ごとではなく活動ごとに並べるのは、
/// 「この時間に何枚みつけた」という体験の単位で見返せるようにするため。
struct CaptureGroup: Identifiable {
    let id: String
    /// セッション情報が無い古い写真では nil（日付でまとめる）
    let sessionID: String?
    let mode: HuntMode?
    let teamNumber: Int?
    let level: HuntDifficulty?
    /// 制限時間（秒）。0 は「じかん なし」。古い写真では nil。
    let limitSeconds: Double?
    var startedAt: Date
    var items: [ColorCapture]

    /// 「9月30日 10:15」。古い写真は日付だけ。
    var title: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = sessionID == nil ? "M月d日" : "M月d日 HH:mm"
        return formatter.string(from: startedAt)
    }

    /// 「SOLO・かんたん・3ふん」「TEAM 4・YELLOW・5ふん」
    var subtitle: String {
        guard sessionID != nil else { return "これより まえの しゃしん" }
        var parts: [String] = []
        if mode == .team {
            parts.append("TEAM \(teamNumber ?? 0)")
            if let number = teamNumber,
               let profile = TeamHuntConfiguration.profile(for: number) {
                parts.append(profile.displayName)
            }
        } else {
            parts.append("SOLO")
            if let level = level { parts.append(level.label) }
        }
        if let seconds = limitSeconds {
            parts.append(HuntTimeOptions.label(seconds: seconds))
        }
        return parts.joined(separator: "・")
    }

    /// 新しい活動が先頭。同じ活動の中は撮った順。
    static func groups(from captures: [ColorCapture]) -> [CaptureGroup] {
        // 日付は端末の時刻で数える（UTC で切ると朝の写真が前日にまざる）
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "ja_JP")
        dayFormatter.dateFormat = "yyyy-MM-dd"

        var keys: [String] = []
        var map: [String: CaptureGroup] = [:]

        // storage.captures は新しい順。古い順に見ていくと、
        // 同じ活動の中は「撮った順」に積まれる。
        for capture in captures.reversed() {
            let when = capture.sessionStartedAt ?? capture.capturedAt
            let key: String
            if let sessionID = capture.sessionID {
                key = "session:" + sessionID
            } else {
                key = "day:" + dayFormatter.string(from: capture.capturedAt)
            }

            if map[key] != nil {
                map[key]?.items.append(capture)
                if when < (map[key]?.startedAt ?? when) {
                    map[key]?.startedAt = when
                }
            } else {
                keys.append(key)
                map[key] = CaptureGroup(id: key,
                                        sessionID: capture.sessionID,
                                        mode: capture.sessionID == nil ? nil : capture.huntMode,
                                        teamNumber: capture.sessionID == nil ? nil : capture.teamNumber,
                                        level: capture.level.map { HuntDifficulty.byID($0) },
                                        limitSeconds: capture.limitSeconds,
                                        startedAt: when,
                                        items: [capture])
            }
        }

        // 新しい活動が先頭。時刻が同じときは、あとから出てきた活動を先に。
        return keys.compactMap { map[$0] }
            .sorted { lhs, rhs in
                if lhs.startedAt == rhs.startedAt { return lhs.id > rhs.id }
                return lhs.startedAt > rhs.startedAt
            }
    }
}
