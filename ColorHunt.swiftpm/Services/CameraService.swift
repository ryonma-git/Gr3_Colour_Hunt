import AVFoundation
import Combine
import UIKit

/// カメラの起動・プレビュー・中央の色の取り出し・写真撮影をまとめて受け持つ。
///
/// スレッドの約束:
/// - `@Published` の書き換えは必ずメインスレッド
/// - AVCaptureSession の設定・開始・停止は `sessionQueue`
/// - 映像フレームの解析は `videoQueue`
final class CameraService: NSObject, ObservableObject {

    enum Authorization: Equatable {
        case undetermined
        case authorized
        case denied
    }

    // MARK: 画面から見える状態（メインスレッドのみ）

    @Published private(set) var authorization: Authorization = .undetermined
    @Published private(set) var isSessionRunning = false
    @Published private(set) var isCapturingPhoto = false
    @Published private(set) var capturedPhoto: CapturedPhoto?
    /// 児童にも分かる言葉のエラー。nil なら問題なし。
    @Published private(set) var problemMessage: String?

    /// 中央の色が測れるたびに呼ばれる（メインスレッド）
    var onSample: ((HSVColor) -> Void)?

    let session = AVCaptureSession()

    // MARK: 内部

    private let sessionQueue = DispatchQueue(label: "com.example.colorhunt.session")
    private let videoQueue = DispatchQueue(label: "com.example.colorhunt.video")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()

    /// sessionQueue からのみ触る
    private var isConfigured = false
    /// videoQueue からのみ触る
    private var lastSampleTime: CFTimeInterval = 0
    private let sampleInterval: CFTimeInterval = 1.0 / HuntTuning.samplesPerSecond

    override init() {
        super.init()
        registerNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 開始 / 停止

    /// カメラを使い始める。権限がまだなら、ここで確認ダイアログが出る。
    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorization = .authorized
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.authorization = granted ? .authorized : .denied
                    if granted {
                        self.configureAndRun()
                    }
                }
            }
        default:
            authorization = .denied
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }

    func clearCapturedPhoto() {
        capturedPhoto = nil
    }

    // MARK: - 撮影

    /// いまのカメラ画像を1枚撮る。
    func capturePhoto(interfaceOrientation: UIInterfaceOrientation) {
        guard !isCapturingPhoto else { return }
        isCapturingPhoto = true

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.session.isRunning else {
                DispatchQueue.main.async {
                    self.isCapturingPhoto = false
                    self.problemMessage = "カメラがとまっています。もういちどためしてください。"
                }
                return
            }
            if let connection = self.photoOutput.connection(with: .video) {
                CaptureOrientation.apply(to: connection, interfaceOrientation: interfaceOrientation)
            }

            let settings: AVCapturePhotoSettings
            if self.photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            } else {
                settings = AVCapturePhotoSettings()
            }
            settings.flashMode = .off
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - セッション構成

    private func configureAndRun() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.isConfigured {
                self.configureSession()
            }
            guard self.isConfigured else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            let running = self.session.isRunning
            DispatchQueue.main.async {
                self.isSessionRunning = running
                if running {
                    self.problemMessage = nil
                }
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        var device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        if device == nil {
            device = AVCaptureDevice.default(for: .video)
        }
        guard let camera = device else {
            session.commitConfiguration()
            reportProblem("カメラが見つかりませんでした。")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            guard session.canAddInput(input) else {
                session.commitConfiguration()
                reportProblem("カメラをつかえませんでした。")
                return
            }
            session.addInput(input)
        } catch {
            session.commitConfiguration()
            reportProblem("カメラをつかえませんでした。")
            return
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()
        focusOnCenter(camera)
        isConfigured = true
    }

    /// ピントと明るさを画面中央に合わせる。中央の色を測るアプリなので効果が大きい。
    private func focusOnCenter(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            let center = CGPoint(x: 0.5, y: 0.5)
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = center
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = center
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        } catch {
            // ピント合わせができなくても撮影自体はできるので、そのまま続ける
        }
    }

    private func reportProblem(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.problemMessage = message
        }
    }

    // MARK: - 中断・エラーへの備え（Split View など）

    private func registerNotifications() {
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(handleRuntimeError(_:)),
                           name: .AVCaptureSessionRuntimeError,
                           object: session)
        center.addObserver(self,
                           selector: #selector(handleInterruption(_:)),
                           name: .AVCaptureSessionWasInterrupted,
                           object: session)
        center.addObserver(self,
                           selector: #selector(handleInterruptionEnded(_:)),
                           name: .AVCaptureSessionInterruptionEnded,
                           object: session)
    }

    @objc private func handleRuntimeError(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.isSessionRunning = false
        }
        // メディアサービスの一時的なリセットなら、自分でやり直す（授業を止めないため）
        if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError,
           error.code == .mediaServicesWereReset {
            configureAndRun()
            return
        }
        reportProblem("カメラがとまりました。ホームにもどって、もういちど START をおしてください。")
    }

    @objc private func handleInterruption(_ notification: Notification) {
        reportProblem("カメラがつかえません。ほかのアプリをとじて、もういちどためしてください。")
    }

    @objc private func handleInterruptionEnded(_ notification: Notification) {
        configureAndRun()
    }
}

// MARK: - 映像フレームから中央の色を取り出す

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastSampleTime >= sampleInterval else { return }
        lastSampleTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let hsv = CameraService.centerHSV(of: pixelBuffer, patch: HuntTuning.sampleSize) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.onSample?(hsv)
        }
    }

    /// 画面中央の小さな正方形（既定 7x7 ピクセル）の平均色を HSV で返す。
    /// 円全体ではなく、ごく狭い中央だけを見るのが Color Hunt の判定方針。
    static func centerHSV(of pixelBuffer: CVPixelBuffer, patch: Int) -> HSVColor? {
        guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA else {
            return nil
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard width > patch, height > patch, patch > 0 else { return nil }

        let half = patch / 2
        let startX = max(0, width / 2 - half)
        let endX = min(width - 1, width / 2 + half)
        let startY = max(0, height / 2 - half)
        let endY = min(height - 1, height / 2 + half)

        let pointer = base.assumingMemoryBound(to: UInt8.self)
        var sumB = 0
        var sumG = 0
        var sumR = 0
        var count = 0

        for y in startY...endY {
            let row = pointer + y * bytesPerRow
            for x in startX...endX {
                let pixel = row + x * 4        // BGRA
                sumB += Int(pixel[0])
                sumG += Int(pixel[1])
                sumR += Int(pixel[2])
                count += 1
            }
        }
        guard count > 0 else { return nil }

        let divisor = Double(count) * 255.0
        return RGBHSVConversion.hsv(r: Double(sumR) / divisor,
                                    g: Double(sumG) / divisor,
                                    b: Double(sumB) / divisor)
    }
}

// MARK: - 写真ができあがったとき

extension CameraService: AVCapturePhotoCaptureDelegate {

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        var prepared: CapturedPhoto?
        if error == nil,
           let data = photo.fileDataRepresentation(),
           let image = UIImage(data: data) {
            prepared = ImagePreparation.prepare(image)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isCapturingPhoto = false
            if let photo = prepared {
                self.capturedPhoto = photo
            } else {
                self.problemMessage = "しゃしんをとれませんでした。もういちどためしてください。"
            }
        }
    }
}
