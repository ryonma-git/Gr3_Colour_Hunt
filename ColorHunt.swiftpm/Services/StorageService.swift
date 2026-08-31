import Combine
import Foundation

/// 写真と library.json の保存・読み込み。
///
/// 保存先の考え方:
/// - 本当の保存場所は「ファイル」アプリから見えるフォルダ（Color Hunt/）
/// - アプリを作り直しても、そのフォルダを選び直せば作品はもどってくる
/// - フォルダが未設定・使えないときだけ、アプリの中に一時的に保存する（写真を失わないため）
///
/// このクラスのメソッドはすべてメインスレッドから呼ぶこと。
final class StorageService: ObservableObject {

    enum LocationKind: Equatable {
        /// 「ファイル」アプリの中のフォルダ（表示名つき）
        case external(String)
        /// アプリの中（フォルダ未設定のときの逃げ道）
        case appInternal
    }

    // MARK: 定数

    static let folderName = "Color Hunt"
    static let libraryFileName = "library.json"
    static let photosDirectoryName = "photos"

    private static let bookmarkKey = "ColorHunt.libraryFolderBookmark"
    private static let subfolderKey = "ColorHunt.libraryFolderSubfolder"
    private static let skipSetupKey = "ColorHunt.didSkipFolderSetup"

    // MARK: 画面から見える状態

    @Published private(set) var captures: [ColorCapture] = []
    @Published private(set) var locationKind: LocationKind = .appInternal
    /// 一度もフォルダを選んでいない／選び直しが必要
    @Published private(set) var needsFolderSelection = true
    @Published var lastErrorMessage: String?

    private(set) var libraryRoot: URL
    private var scopedURL: URL?

    init() {
        libraryRoot = StorageService.internalRoot()
    }

    deinit {
        scopedURL?.stopAccessingSecurityScopedResource()
    }

    // MARK: - 起動時

    /// 前回選んだフォルダを開き直す。だめならアプリの中を使う。
    func bootstrap() {
        if restoreBookmarkedFolder() { return }
        useInternalStorage(needsSelection: true)
    }

    // MARK: - フォルダの選択

    /// 「ファイル」アプリで選ばれたフォルダを保存先にする。
    ///
    /// - 選んだフォルダに library.json があれば、そこをそのままライブラリとして開く（＝過去データの復元）
    /// - なければ、その中に "Color Hunt" フォルダを作って使う
    @discardableResult
    func adoptFolder(_ picked: URL) -> Bool {
        // security-scoped でない URL でも、そのまま読み書きできることがある。
        // スコープが取れなかっただけで諦めず、実際に書けるかどうかで判断する。
        let didStartScope = picked.startAccessingSecurityScopedResource()

        let fileManager = FileManager.default
        let directLibrary = picked.appendingPathComponent(StorageService.libraryFileName)
        let root: URL
        var subfolder = ""
        if fileManager.fileExists(atPath: directLibrary.path)
            || picked.lastPathComponent == StorageService.folderName {
            root = picked
        } else {
            root = picked.appendingPathComponent(StorageService.folderName, isDirectory: true)
            subfolder = StorageService.folderName
        }

        guard prepareDirectories(at: root) else {
            if didStartScope {
                picked.stopAccessingSecurityScopedResource()
            }
            lastErrorMessage = "そのばしょには ほぞんできませんでした。べつの ばしょを えらんでください。"
            return false
        }

        // ここまで来たら使える。前のスコープを1回だけ閉じて入れ替える
        let previous = scopedURL
        if let previous = previous {
            previous.stopAccessingSecurityScopedResource()
        }
        scopedURL = didStartScope ? picked : nil

        libraryRoot = root
        locationKind = .external(StorageService.displayName(for: root))
        needsFolderSelection = false
        UserDefaults.standard.set(false, forKey: StorageService.skipSetupKey)
        saveBookmark(for: picked, subfolder: subfolder)
        loadLibrary()
        return true
    }

    /// 起動時に保存先の画面を自動で出すかどうか。
    /// 一度「ほぞん せず はじめる」を選んだら、毎回は出さない（授業を止めないため）。
    var shouldPromptFolderSetup: Bool {
        needsFolderSelection && !UserDefaults.standard.bool(forKey: StorageService.skipSetupKey)
    }

    /// 「ほぞん せず はじめる」。フォルダを決めずに授業を始める。
    /// 写真はアプリの中に残るが、アプリを作り直すと消える。
    func startWithoutFolder() {
        UserDefaults.standard.set(true, forKey: StorageService.skipSetupKey)
        useInternalStorage(needsSelection: true)
    }

    /// フォルダを選ばずに進むとき（授業を止めないための逃げ道）
    func useInternalStorage(needsSelection: Bool) {
        if let scoped = scopedURL {
            scoped.stopAccessingSecurityScopedResource()
            scopedURL = nil
        }
        libraryRoot = StorageService.internalRoot()
        _ = prepareDirectories(at: libraryRoot)
        locationKind = .appInternal
        needsFolderSelection = needsSelection
        loadLibrary()
    }

    // MARK: - 保存 / 削除

    /// 「この写真にする」で呼ばれる。JPG と library.json の両方を更新する。
    func save(photo: CapturedPhoto, profile: ColorProfile, hsv: HSVColor) -> ColorCapture? {
        let identifier = UUID().uuidString
        let fileName = identifier + ".jpg"
        let relativePath = StorageService.photosDirectoryName + "/" + fileName
        let photosDirectory = libraryRoot.appendingPathComponent(StorageService.photosDirectoryName,
                                                                isDirectory: true)
        let photoURL = photosDirectory.appendingPathComponent(fileName)

        do {
            try FileManager.default.createDirectory(at: photosDirectory,
                                                    withIntermediateDirectories: true)
            try photo.jpegData.write(to: photoURL, options: .atomic)
        } catch {
            lastErrorMessage = "しゃしんをほぞんできませんでした。ほぞんさきをたしかめてください。"
            return nil
        }

        let capture = ColorCapture(id: identifier,
                                   targetColor: profile.id,
                                   displayName: profile.displayName,
                                   imageFile: relativePath,
                                   capturedAt: Date(),
                                   difficulty: profile.difficulty.rawValue,
                                   colorProfileVersion: profile.profileVersion,
                                   sampledHSV: hsv)

        captures.insert(capture, at: 0)
        guard writeLibrary() else {
            // JSON が書けなかったら写真も消して、食い違いを残さない
            try? FileManager.default.removeItem(at: photoURL)
            captures.removeAll { $0.id == identifier }
            lastErrorMessage = "ほぞんできませんでした。ほぞんさきをえらびなおしてください。"
            return nil
        }
        return capture
    }

    /// 画像ファイルと library.json の両方から消す。
    func delete(_ capture: ColorCapture) {
        try? FileManager.default.removeItem(at: imageURL(for: capture))
        captures.removeAll { $0.id == capture.id }
        if !writeLibrary() {
            lastErrorMessage = "けすことはできましたが、ほぞんデータの こうしんに しっぱいしました。"
        }
    }

    // MARK: - 参照

    func imageURL(for capture: ColorCapture) -> URL {
        libraryRoot.appendingPathComponent(capture.imageFile)
    }

    func captures(for profileID: String) -> [ColorCapture] {
        captures.filter { $0.targetColor == profileID }
    }

    var locationDescription: String {
        switch locationKind {
        case .external(let name):
            return name
        case .appInternal:
            return "アプリの中（フォルダ未せってい）"
        }
    }

    var isUsingExternalFolder: Bool {
        if case .external = locationKind { return true }
        return false
    }

    // MARK: - 内部処理

    private static func internalRoot() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(folderName, isDirectory: true)
    }

    private static func displayName(for url: URL) -> String {
        let parent = url.deletingLastPathComponent().lastPathComponent
        if parent.isEmpty || parent == "/" {
            return url.lastPathComponent
        }
        return parent + " / " + url.lastPathComponent
    }

    private func prepareDirectories(at root: URL) -> Bool {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            try fileManager.createDirectory(
                at: root.appendingPathComponent(StorageService.photosDirectoryName, isDirectory: true),
                withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }

    private func loadLibrary() {
        let url = libraryRoot.appendingPathComponent(StorageService.libraryFileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            captures = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let library = try JSONDecoder.colorHunt().decode(ColorHuntLibrary.self, from: data)
            captures = library.captures.sorted { $0.capturedAt > $1.capturedAt }
        } catch {
            backupBrokenLibrary(at: url)
            captures = []
            lastErrorMessage = "ほぞんデータをよみこめませんでした。あたらしくはじめます。"
        }
    }

    /// こわれた library.json は消さずに名前を変えて残す（写真は無事なので手で直せる）
    private func backupBrokenLibrary(at url: URL) {
        let stamp = Int(Date().timeIntervalSince1970)
        let backup = libraryRoot.appendingPathComponent("library.broken-\(stamp).json")
        try? FileManager.default.moveItem(at: url, to: backup)
    }

    private func writeLibrary() -> Bool {
        let sorted = captures.sorted { $0.capturedAt > $1.capturedAt }
        let library = ColorHuntLibrary(schemaVersion: ColorHuntLibrary.currentSchemaVersion,
                                       captures: sorted)
        let url = libraryRoot.appendingPathComponent(StorageService.libraryFileName)
        do {
            let data = try JSONEncoder.colorHunt().encode(library)
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                // 一部の保存先では atomic 書き込みが使えないことがある
                try data.write(to: url)
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - ブックマーク（同じアプリのあいだだけ有効な近道）

    private func saveBookmark(for url: URL, subfolder: String) {
        let defaults = UserDefaults.standard
        do {
            let data = try url.bookmarkData()
            defaults.set(data, forKey: StorageService.bookmarkKey)
            defaults.set(subfolder, forKey: StorageService.subfolderKey)
        } catch {
            // ブックマークが作れなくても、その回のあいだは保存できる
            defaults.removeObject(forKey: StorageService.bookmarkKey)
            defaults.removeObject(forKey: StorageService.subfolderKey)
        }
    }

    private func restoreBookmarkedFolder() -> Bool {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: StorageService.bookmarkKey) else { return false }

        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: data,
                              options: [],
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            let didStartScope = url.startAccessingSecurityScopedResource()

            let subfolder = defaults.string(forKey: StorageService.subfolderKey) ?? ""
            let root = subfolder.isEmpty
                ? url
                : url.appendingPathComponent(subfolder, isDirectory: true)

            // 実際にそのフォルダが使えるかどうかで復元の成否を決める
            guard prepareDirectories(at: root) else {
                if didStartScope {
                    url.stopAccessingSecurityScopedResource()
                }
                return false
            }

            scopedURL = didStartScope ? url : nil
            libraryRoot = root
            locationKind = .external(StorageService.displayName(for: root))
            needsFolderSelection = false
            loadLibrary()
            if isStale {
                saveBookmark(for: url, subfolder: subfolder)
            }
            return true
        } catch {
            return false
        }
    }
}
