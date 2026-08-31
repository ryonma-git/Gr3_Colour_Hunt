import Foundation

/// RGB と HSV の相互変換。
///
/// カメラのピクセル値（sRGB, 0...1）をそのまま入力する。
/// 厳密な色彩測定用ではなく、教室で使える程度の実用変換。
enum RGBHSVConversion {

    /// RGB(各 0...1) → HSV(H:0...360, S:0...1, V:0...1)
    static func hsv(r: Double, g: Double, b: Double) -> HSVColor {
        let rr = clamp01(r)
        let gg = clamp01(g)
        let bb = clamp01(b)

        let maxValue = max(rr, gg, bb)
        let minValue = min(rr, gg, bb)
        let delta = maxValue - minValue

        var hue: Double = 0
        if delta > 1e-6 {
            if maxValue == rr {
                hue = 60 * ((gg - bb) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxValue == gg {
                hue = 60 * (((bb - rr) / delta) + 2)
            } else {
                hue = 60 * (((rr - gg) / delta) + 4)
            }
        }
        if hue < 0 { hue += 360 }
        if hue >= 360 { hue -= 360 }

        let saturation = maxValue <= 1e-6 ? 0 : delta / maxValue
        return HSVColor(h: hue, s: saturation, v: maxValue)
    }

    /// HSV → RGB(各 0...1)。UI の色見本づくりなどに使う。
    static func rgb(_ hsv: HSVColor) -> (r: Double, g: Double, b: Double) {
        let h = hsv.h.truncatingRemainder(dividingBy: 360) / 60
        let s = clamp01(hsv.s)
        let v = clamp01(hsv.v)

        let c = v * s
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c

        let rgb: (Double, Double, Double)
        switch Int(h.rounded(.down)) {
        case 0: rgb = (c, x, 0)
        case 1: rgb = (x, c, 0)
        case 2: rgb = (0, c, x)
        case 3: rgb = (0, x, c)
        case 4: rgb = (x, 0, c)
        default: rgb = (c, 0, x)
        }
        return (rgb.0 + m, rgb.1 + m, rgb.2 + m)
    }

    private static func clamp01(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
