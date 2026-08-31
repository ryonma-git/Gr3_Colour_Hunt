import AVFoundation
import UIKit

/// カメラの映像の向きをそろえるためのヘルパー。
///
/// iOS 17 以降は `videoRotationAngle`、iOS 16 では `videoOrientation` を使う。
/// 古い API の呼び出しは deprecated 指定した関数の中に閉じ込めてあるので、
/// ビルド警告は出ない。
enum CaptureOrientation {

    static func apply(to connection: AVCaptureConnection,
                      interfaceOrientation: UIInterfaceOrientation) {
        if #available(iOS 17.0, *) {
            let angle = rotationAngle(for: interfaceOrientation)
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        } else {
            applyLegacy(to: connection, interfaceOrientation: interfaceOrientation)
        }
    }

    /// 画面の向きを取り出す。取れないときは Portrait 扱い。
    static func interfaceOrientation(for view: UIView?) -> UIInterfaceOrientation {
        view?.window?.windowScene?.interfaceOrientation ?? .portrait
    }

    @available(iOS 17.0, *)
    private static func rotationAngle(for orientation: UIInterfaceOrientation) -> CGFloat {
        switch orientation {
        case .landscapeLeft: return 180
        case .landscapeRight: return 0
        case .portraitUpsideDown: return 270
        default: return 90
        }
    }

    @available(iOS, deprecated: 17.0, message: "iOS 16 用のフォールバック")
    private static func applyLegacy(to connection: AVCaptureConnection,
                                    interfaceOrientation: UIInterfaceOrientation) {
        guard connection.isVideoOrientationSupported else { return }
        switch interfaceOrientation {
        case .landscapeLeft: connection.videoOrientation = .landscapeLeft
        case .landscapeRight: connection.videoOrientation = .landscapeRight
        case .portraitUpsideDown: connection.videoOrientation = .portraitUpsideDown
        default: connection.videoOrientation = .portrait
        }
    }
}
