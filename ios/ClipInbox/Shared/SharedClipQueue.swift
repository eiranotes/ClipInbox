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
        defaultFolder: "인박스",
        folders: ["인박스"],
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
        folder: String = "인박스",
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

enum SharedImageAssetError: LocalizedError, Equatable {
    case unsupported
    case tooLarge(maxMegabytes: Int)
    case tooManyPixels(maxMegapixels: Int)

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return SharedL10n.text("지원하는 이미지 파일을 읽을 수 없습니다.")
        case .tooLarge(let maxMegabytes):
            return SharedL10n.format("format.image_too_large", maxMegabytes)
        case .tooManyPixels(let maxMegapixels):
            return SharedL10n.format("format.image_too_many_pixels", maxMegapixels)
        }
    }
}

/// Share Extension에서 받은 원본 표현을 보존한다. Provider 파일 표현은 메모리에
/// 올리지 않고 검증·복사하며, Data 표현은 작은 fallback과 인앱 PhotosPicker에만 쓴다.
struct SharedImageAsset: Equatable {
    static let maxBytes: Int64 = 50 * 1_024 * 1_024
    static let maxPixels: Int64 = 100_000_000

    private enum Source {
        case data(Data)
        case file(URL, removeAfterUse: Bool)
    }

    private let source: Source
    let fileExtension: String
    let byteCount: Int64
    let pixelCount: Int64

    var data: Data {
        switch source {
        case .data(let data): return data
        case .file(let url, _): return (try? Data(contentsOf: url)) ?? Data()
        }
    }

    init?(data: Data, typeIdentifier: String? = nil, suggestedFileExtension: String? = nil) {
        guard let value = try? SharedImageAsset(
            validatingData: data,
            typeIdentifier: typeIdentifier,
            suggestedFileExtension: suggestedFileExtension
        ) else { return nil }
        self = value
    }

    init(validatingData data: Data, typeIdentifier: String? = nil,
         suggestedFileExtension: String? = nil) throws {
        guard Int64(data.count) <= Self.maxBytes else {
            throw SharedImageAssetError.tooLarge(maxMegabytes: Int(Self.maxBytes / 1_024 / 1_024))
        }
        guard !data.isEmpty,
              let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw SharedImageAssetError.unsupported
        }
        let metadata = try Self.metadata(
            source: imageSource,
            typeIdentifier: typeIdentifier,
            suggestedFileExtension: suggestedFileExtension
        )
        source = .data(data)
        fileExtension = metadata.fileExtension
        byteCount = Int64(data.count)
        pixelCount = metadata.pixelCount
    }

    init(validatingFileAt url: URL, typeIdentifier: String? = nil,
         suggestedFileExtension: String? = nil, removeAfterUse: Bool = false) throws {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true, let fileSize = values.fileSize, fileSize > 0 else {
            throw SharedImageAssetError.unsupported
        }
        guard Int64(fileSize) <= Self.maxBytes else {
            throw SharedImageAssetError.tooLarge(maxMegabytes: Int(Self.maxBytes / 1_024 / 1_024))
        }
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw SharedImageAssetError.unsupported
        }
        let metadata = try Self.metadata(
            source: imageSource,
            typeIdentifier: typeIdentifier,
            suggestedFileExtension: suggestedFileExtension ?? url.pathExtension
        )
        source = .file(url, removeAfterUse: removeAfterUse)
        fileExtension = metadata.fileExtension
        byteCount = Int64(fileSize)
        pixelCount = metadata.pixelCount
    }

    func write(to destination: URL) throws {
        switch source {
        case .data(let data):
            try data.write(to: destination, options: [.atomic, .completeFileProtectionUnlessOpen])
        case .file(let sourceURL, _):
            let temporary = destination.deletingLastPathComponent()
                .appendingPathComponent(".\(UUID().uuidString).tmp")
            try FileManager.default.copyItem(at: sourceURL, to: temporary)
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
                } else {
                    try FileManager.default.moveItem(at: temporary, to: destination)
                }
                try FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.completeUnlessOpen],
                    ofItemAtPath: destination.path
                )
            } catch {
                try? FileManager.default.removeItem(at: temporary)
                throw error
            }
        }
    }

    func cleanupSourceIfNeeded() {
        if case .file(let url, let removeAfterUse) = source, removeAfterUse {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func == (lhs: SharedImageAsset, rhs: SharedImageAsset) -> Bool {
        lhs.fileExtension == rhs.fileExtension
            && lhs.byteCount == rhs.byteCount
            && lhs.pixelCount == rhs.pixelCount
            && lhs.data == rhs.data
    }

    private static func metadata(source: CGImageSource, typeIdentifier: String?,
                                 suggestedFileExtension: String?) throws
    -> (fileExtension: String, pixelCount: Int64) {
        guard CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.int64Value,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.int64Value,
              width > 0, height > 0 else {
            throw SharedImageAssetError.unsupported
        }
        let (pixelCount, overflow) = width.multipliedReportingOverflow(by: height)
        guard !overflow, pixelCount <= maxPixels else {
            throw SharedImageAssetError.tooManyPixels(maxMegapixels: Int(maxPixels / 1_000_000))
        }
        let detectedType = CGImageSourceGetType(source) as String?
        let candidates = [
            detectedType.flatMap { UTType($0)?.preferredFilenameExtension },
            typeIdentifier.flatMap { UTType($0)?.preferredFilenameExtension },
            suggestedFileExtension
        ]
        guard let fileExtension = candidates.compactMap(SharedClipQueue.safeImageFileExtension).first else {
            throw SharedImageAssetError.unsupported
        }
        return (fileExtension, pixelCount)
    }
}

enum SharedClipQueue {
    static let appGroupIdentifier = "group.app.eiradev.ClipInbox"
    static let maxPendingItemCount = 200
    static let maxPendingBytes: Int64 = 250 * 1_024 * 1_024
    static let maxPendingAge: TimeInterval = 30 * 24 * 60 * 60
    private static let configurationFileName = "ShareConfiguration-v1.json"
    private static let legacyConfigurationKey = "clip-inbox-share-configuration-v1"
    private static let supportedImageFileExtensions = Set([
        "jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "gif", "webp"
    ])

    struct Item {
        let fileURL: URL
        let payload: SharedClipPayload
    }

    struct StorageSummary: Equatable {
        let originalImageCount: Int
        let originalImageBytes: Int64
        let pendingCount: Int
        let pendingPayloadBytes: Int64
        let quarantinedCount: Int
    }

    enum QueueError: LocalizedError, Equatable {
        case appGroupUnavailable
        case itemLimitReached(Int)
        case byteLimitReached(Int)

        var errorDescription: String? {
            switch self {
            case .appGroupUnavailable:
                return SharedL10n.text("Clip Inbox App Group 컨테이너를 열 수 없습니다. 서명과 App Group 권한을 확인하세요.")
            case .itemLimitReached(let limit):
                return SharedL10n.format("format.share_queue_item_limit", limit)
            case .byteLimitReached(let megabytes):
                return SharedL10n.format("format.share_queue_byte_limit", megabytes)
            }
        }
    }

    static func loadConfiguration() -> SharedClipConfiguration {
        if let fileURL = try? configurationFileURL(),
           let data = try? Data(contentsOf: fileURL),
           let value = try? JSONDecoder().decode(SharedClipConfiguration.self, from: data) {
            return value
        }
        if let legacy = loadLegacyConfiguration() {
            try? saveConfiguration(legacy)
            return legacy
        }
        return .standard
    }

    static func saveConfiguration(_ configuration: SharedClipConfiguration) throws {
        let fileURL = try configurationFileURL()
        let data = try JSONEncoder().encode(configuration)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    static func enqueue(_ payload: SharedClipPayload, containerURL: URL? = nil) throws {
        try enqueue([payload], containerURL: containerURL)
    }

    /// 한 번의 Share 작업에서 넘어온 여러 항목은 용량/개수 한도를 먼저 함께
    /// 검증한 뒤 기록한다. 중간 쓰기 실패 시 이번 배치가 만든 payload만 되돌린다.
    static func enqueue(_ payloads: [SharedClipPayload], containerURL: URL? = nil) throws {
        guard !payloads.isEmpty else { return }
        let directory = try pendingDirectoryURL(containerURL: containerURL)
        let pending = try pendingItems(containerURL: containerURL)
        var seenIDs = Set(pending.map(\.payload.id))
        let newPayloads = payloads.filter { seenIDs.insert($0.id).inserted }
        guard !newPayloads.isEmpty else { return }
        guard pending.count + newPayloads.count <= maxPendingItemCount else {
            throw QueueError.itemLimitReached(maxPendingItemCount)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try newPayloads.map { payload in
            (
                payload: payload,
                data: try encoder.encode(payload),
                fileURL: directory
                    .appendingPathComponent(payload.id.uuidString)
                    .appendingPathExtension("json")
            )
        }
        let existingBytes = try pending.reduce(Int64(0)) { partial, item in
            partial + (try queuedBytes(for: item, containerURL: containerURL))
        }
        let incomingBytes = encoded.reduce(Int64(0)) { partial, item in
            let imageBytes: Int64
            if let imageName = item.payload.sharedImageName,
               let imageURL = imageURL(named: imageName, containerURL: containerURL) {
                imageBytes = Int64((try? imageURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            } else {
                imageBytes = 0
            }
            return partial + Int64(item.data.count) + imageBytes
        }
        guard existingBytes + incomingBytes <= maxPendingBytes else {
            throw QueueError.byteLimitReached(Int(maxPendingBytes / 1_024 / 1_024))
        }

        var writtenURLs: [URL] = []
        do {
            for item in encoded {
                try item.data.write(to: item.fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
                writtenURLs.append(item.fileURL)
            }
        } catch {
            writtenURLs.forEach { try? FileManager.default.removeItem(at: $0) }
            throw error
        }
    }

    static func pendingItems(containerURL: URL? = nil, now: Date = Date()) throws -> [Item] {
        let directory = try pendingDirectoryURL(containerURL: containerURL)
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let decoder = JSONDecoder()
        var items: [Item] = []
        for url in urls where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let payload = try? decoder.decode(SharedClipPayload.self, from: data) else {
                try? quarantine(url, directoryName: "FailedClips", containerURL: containerURL)
                continue
            }
            guard now.timeIntervalSince(payload.createdAt) <= maxPendingAge else {
                try? quarantine(url, directoryName: "ExpiredClips", containerURL: containerURL)
                if let imageName = payload.sharedImageName,
                   let source = imageURL(named: imageName, containerURL: containerURL) {
                    try? quarantine(source, directoryName: "ExpiredImages", containerURL: containerURL)
                }
                continue
            }
            items.append(Item(fileURL: url, payload: payload))
        }
        return items.sorted {
            if $0.payload.createdAt != $1.payload.createdAt {
                return $0.payload.createdAt < $1.payload.createdAt
            }
            return $0.payload.id.uuidString < $1.payload.id.uuidString
        }
    }

    static func remove(_ item: Item) throws {
        try FileManager.default.removeItem(at: item.fileURL)
    }

    static func storeImageAsset(_ asset: SharedImageAsset, for id: UUID,
                                containerURL: URL? = nil) throws -> String {
        let fileName = "\(id.uuidString).\(asset.fileExtension)"
        let fileURL = try imagesDirectoryURL(containerURL: containerURL).appendingPathComponent(fileName)
        try asset.write(to: fileURL)
        return fileName
    }

    static func imageURL(named fileName: String, containerURL: URL? = nil) -> URL? {
        guard isValidImageFileName(fileName) else {
            return nil
        }
        return try? imagesDirectoryURL(containerURL: containerURL).appendingPathComponent(fileName)
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

    static func storageSummary(containerURL: URL? = nil) throws -> StorageSummary {
        let images = try FileManager.default.contentsOfDirectory(
            at: imagesDirectoryURL(containerURL: containerURL),
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ).filter { isValidImageFileName($0.lastPathComponent) }
        let imageBytes = try images.reduce(Int64(0)) { partial, url in
            partial + Int64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        }
        let pending = try pendingItems(containerURL: containerURL)
        let payloadBytes = try pending.reduce(Int64(0)) { partial, item in
            partial + Int64(try item.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        }
        let container = try resolvedContainerURL(containerURL)
        let quarantinedCount = ["FailedClips", "ExpiredClips"].reduce(0) { partial, name in
            let directory = container.appendingPathComponent(name, isDirectory: true)
            let count = (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ).count) ?? 0
            return partial + count
        }
        return StorageSummary(
            originalImageCount: images.count,
            originalImageBytes: imageBytes,
            pendingCount: pending.count,
            pendingPayloadBytes: payloadBytes,
            quarantinedCount: quarantinedCount
        )
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

    private static func pendingDirectoryURL(containerURL override: URL? = nil) throws -> URL {
        let container = try resolvedContainerURL(override)
        let directory = container.appendingPathComponent("PendingClips", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func imagesDirectoryURL(containerURL override: URL? = nil) throws -> URL {
        let container = try resolvedContainerURL(override)
        let directory = container.appendingPathComponent("SharedImages", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func resolvedContainerURL(_ override: URL?) throws -> URL {
        if let override { return override }
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { throw QueueError.appGroupUnavailable }
        return container
    }

    private static func quarantine(_ source: URL, directoryName: String,
                                   containerURL: URL?) throws {
        let directory = try resolvedContainerURL(containerURL)
            .appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var destination = directory.appendingPathComponent(source.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            destination = directory.appendingPathComponent("\(UUID().uuidString)-\(source.lastPathComponent)")
        }
        try FileManager.default.moveItem(at: source, to: destination)
    }

    private static func queuedBytes(for item: Item, containerURL: URL?) throws -> Int64 {
        let payloadBytes = Int64(try item.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        guard let imageName = item.payload.sharedImageName,
              let imageURL = imageURL(named: imageName, containerURL: containerURL) else {
            return payloadBytes
        }
        let imageBytes = Int64(try imageURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        return payloadBytes + imageBytes
    }
}
