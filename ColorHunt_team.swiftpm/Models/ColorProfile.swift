import SwiftUI

// ============================================================================
//  Color Hunt の「色の定義」と「判定のチューニング」は、すべてこのファイルにある。
//  色の判定がきびしすぎる／ゆるすぎるときは、このファイルだけを直せばよい。
//  （詳しくは README.md「7. 色の判定値の調整場所」を参照）
//
//  Web 版 (web/js/colors.js) と同じ数値。片方を変えたらもう片方も合わせること。
//
//  profileVersion 2（2026-09-14）: 授業で PURPLE・YELLOW などが反応しにくかったので、
//  外れていた境界をゆるめた。ORANGE だけは変更なし。
// ============================================================================

/// 0...1 の値がこの範囲に入っているかを判定する。
struct ValueRange: Codable, Hashable {
    var lower: Double
    var upper: Double

    init(_ lower: Double, _ upper: Double) {
        self.lower = lower
        self.upper = upper
    }

    func contains(_ value: Double) -> Bool {
        value >= lower && value <= upper
    }
}

/// 色相（0...360度）の範囲。
/// `from > to` の場合は 360度をまたぐ範囲として扱う（例: 345 → 15）。
struct HueRange: Codable, Hashable {
    var from: Double
    var to: Double

    init(_ from: Double, _ to: Double) {
        self.from = from
        self.to = to
    }

    func contains(_ hue: Double) -> Bool {
        let h = hue.truncatingRemainder(dividingBy: 360)
        let normalized = h < 0 ? h + 360 : h
        if from <= to {
            return normalized >= from && normalized <= to
        } else {
            return normalized >= from || normalized <= to
        }
    }
}

/// 色相・彩度・明度の範囲の組。
/// ふつうは ColorProfile 本体の範囲だけで足りる。
/// PINK のように「2つの範囲の合わせ技」にしたい色だけ `extraRegions` に足す。
struct ColorRegion: Codable, Hashable {
    var hueRanges: [HueRange]
    var saturationRange: ValueRange
    var brightnessRange: ValueRange

    func contains(_ hsv: HSVColor) -> Bool {
        guard saturationRange.contains(hsv.s) else { return false }
        guard brightnessRange.contains(hsv.v) else { return false }
        return hueRanges.contains { $0.contains(hsv.h) }
    }
}

/// 将来の難易度分け（今回は basic のみ使用）
enum ColorDifficulty: String, Codable, Hashable {
    case basic
    case advanced
    case expert
}

/// UI 表示のための色見本（判定には使わない）
struct RGBTriple: Codable, Hashable {
    var r: Double
    var g: Double
    var b: Double
}

/// 探す色ひとつ分の定義。
///
/// 判定条件は Hue だけに依存させない。
/// Saturation / Brightness も条件に含めているので、将来
/// ORANGE と BROWN のように「色相が近く明るさで分かれる色」も
/// このモデルのまま表現できる（README「将来拡張の考え方」参照）。
struct ColorProfile: Identifiable, Codable, Hashable {
    /// 保存データ用の識別子（例: "red"）
    let id: String
    /// 画面に大きく出す英語表記（例: "RED"）
    let displayName: String
    /// 読み上げるときの文字列（例: "Red"）
    let speechText: String

    /// 色相の許容範囲（複数指定できる）
    var hueRanges: [HueRange]
    /// 彩度の許容範囲
    var saturationRange: ValueRange
    /// 明度の許容範囲
    var brightnessRange: ValueRange
    /// 追加の範囲。どれか1つに入っていれば一致とみなす。ほとんどの色は空。
    var extraRegions: [ColorRegion] = []

    var difficulty: ColorDifficulty
    /// 判定条件を変更したら +1 する。保存データにも記録される。
    var profileVersion: Int

    /// UI の色（判定には無関係）
    var tint: RGBTriple

    /// 中央の色がこのプロファイルの条件を満たすか（どれか1つの範囲に入っていればよい）。
    func matches(_ hsv: HSVColor) -> Bool {
        let primary = ColorRegion(hueRanges: hueRanges,
                                  saturationRange: saturationRange,
                                  brightnessRange: brightnessRange)
        if primary.contains(hsv) { return true }
        return extraRegions.contains { $0.contains(hsv) }
    }

    var displayColor: Color {
        Color(red: tint.r, green: tint.g, blue: tint.b)
    }

    /// 白い背景に文字として置いても読める色。
    /// YELLOW のように明るい色は暗くして使う（色だけに頼らないための下地）。
    var readableColor: Color {
        let hsv = RGBHSVConversion.hsv(r: tint.r, g: tint.g, b: tint.b)
        guard hsv.v > 0.72 && hsv.s > 0.20 else { return displayColor }
        let darker = RGBHSVConversion.rgb(HSVColor(h: hsv.h, s: min(1, hsv.s * 1.05), v: 0.60))
        return Color(red: darker.r, green: darker.g, blue: darker.b)
    }
}

// MARK: - 色のカタログ

extension ColorProfile {

    // ------------------------------------------------------------------
    //  ★ 色の判定条件はここだけ。ここを直せば判定の広さが変わる。
    //
    //  ゆるくしたい（もっと成功しやすく）→ saturationRange / brightnessRange の
    //    下限を下げる、hueRanges を広げる
    //  きびしくしたい（別の物を拾ってしまう）→ 逆に上げる／せばめる
    //
    //  変更したら profileVersion を +1 しておくと、
    //  あとから library.json を見て「どの条件で撮ったか」が分かる。
    // ------------------------------------------------------------------

    static let red = ColorProfile(
        id: "red",
        displayName: "RED",
        speechText: "Red",
        hueRanges: [
            HueRange(340, 360),
            HueRange(0, 14)
        ],
        saturationRange: ValueRange(0.45, 1.0),   // これ未満は「肌」や「ピンク」
        brightnessRange: ValueRange(0.20, 1.0),
        difficulty: .basic,
        profileVersion: 2,
        tint: RGBTriple(r: 0.90, g: 0.16, b: 0.16)
    )

    static let orange = ColorProfile(
        id: "orange",
        displayName: "ORANGE",
        speechText: "Orange",
        hueRanges: [HueRange(16, 44)],
        saturationRange: ValueRange(0.65, 1.0),   // 木の机・肌をはじくため高め
        brightnessRange: ValueRange(0.50, 1.0),
        difficulty: .basic,
        profileVersion: 1,
        tint: RGBTriple(r: 0.95, g: 0.52, b: 0.10)
    )

    static let yellow = ColorProfile(
        id: "yellow",
        displayName: "YELLOW",
        speechText: "Yellow",
        hueRanges: [HueRange(40, 75)],            // 山吹色からテニスボールの黄色まで
        saturationRange: ValueRange(0.28, 1.0),   // 光って白っぽく写った黄色も通す
        brightnessRange: ValueRange(0.45, 1.0),   // 影の黄色も通す（これより暗いとオリーブ色）
        difficulty: .basic,
        profileVersion: 2,
        tint: RGBTriple(r: 0.97, g: 0.78, b: 0.10)
    )

    static let green = ColorProfile(
        id: "green",
        displayName: "GREEN",
        speechText: "Green",
        hueRanges: [HueRange(70, 175)],           // 黄緑から青緑まで
        saturationRange: ValueRange(0.20, 1.0),   // うすい緑も通す
        brightnessRange: ValueRange(0.15, 1.0),   // 黒板の濃い緑も通す
        difficulty: .basic,
        profileVersion: 2,
        tint: RGBTriple(r: 0.18, g: 0.70, b: 0.33)
    )

    static let blue = ColorProfile(
        id: "blue",
        displayName: "BLUE",
        speechText: "Blue",
        hueRanges: [HueRange(180, 250)],          // ターコイズから紺色まで
        saturationRange: ValueRange(0.22, 1.0),   // うすい水色（空色）も通す
        brightnessRange: ValueRange(0.18, 1.0),   // 紺色も通す
        difficulty: .basic,
        profileVersion: 2,
        tint: RGBTriple(r: 0.13, g: 0.42, b: 0.90)
    )

    static let purple = ColorProfile(
        id: "purple",
        displayName: "PURPLE",
        speechText: "Purple",
        hueRanges: [HueRange(245, 325)],          // カメラで青っぽく写る紫から赤むらさきまで
        saturationRange: ValueRange(0.18, 1.0),   // ラベンダーなど、うすい紫も通す
        brightnessRange: ValueRange(0.22, 1.0),   // S を下げたぶん、黒い服を拾わないよう少し上げた
        difficulty: .basic,
        profileVersion: 2,
        tint: RGBTriple(r: 0.55, g: 0.30, b: 0.78)
    )

    /// PINK は2つの範囲の合わせ技。色相だけに頼らない設計が効いている例。
    /// ① 赤と同じ色相の「うすい赤」（ももいろ）。こい赤は RED なので S は 0.70 まで。
    /// ② 赤むらさき寄りの色相の「こいピンク」（ピンクのペンなど）。
    ///    この色相に RED は無いので、S の上限をなくした。
    static let pink = ColorProfile(
        id: "pink",
        displayName: "PINK",
        speechText: "Pink",
        hueRanges: [
            HueRange(340, 360),
            HueRange(0, 8)
        ],
        saturationRange: ValueRange(0.15, 0.70),  // 0.70 より濃いものは RED 扱い
        brightnessRange: ValueRange(0.60, 1.0),   // 暗いピンクは無い
        extraRegions: [
            ColorRegion(hueRanges: [HueRange(300, 340)],
                        saturationRange: ValueRange(0.15, 1.0),
                        brightnessRange: ValueRange(0.60, 1.0))
        ],
        difficulty: .basic,
        profileVersion: 2,
        tint: RGBTriple(r: 0.95, g: 0.45, b: 0.65)
    )

    /// TEAM HUNT の8班目で使う色。
    ///
    /// BROWN は「暗い / くすんだ ORANGE」なので、色相だけでは分けられない。
    /// ORANGE を S 0.65以上に限っているのに対し、BROWN は S 0.38〜0.70・V 0.85以下
    /// という「鮮やかすぎない・明るすぎない」条件で分けている（0.65〜0.70 は両方に入る）。
    /// 木の机・床・段ボール・茶色い筆箱が通ることを優先した。
    ///
    /// ※ 注意: 茶色は肌の色と HSV 上でどうしても重なる。
    ///   明るい手のひら（S 0.30 前後）は S の下限 0.38 ではじけるが、
    ///   暗めの肌は BROWN の範囲に入る。HSV では原理的に分離できない。
    ///   授業前に「人ではなく物をさがす」と一言添えるのが現実的な対処。
    ///   きびしくしたい場合は saturationRange の下限を 0.45 に上げる
    ///   （そのぶん段ボールなど薄い茶色が通らなくなる）。
    static let brown = ColorProfile(
        id: "brown",
        displayName: "BROWN",
        speechText: "Brown",
        hueRanges: [HueRange(10, 45)],            // 赤みの茶色も通す
        saturationRange: ValueRange(0.38, 0.70),  // 0.38 未満は肌 / 0.70 より鮮やかなら ORANGE
        brightnessRange: ValueRange(0.18, 0.85),  // 明るすぎるものは ORANGE / 肌
        difficulty: .advanced,
        profileVersion: 2,
        tint: RGBTriple(r: 0.51, g: 0.36, b: 0.21)
    )

    /// アプリが知っている色すべて。Gallery の並び順にも使う。
    static let catalog: [ColorProfile] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink, .brown
    ]

    /// ★ SOLO HUNT でランダム出題する色。ここを減らせば、その色だけが出る。
    ///   例: 最初の授業は3色だけにする
    ///       static let huntColors: [ColorProfile] = [.red, .blue, .yellow]
    ///
    ///   BROWN は入れていない。TEAM HUNT の8班目でだけ使う色で、
    ///   ひとりで探すには難しく、肌の色とも重なりやすいため。
    ///   SOLO でも出したいときは末尾に .brown を足す。
    static let huntColors: [ColorProfile] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink
    ]

    /// 次に出す色をランダムに選ぶ。直前と同じ色は選ばない。
    static func randomHuntColor(excluding current: ColorProfile?) -> ColorProfile {
        let pool = huntColors.filter { $0.id != current?.id }
        if let next = pool.randomElement() { return next }
        return huntColors.first ?? .red
    }

    /// 保存データの `targetColor` から色定義を引く。
    static func profile(id: String) -> ColorProfile? {
        catalog.first { $0.id == id }
    }
}

// MARK: - 判定のチューニング

/// 色の範囲以外の調整値。README の指示でここだけ触ればよいようにまとめてある。
enum HuntTuning {
    /// 画面中央から取り出す正方形の一辺（ピクセル）。5〜9 くらいで調整する。
    static let sampleSize: Int = 7

    /// 色を調べる回数（1秒あたり）。多くしすぎない。
    static let samplesPerSecond: Double = 12

    /// 何秒間つづけて条件を満たしたら「みつけた」にするか。
    static let stableDuration: TimeInterval = 0.5

    /// 手ぶれ対策。この秒数だけ外れても、まだ「あたり続けている」とみなす。
    static let releaseGrace: TimeInterval = 0.2

    /// みつけた状態（緑）を解除するまでの時間。
    /// 対象の色から外れ続けた時間がこれを超えると、また別のものを探し始められる。
    /// みつける時間（0.5秒）より少し長くして、シャッターを押すときに
    /// カメラが動いても緑が消えにくくしてある（2026-09-14 の授業のようすから）。
    /// まだ早いときは 1.0、みつける時間とそろえたいときは stableDuration にする。
    static let foundReleaseDuration: TimeInterval = 0.8
}
