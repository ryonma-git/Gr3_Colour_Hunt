import SwiftUI
import UIKit

/// ロイロノートへの共有は iOS 標準の共有シートを使う（専用APIは使わない）。
enum ShareService {

    enum Style {
        /// RED と "I found RED." を入れた発表用の1枚（既定）
        case presentationCard
        /// 撮った写真そのまま
        case photoOnly
    }

    /// 送る画像の種類。写真そのままを送りたいときは .photoOnly に変える。
    static var style: Style = .presentationCard

    /// 共有用のファイルを一時フォルダに作って、その URL を返す。
    /// 何かに失敗したら、もとの写真をそのまま共有する。
    static func makeShareURL(for capture: ColorCapture,
                             imageURL: URL,
                             profile: ColorProfile?) -> URL {
        guard let original = UIImage(contentsOfFile: imageURL.path) else {
            return imageURL
        }

        var image = original
        if style == .presentationCard,
           let card = presentationCard(photo: original, capture: capture, profile: profile) {
            image = card
        }

        guard let data = image.jpegData(compressionQuality: 0.9) else {
            return imageURL
        }

        let stamp = fileStamp(for: capture.capturedAt)
        let name = "ColorHunt_\(capture.displayName)_\(stamp).jpg"
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: destination, options: .atomic)
            return destination
        } catch {
            return imageURL
        }
    }

    // MARK: - 発表用の1枚をつくる

    private static func presentationCard(photo: UIImage,
                                        capture: ColorCapture,
                                        profile: ColorProfile?) -> UIImage? {
        let canvas = CGSize(width: 1200, height: 1560)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let accent: UIColor
        if let profile = profile {
            accent = UIColor(red: profile.tint.r, green: profile.tint.g, blue: profile.tint.b, alpha: 1)
        } else {
            accent = UIColor.label
        }

        let renderer = UIGraphicsImageRenderer(size: canvas, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: canvas))

            // 上: 色の名前
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: font(size: 150, weight: .heavy),
                .foregroundColor: accent
            ]
            let title = capture.displayName as NSString
            let titleSize = title.size(withAttributes: titleAttributes)
            title.draw(at: CGPoint(x: (canvas.width - titleSize.width) / 2, y: 60),
                       withAttributes: titleAttributes)

            // 中: 写真（縦横比を保って収める）
            let box = CGRect(x: 60, y: 250, width: 1080, height: 1080)
            UIColor(white: 0.94, alpha: 1).setFill()
            context.fill(box)
            let fitted = aspectFit(size: photo.size, in: box)
            photo.draw(in: fitted)

            // 下: 発表のことば
            let captionAttributes: [NSAttributedString.Key: Any] = [
                .font: font(size: 82, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            let caption = "I found \(capture.displayName)." as NSString
            let captionSize = caption.size(withAttributes: captionAttributes)
            caption.draw(at: CGPoint(x: (canvas.width - captionSize.width) / 2, y: 1390),
                         withAttributes: captionAttributes)
        }
    }

    private static func font(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let descriptor = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return base
    }

    private static func aspectFit(size: CGSize, in box: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return box }
        let scale = min(box.width / size.width, box.height / size.height)
        let width = size.width * scale
        let height = size.height * scale
        return CGRect(x: box.midX - width / 2,
                      y: box.midY - height / 2,
                      width: width,
                      height: height)
    }

    private static func fileStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter.string(from: date)
    }
}

// MARK: - SwiftUI から共有シートを開く

/// `UIActivityViewController` を SwiftUI の .sheet で使うためのラッパー。
/// ロイロノートが入っていれば、共有先の一覧に出てくる。
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onFinish: (() -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let finish = onFinish
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            finish?()
        }
        // iPad でポップオーバー表示になった場合の保険
        controller.popoverPresentationController?.permittedArrowDirections = []
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// `.sheet(item:)` で共有シートを出すための入れもの。
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
