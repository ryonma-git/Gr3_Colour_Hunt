import AVFoundation
import SwiftUI
import UIKit

/// AVCaptureVideoPreviewLayer を SwiftUI で表示する。
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    /// 画面の向きが変わったときに知らせる（撮影する写真の向きをそろえるため）
    var onOrientationChange: ((UIInterfaceOrientation) -> Void)?

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onOrientationChange = onOrientationChange
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
        uiView.onOrientationChange = onOrientationChange
    }

    final class PreviewContainerView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        // swiftlint:disable:next force_cast
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        var onOrientationChange: ((UIInterfaceOrientation) -> Void)?
        private var lastOrientation: UIInterfaceOrientation?

        override func layoutSubviews() {
            super.layoutSubviews()
            let orientation = CaptureOrientation.interfaceOrientation(for: self)
            if let connection = previewLayer.connection {
                CaptureOrientation.apply(to: connection, interfaceOrientation: orientation)
            }
            guard lastOrientation != orientation else { return }
            lastOrientation = orientation
            // レイアウト中に SwiftUI の状態を変えないよう、次のループで伝える
            DispatchQueue.main.async { [weak self] in
                self?.onOrientationChange?(orientation)
            }
        }
    }
}
