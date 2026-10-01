import Combine
import Foundation

/// 1回の活動（SOLO / TEAM）の進行を持つ。
///
/// 責務はここまで:
///   - いま何をさがしているか（モード・班・担当色・難易度）
///   - 残り時間（「じかん なし」のときは数えない）
///   - この活動で保存された写真の数と id
///
/// 得点・順位・勝敗は決めない。それは教師が黒板の上で行う。
final class HuntRunService: ObservableObject {

    @Published private(set) var run: HuntRun?
    /// 残り秒数（表示用）
    @Published private(set) var remainingSeconds: Int = 0
    /// 時間切れ
    @Published private(set) var isTimeUp = false

    private var timer: Timer?
    /// 実際にさがし始めた時刻（3・2・1 のあと）。時計は実時間で数える。
    private var timingStartedAt: Date?

    deinit {
        timer?.invalidate()
    }

    // MARK: - 参照

    var isActive: Bool { run != nil }
    var isTeam: Bool { run?.mode == .team }
    var teamNumber: Int? { run?.teamNumber }
    var profile: ColorProfile? { run?.profile }
    var level: HuntDifficulty? { run?.level }
    var foundCount: Int { run?.foundCount ?? 0 }
    var captureIDs: [String] { run?.captureIDs ?? [] }
    var hasTimeLimit: Bool { run?.hasTimeLimit ?? false }

    /// 残りわずか（色を少し変えて知らせる。点滅はしない）
    var isWarning: Bool {
        hasTimeLimit && !isTimeUp && Double(remainingSeconds) <= HuntTimeOptions.warningThreshold
    }

    /// "4:32" の形
    var remainingText: String {
        let s = max(0, remainingSeconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: - 進行

    /// START を押した時点。まだ時計は動かさない。
    func start(_ newRun: HuntRun) {
        stopTimer()
        run = newRun
        remainingSeconds = Int(newRun.limitSeconds)
        isTimeUp = false
        timingStartedAt = nil
    }

    /// 3・2・1 が終わって、ほんとうにさがし始めるとき。ここから数え始める。
    /// 「じかん なし」のときは何もしない。
    func beginTiming() {
        guard let current = run, current.hasTimeLimit, timingStartedAt == nil else { return }
        timingStartedAt = Date()
        remainingSeconds = Int(current.limitSeconds)
        isTimeUp = false

        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// 写真が保存されたときに +1 する。FOUND しただけでは増えない。
    func record(_ capture: ColorCapture) {
        guard run != nil else { return }
        run?.captureIDs.append(capture.id)
    }

    /// FINISH または TIME'S UP。写真は消さない。
    func finish() {
        stopTimer()
        run?.endedAt = Date()
    }

    /// ホームに戻るときに片づける。
    func clear() {
        stopTimer()
        run = nil
        timingStartedAt = nil
        remainingSeconds = 0
        isTimeUp = false
    }

    // MARK: - 内部

    private func tick() {
        guard let current = run, let startedAt = timingStartedAt, current.endedAt == nil else { return }
        let left = current.limitSeconds - Date().timeIntervalSince(startedAt)
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
