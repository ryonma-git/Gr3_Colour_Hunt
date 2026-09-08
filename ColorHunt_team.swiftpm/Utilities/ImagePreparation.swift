import UIKit

/// 撮影したけれど、まだ保存していない1枚。
struct CapturedPhoto {
    let image: UIImage
    let jpegData: Data
}

/// 撮った写真を保存用にととのえる。
/// - 長辺を縮めて、ロイロノートへの送信と Gallery 表示を軽くする
/// - EXIF の向きを焼き込んで、どのアプリで見ても正しい向きにする
enum ImagePreparation {

    /// 保存する写真の長辺の最大ピクセル数
    static let maxPixelSize: CGFloat = 2048
    /// JPEG の画質（0...1）
    static let jpegQuality: CGFloat = 0.85

    static func prepare(_ image: UIImage) -> CapturedPhoto? {
        let resized = resized(image, maxPixel: maxPixelSize)
        guard let data = resized.jpegData(compressionQuality: jpegQuality) else { return nil }
        return CapturedPhoto(image: resized, jpegData: data)
    }

    static func resized(_ image: UIImage, maxPixel: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > 0 else { return image }

        let scale = min(1, maxPixel / longest)
        let target = CGSize(width: max(1, (size.width * scale).rounded()),
                            height: max(1, (size.height * scale).rounded()))

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
