import Combine
import Foundation

/// TEAM HUNT ひとつ分の進行を持つ。
///
/// 責務はここまで:
///   - どの班がどの色を担当しているか
///   - 残り時間（5分）
///   - この活動で正式保存された写真の数と id
///
/// 得点・順位・勝敗は決めない。それは教師が黒板の上で行う。
final class TeamHuntService: ObservableObject {

    @Published private(set) var session: TeamHuntSession?
    /// 残り秒数（表示用）
    @Published private(set) var remainingSeconds: Int = Int(TeamHuntConfiguration.duration)
    /// 5分たった
    @Published private(set) var isTimeUp = false

    private var timer: Timer?
    /// 実際にさがし始めた時刻（3・2・1 のあと）。時計は実時間で数える。
    private var timingStartedAt: Date?

    deinit {
        timer?.invalidate()
    }

    // MARK: - 参照

    var isActive: Bool { session != nil }
    var teamNumber: Int? { session?.teamNumber }
    var profile: ColorProfile? { session?.profile }
    var foundCount: Int { session?.foundCount ?? 0 }
    var captureIDs: [String] { session?.captureIDs ?? [] }

    /// 残りわずか（色を少し変えて知らせる。点滅はしない）
    var isWarning: Bool {
        !isTimeUp && Double(remainingSeconds) <= TeamHuntConfiguration.warningThreshold
    }

    /// "4:32" の形
    var remainingText: String {
        let s = max(0, remainingSeconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: - 進行

    /// 班をえらんだ時点。まだ時計は動かさない。
    func start(teamNumber: Int, profile: ColorProfile) {
        stopTimer()
        session = TeamHuntSession(teamNumber: teamNumber, profile: profile)
        remainingSeconds = Int(TeamHuntConfiguration.duration)
        isTimeUp = false
        timingStartedAt = nil
    }

    /// 3・2・1 が終わって、ほんとうにさがし始めるとき。ここから5分。
    func beginTiming() {
        guard session != nil, timingStartedAt == nil else { return }
        timingStartedAt = Date()
        remainingSeconds = Int(TeamHuntConfiguration.duration)
        isTimeUp = false

        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// 「この しゃしんに する」で正式保存されたときに +1 する。
    /// FOUND しただけ・とりなおしただけでは増えない。
    func record(_ capture: ColorCapture) {
        guard session != nil else { return }
        session?.captureIDs.append(capture.id)
    }

    /// FINISH または TIME'S UP。写真は消さない。
    func finish() {
        stopTimer()
        session?.endedAt = Date()
    }

    /// ホームに戻るときに片づける。
    func clear() {
        stopTimer()
        session = nil
        timingStartedAt = nil
        remainingSeconds = Int(TeamHuntConfiguration.duration)
        isTimeUp = false
    }

    // MARK: - 内部

    private func tick() {
        guard let startedAt = timingStartedAt, session?.endedAt == nil else { return }
        let left = TeamHuntConfiguration.duration - Date().timeIntervalSince(startedAt)
        let secs = Int(max(0, left).rounded(.up))
        if secs != remainingSeconds {
            remainingSeconds = secs
        }
        if left <= 0 && !isTimeUp {
            isTimeUp = true
            stopTimer()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
