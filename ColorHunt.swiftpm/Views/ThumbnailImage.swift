import ImageIO
import SwiftUI
import UIKit

/// 保存した写真を、小さく読み込んで表示する。
/// 一覧で大きな JPEG をそのまま読まないようにするためのもの。
struct ThumbnailImage: View {
    let url: URL
    var maxPixel: CGFloat = 400
    /// true: わくいっぱいに広げて切り取る（一覧むき）
    /// false: 全体が見えるように収める（大きく見るとき）
    var fillsFrame: Bool = true

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image = image {
                if fillsFrame {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            } else {
                Rectangle().fill(Color(white: 0.9))
                Image(systemName: "photo")
                    .font(.system(size: 26))
                    .foregroundColor(Theme.subtle)
            }
        }
        .clipped()
        .task(id: url) {
            image = await ThumbnailLoader.load(url: url, maxPixel: maxPixel)
        }
    }
}

enum ThumbnailLoader {
    private static let cache = NSCache<NSString, UIImage>()

    static func load(url: URL, maxPixel: CGFloat) async -> UIImage? {
        let key = url.path + "#" + String(Int(maxPixel))
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let image = makeThumbnail(url: url, maxPixel: maxPixel)
                if let image = image {
                    cache.setObject(image, forKey: key as NSString)
                }
                continuation.resume(returning: image)
            }
        }
    }

    private static func makeThumbnail(url: URL, maxPixel: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
