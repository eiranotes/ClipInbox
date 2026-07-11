import Foundation
import ImageIO
import UniformTypeIdentifiers

enum SharedSaveMode: String, Codable, CaseIterable {
    case quick
    case review
}

enum SharedAppLanguage: String, Codable, CaseIterable {
    case ko
    case en
    case ja
}

struct SharedClipConfiguration: Codable, Equatable {
    var saveMode: SharedSaveMode
    var language: SharedAppLanguage
    var defaultFolder: String
    var folders: [String]
    var theme: String? = nil

    static let standard = SharedClipConfiguration(
        saveMode: .quick,
        language: .ko,
        defaultFolder: "기본 폴더",
        folders: ["기본 폴더"],
        theme: "라이트"
    )
}

enum SharedClipType: String, Codable {
    case link
    case text
    case image
}

struct SharedClipPayload: Codable, Identifiable {
    var id: UUID
    var type: SharedClipType
    var title: String
    var source: String
    var url: String
    var text: String
    var sharedImageName: String?
    var folder: String
    var tags: [String]
    var memo: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        type: SharedClipType,
        title: String,
        source: String,
        url: String = "",
        text: String = "",
        sharedImageName: String? = nil,
        folder: String = "기본 폴더",
        tags: [String] = [],
        memo: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.source = source
        self.url = url
        self.text = text
        self.sharedImageName = sharedImageName
        self.folder = folder
        self.tags = tags
        self.memo = memo
        self.createdAt = createdAt
    }
}

/// Share Extension에서 받은 이미지의 압축 바이트와 파일 형식을 그대로 보존한다.
/// 픽셀 리사이즈나 JPEG 재인코딩은 하지 않는다.
struct SharedImageAsset: Equatable {
    let data: Data
    let fileExtension: String

    init?(data: Data, typeIdentifier: String? = nil, suggestedFileExtension: String? = nil) {
        guard !data.isEmpty,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }

        let detectedType = CGImageSourceGetType(source) as String?
        let candidates = [
            detectedType.flatMap { UTType($0)?.preferredFilenameExtension },
            typeIdentifier.flatMap { UTType($0)?.preferredFilenameExtension },
            suggestedFileExtension
        ]
        guard let fileExtension = candidates.compactMap(SharedClipQueue.safeImageFileExtension).first else {
            return nil
        }
        self.data = data
        self.fileExtension = fileExtension
    }
}

enum SharedClipQueue {
    static let appGroupIdentifier = "group.app.clipinbox.ClipInbox"
    private static let configurationFileName = "ShareConfiguration-v1.json"
    private static let legacyConfigurationKey = "clip-inbox-share-configuration-v1"
    private static let supportedImageFileExtensions = Set([
        "jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "gif", "webp"
    ])

    struct Item {
        let fileURL: URL
        let payload: SharedClipPayload
    }

    enum QueueError: LocalizedError {
        case appGroupUnavailable

        var errorDescription: String? {
            SharedL10n.text("Clip Inbox App Group 컨테이너를 열 수 없습니다. 서명과 App Group 권한을 확인하세요.")
        }
    }

    static func loadConfiguration() -> SharedClipConfiguration {
        if let fileURL = try? configurationFileURL(),
           let data = try? Data(contentsOf: fileURL),
           let value = try? JSONDecoder().decode(SharedClipConfiguration.self, from: data) {
            return value
        }
        if let legacy = loadLegacyConfiguration() {
            saveConfiguration(legacy)
            return legacy
        }
        return .standard
    }

    static func saveConfiguration(_ configuration: SharedClipConfiguration) {
        guard let fileURL = try? configurationFileURL(),
              let data = try? JSONEncoder().encode(configuration) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    static func enqueue(_ payload: SharedClipPayload) throws {
        let directory = try pendingDirectoryURL()
        let fileURL = directory.appendingPathComponent(payload.id.uuidString).appendingPathExtension("json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(payload)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    static func pendingItems() throws -> [Item] {
        let directory = try pendingDirectoryURL()
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let decoder = JSONDecoder()
        return urls
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let payload = try? decoder.decode(SharedClipPayload.self, from: data) else { return nil }
                return Item(fileURL: url, payload: payload)
            }
    }

    static func remove(_ item: Item) throws {
        try FileManager.default.removeItem(at: item.fileURL)
    }

    static func storeImageAsset(_ asset: SharedImageAsset, for id: UUID) throws -> String {
        let fileName = "\(id.uuidString).\(asset.fileExtension)"
        let fileURL = try imagesDirectoryURL().appendingPathComponent(fileName)
        try asset.data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        return fileName
    }

    static func imageURL(named fileName: String) -> URL? {
        guard isValidImageFileName(fileName) else {
            return nil
        }
        return try? imagesDirectoryURL().appendingPathComponent(fileName)
    }

    static func removeImage(named fileName: String) throws {
        guard let fileURL = imageURL(named: fileName), FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    static func removeAllImages() throws {
        let directory = try imagesDirectoryURL()
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for url in urls where isValidImageFileName(url.lastPathComponent) {
            try FileManager.default.removeItem(at: url)
        }
    }

    static func isValidImageFileName(_ fileName: String) -> Bool {
        guard fileName == (fileName as NSString).lastPathComponent else { return false }
        let stem = (fileName as NSString).deletingPathExtension
        guard UUID(uuidString: stem) != nil else { return false }
        return safeImageFileExtension((fileName as NSString).pathExtension) != nil
    }

    static func safeImageFileExtension(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        return supportedImageFileExtensions.contains(normalized) ? normalized : nil
    }

    private static func configurationFileURL() throws -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw QueueError.appGroupUnavailable
        }
        return container.appendingPathComponent(configurationFileName)
    }

    /// 이전 빌드의 App Group UserDefaults 값을 CFPrefs API 없이 한 번만 읽어
    /// 파일 기반 설정으로 옮긴다. simulator의 AnyUser/container 경고도 피한다.
    private static func loadLegacyConfiguration() -> SharedClipConfiguration? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { return nil }
        let fileURL = container
            .appendingPathComponent("Library/Preferences", isDirectory: true)
            .appendingPathComponent("\(appGroupIdentifier).plist")
        guard let plistData = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil),
              let dictionary = plist as? [String: Any],
              let configurationData = dictionary[legacyConfigurationKey] as? Data else { return nil }
        return try? JSONDecoder().decode(SharedClipConfiguration.self, from: configurationData)
    }

    private static func pendingDirectoryURL() throws -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw QueueError.appGroupUnavailable
        }
        let directory = container.appendingPathComponent("PendingClips", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func imagesDirectoryURL() throws -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw QueueError.appGroupUnavailable
        }
        let directory = container.appendingPathComponent("SharedImages", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
