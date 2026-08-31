import AudioToolbox
import UIKit

/// 成功したときの控えめな手ごたえ（音・振動）。
/// iPad には振動しない機種もあるので、鳴らなくても動作に影響しないようにしてある。
enum Feedback {

    /// RED をみつけたとき
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1057) // 短い "Tink"
    }

    /// ボタンを押したとき
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
