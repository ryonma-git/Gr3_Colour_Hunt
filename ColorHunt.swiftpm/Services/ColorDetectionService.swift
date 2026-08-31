import Combine
import QuartzCore

/// 「いま画面中央にある色が、さがしている色かどうか」を判定する。
///
/// 一瞬だけ条件に入っただけでは成功にしない。
/// `HuntTuning.stableDuration` 秒つづけて条件を満たしたときに `.found` になる。
///
/// 逆に、`.found` のあとで対象の色から `HuntTuning.foundReleaseDuration` 秒つづけて
/// 外れたら `.searching` に戻す。カメラを別のものに向ければ、また探し直せる。
final class ColorDetectionService: ObservableObject {

    enum Phase: Equatable {
        case searching
        case found
    }

    // MARK: 画面から見える状態

    @Published private(set) var phase: Phase = .searching
    /// いまこの瞬間、条件を満たしているか（ターゲットの色を変えるのに使う）
    @Published private(set) var isMatchingNow = false
    /// `.found` になった瞬間に測れていた色。保存データに残す。
    @Published private(set) var foundHSV: HSVColor?

    /// いまさがしている色。将来はここを差し替えるだけで別の色になる。
    @Published var activeProfile: ColorProfile

    /// 開発用の数値表示。児童用UIでは必ず false。
    @Published var isDebugEnabled = false
    @Published private(set) var debugHSV: HSVColor?

    // MARK: 内部

    /// 連続して一致し始めた時刻
    private var matchStartedAt: CFTimeInterval?
    /// 連続して外れ始めた時刻
    private var mismatchStartedAt: CFTimeInterval?
    private var isPaused = true

    init(profile: ColorProfile) {
        self.activeProfile = profile
    }

    // MARK: - 操作

    /// 次にさがす色をランダムに決める。直前と同じ色は出ない。判定もやり直す。
    /// START のときと、「つぎを さがす」を押したときに呼ぶ。
    func pickNextColor() {
        activeProfile = ColorProfile.randomHuntColor(excluding: activeProfile)
        reset()
    }

    /// 判定を最初からやり直す（カウントダウン前・撮り直しのとき）
    func reset() {
        phase = .searching
        isMatchingNow = false
        foundHSV = nil
        matchStartedAt = nil
        mismatchStartedAt = nil
    }

    func pause() {
        isPaused = true
        isMatchingNow = false
        matchStartedAt = nil
        mismatchStartedAt = nil
    }

    func resume() {
        isPaused = false
        matchStartedAt = nil
        mismatchStartedAt = nil
    }

    /// カメラから届いた中央の色を1回分うけとる（メインスレッド）
    func ingest(_ hsv: HSVColor) {
        if isDebugEnabled {
            debugHSV = hsv
        }
        guard !isPaused else { return }

        let now = CACurrentMediaTime()
        let matches = activeProfile.matches(hsv)

        if matches {
            mismatchStartedAt = nil
            if matchStartedAt == nil {
                matchStartedAt = now
            }
            if !isMatchingNow {
                isMatchingNow = true
            }
            if phase == .searching,
               let start = matchStartedAt,
               now - start >= HuntTuning.stableDuration {
                foundHSV = hsv
                phase = .found
            }
        } else {
            if mismatchStartedAt == nil {
                mismatchStartedAt = now
            }
            let offDuration = now - (mismatchStartedAt ?? now)

            // 少しの手ぶれで判定が切れないように、わずかな猶予をもたせる
            guard offDuration >= HuntTuning.releaseGrace else { return }

            matchStartedAt = nil
            if isMatchingNow {
                isMatchingNow = false
            }

            // 対象の色から外れつづけたら「みつけた」を解除して、
            // また別のものを探し始められるようにする（みつけるのと同じ時間で対称）
            if phase == .found, offDuration >= HuntTuning.foundReleaseDuration {
                phase = .searching
                foundHSV = nil
            }
        }
    }
}
