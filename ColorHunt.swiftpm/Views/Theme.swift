import SwiftUI

/// 画面全体で使う色と文字の大きさ。
/// 小学3年生が見て分かるように、大きく・シンプルに。
enum Theme {
    static let background = Color(red: 0.98, green: 0.98, blue: 0.97)
    static let ink = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let subtle = Color(red: 0.45, green: 0.45, blue: 0.47)
    static let accent = Color(red: 0.90, green: 0.16, blue: 0.16)

    /// さがしている色が中央にあるとき
    static let matching = Color(red: 1.00, green: 0.80, blue: 0.10)
    /// みつけたとき
    static let success = Color(red: 0.18, green: 0.76, blue: 0.35)

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    static func label(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}

/// START のような、いちばん押してほしいボタン
struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.label(38))
            .foregroundColor(.white)
            .frame(maxWidth: 460)
            .frame(height: 96)
            .background(
                Capsule().fill(fill)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// MY COLORS のような、2番目のボタン
/// 暗い背景の上では tint: .white を渡す。
struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.label(30))
            .foregroundColor(tint)
            .frame(maxWidth: 460)
            .frame(height: 82)
            .background(
                Capsule().stroke(tint.opacity(0.35), lineWidth: 3)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
