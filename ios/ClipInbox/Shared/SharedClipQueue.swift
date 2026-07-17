import Foundation
import ImageIO
import UniformTypeIdentifiers

enum SharedSaveMode: String, Codable, CaseIterable, Sendable {
    case quick
    case review
}

enum SharedAppLanguage: String, Codable, CaseIterable, Sendable {
    case ko
    case en
    case ja
}

struct SharedClipConfiguration: Codable, Equatable, Sendable {
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

enum SharedClipType: String, Codable, Sendable {
    case link
    case text
    case image
}

struct SharedClipPayload: Codable, Identifiable, Sendable {
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

enum SharedImageAssetError: LocalizedError, Equatable, Sendable {
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
struct SharedImageAsset: Equatable, Sendable {
    static let maxBytes: Int64 = 50 * 1_024 * 1_024
    static let maxPixels: Int64 = 100_000_000

    private enum Source: Sendable {
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
    static let maxShareBatchItemCount = 20
    static let maxStagingBatchAge: TimeInterval = 24 * 60 * 60
    static let pendingBatchesDirectoryName = "PendingClipBatches"
    static let stagingBatchesDirectoryName = "PendingClipBatchesStaging"
    private static let configurationFileName = "ShareConfiguration-v1.json"
    private static let legacyConfigurationKey = "clip-inbox-share-configuration-v1"
    private static let payloadsDirectoryName = "Payloads"
    private static let batchImagesDirectoryName = "Images"
    private static let supportedImageFileExtensions = Set([
        "jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "gif", "webp"
    ])

    struct Item: Sendable {
        let fileURL: URL
        let payload: SharedClipPayload
        fileprivate let pendingImageURL: URL?
        fileprivate let batchDirectoryURL: URL?
        fileprivate let sourceContainerURL: URL

        var importBatchIdentifier: String {
            batchDirectoryURL?.lastPathComponent ?? payload.id.uuidString
        }
    }

    struct BatchItem: Sendable {
        let payload: SharedClipPayload
        let imageAsset: SharedImageAsset?

        init(payload: SharedClipPayload, imageAsset: SharedImageAsset? = nil) {
            self.payload = payload
            self.imageAsset = imageAsset
        }
    }

    typealias BatchProgressHandler = @Sendable (_ completed: Int, _ total: Int) -> Void

    struct StorageSummary: Equatable, Sendable {
        let originalImageCount: Int
        let originalImageBytes: Int64
        let pendingCount: Int
        let pendingBytes: Int64
        let quarantinedCount: Int
    }

    enum QueueError: LocalizedError, Equatable, Sendable {
        case appGroupUnavailable
        case batchItemLimitReached(Int)
        case itemLimitReached(Int)
        case byteLimitReached(Int)

        var errorDescription: String? {
            switch self {
            case .appGroupUnavailable:
                return SharedL10n.text("Clip Inbox App Group 컨테이너를 열 수 없습니다. 서명과 App Group 권한을 확인하세요.")
            case .batchItemLimitReached(let limit):
                return SharedL10n.format("format.share_batch_item_limit", limit)
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

    static func saveConfiguration(_ configuration: SharedClipConfiguration,
                                  containerURL: URL? = nil) throws {
        let fileURL = try configurationFileURL(containerURL: containerURL)
        let data = try JSONEncoder().encode(configuration)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    static func enqueue(_ payload: SharedClipPayload, containerURL: URL? = nil) throws {
        try enqueueBatch([BatchItem(payload: payload)], containerURL: containerURL)
    }

    /// 기존 호출자를 위한 payload 전용 경로도 새 원자적 배치 형식으로 기록한다.
    static func enqueue(_ payloads: [SharedClipPayload], containerURL: URL? = nil) throws {
        try enqueueBatch(payloads.map { BatchItem(payload: $0) }, containerURL: containerURL)
    }

    /// payload와 원본 이미지를 외부에서 보이지 않는 staging 디렉터리에 모두
    /// 기록한 뒤, 완성된 디렉터리 하나를 pending root로 rename해 한 번에 공개한다.
    static func enqueueBatch(
        _ items: [BatchItem],
        containerURL: URL? = nil,
        progress: BatchProgressHandler? = nil
    ) throws {
        guard !items.isEmpty else { return }
        guard items.count <= maxShareBatchItemCount else {
            throw QueueError.batchItemLimitReached(maxShareBatchItemCount)
        }

        try cleanupStaleStagingBatches(containerURL: containerURL)
        let pending = try pendingItems(containerURL: containerURL)
        var seenIDs = Set(pending.map(\.payload.id))
        let newItems = items.filter { seenIDs.insert($0.payload.id).inserted }
        guard !newItems.isEmpty else { return }
        guard pending.count + newItems.count <= maxPendingItemCount else {
            throw QueueError.itemLimitReached(maxPendingItemCount)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try newItems.map { item in
            var payload = item.payload
            if let asset = item.imageAsset {
                payload.sharedImageName = "\(payload.id.uuidString).\(asset.fileExtension)"
            }
            return (payload: payload, data: try encoder.encode(payload), imageAsset: item.imageAsset)
        }
        let existingBytes = try pending.reduce(Int64(0)) { partial, item in
            partial + (try queuedBytes(for: item, containerURL: containerURL))
        }
        let incomingBytes = encoded.reduce(Int64(0)) { partial, item in
            let imageBytes: Int64
            if let asset = item.imageAsset {
                imageBytes = asset.byteCount
            } else if let imageName = item.payload.sharedImageName,
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

        let stagingRoot = try stagingBatchesDirectoryURL(containerURL: containerURL)
        let committedRoot = try pendingBatchesDirectoryURL(containerURL: containerURL)
        let batchID = UUID()
        let stagingBatch = stagingRoot.appendingPathComponent(batchID.uuidString, isDirectory: true)
        let committedBatch = committedRoot.appendingPathComponent(batchID.uuidString, isDirectory: true)
        let payloadsDirectory = stagingBatch.appendingPathComponent(payloadsDirectoryName, isDirectory: true)
        let imagesDirectory = stagingBatch.appendingPathComponent(batchImagesDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(
            at: payloadsDirectory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUnlessOpen]
        )
        try FileManager.default.createDirectory(
            at: imagesDirectory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUnlessOpen]
        )

        var committed = false
        defer {
            if !committed, FileManager.default.fileExists(atPath: stagingBatch.path) {
                try? FileManager.default.removeItem(at: stagingBatch)
            }
        }

        progress?(0, encoded.count)
        do {
            for (index, item) in encoded.enumerated() {
                if let asset = item.imageAsset, let imageName = item.payload.sharedImageName {
                    try asset.write(to: imagesDirectory.appendingPathComponent(imageName))
                }
                let payloadURL = payloadsDirectory
                    .appendingPathComponent(item.payload.id.uuidString)
                    .appendingPathExtension("json")
                try item.data.write(to: payloadURL, options: [.atomic, .completeFileProtectionUnlessOpen])
                progress?(index + 1, encoded.count)
            }
            try FileManager.default.moveItem(at: stagingBatch, to: committedBatch)
            committed = true
        } catch {
            throw error
        }
    }

    static func pendingItems(containerURL: URL? = nil, now: Date = Date()) throws -> [Item] {
        let container = try resolvedContainerURL(containerURL)
        try cleanupStaleStagingBatches(containerURL: container, now: now)
        let decoder = JSONDecoder()
        var items: [Item] = []
        var seenIDs = Set<UUID>()

        for batchDirectory in try batchDirectoryURLs(containerURL: container) {
            let payloadsDirectory = batchDirectory
                .appendingPathComponent(payloadsDirectoryName, isDirectory: true)
            let payloadURLs = (try? FileManager.default.contentsOfDirectory(
                at: payloadsDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
            for payloadURL in payloadURLs where payloadURL.pathExtension == "json" {
                guard let item = decodePendingItem(
                    at: payloadURL,
                    batchDirectory: batchDirectory,
                    containerURL: container,
                    now: now,
                    decoder: decoder
                ) else { continue }
                guard seenIDs.insert(item.payload.id).inserted else {
                    try? quarantinePendingItem(item, directoryName: "FailedClips",
                                               imageDirectoryName: "FailedImages")
                    continue
                }
                items.append(item)
            }
        }

        let legacyDirectory = try legacyPendingDirectoryURL(containerURL: container)
        let legacyURLs = try FileManager.default.contentsOfDirectory(
            at: legacyDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for payloadURL in legacyURLs where payloadURL.pathExtension == "json" {
            guard let item = decodePendingItem(
                at: payloadURL,
                batchDirectory: nil,
                containerURL: container,
                now: now,
                decoder: decoder
            ) else { continue }
            guard seenIDs.insert(item.payload.id).inserted else {
                try? quarantine(item.fileURL, directoryName: "FailedClips", containerURL: container)
                continue
            }
            items.append(item)
        }

        return items.sorted {
            if $0.payload.createdAt != $1.payload.createdAt {
                return $0.payload.createdAt < $1.payload.createdAt
            }
            return $0.payload.id.uuidString < $1.payload.id.uuidString
        }
    }

    /// 앱 저장소 commit 이후 호출한다. 새 배치의 이미지는 먼저 SharedImages로
    /// 승격하고, 그 다음 payload를 제거한다. 중간 종료 뒤 재호출해도 안전하다.
    static func finalizeImport(_ items: [Item], containerURL: URL? = nil) throws {
        for item in items {
            let container = containerURL ?? item.sourceContainerURL
            if let imageName = item.payload.sharedImageName, item.batchDirectoryURL != nil {
                guard isValidImageFileName(imageName) else {
                    throw SharedImageAssetError.unsupported
                }
                let destination = try imagesDirectoryURL(containerURL: container)
                    .appendingPathComponent(imageName)
                let destinationExists = FileManager.default.fileExists(atPath: destination.path)
                if let source = item.pendingImageURL {
                    let sourceExists = FileManager.default.fileExists(atPath: source.path)
                    guard sourceExists || destinationExists else {
                        throw fileError(NSFileNoSuchFileError, path: source.path)
                    }
                    if sourceExists {
                        guard !destinationExists else {
                            throw fileError(NSFileWriteFileExistsError, path: destination.path)
                        }
                        try FileManager.default.moveItem(at: source, to: destination)
                        try FileManager.default.setAttributes(
                            [.protectionKey: FileProtectionType.completeUnlessOpen],
                            ofItemAtPath: destination.path
                        )
                    }
                } else if !destinationExists, item.payload.type == .image {
                    throw fileError(NSFileNoSuchFileError, path: destination.path)
                }
            }
            if FileManager.default.fileExists(atPath: item.fileURL.path) {
                try FileManager.default.removeItem(at: item.fileURL)
            }
            try cleanupCommittedBatchIfEmpty(item.batchDirectoryURL)
        }
    }

    static func remove(_ item: Item) throws {
        try finalizeImport([item], containerURL: item.sourceContainerURL)
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
        guard let sharedURL = try? imagesDirectoryURL(containerURL: containerURL)
            .appendingPathComponent(fileName) else { return nil }
        if FileManager.default.fileExists(atPath: sharedURL.path) {
            return sharedURL
        }
        if let container = try? resolvedContainerURL(containerURL),
           let batchDirectories = try? batchDirectoryURLs(containerURL: container) {
            for batchDirectory in batchDirectories {
                let candidate = batchDirectory
                    .appendingPathComponent(batchImagesDirectoryName, isDirectory: true)
                    .appendingPathComponent(fileName)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }
        // 기존 호출 계약처럼 유효한 이름에는 아직 파일이 없어도 표준 위치를 준다.
        return sharedURL
    }

    static func removeImage(named fileName: String, containerURL: URL? = nil) throws {
        guard isValidImageFileName(fileName) else { return }
        let fileURL = try imagesDirectoryURL(containerURL: containerURL).appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    static func removeAllImages() throws {
        let directory = try imagesDirectoryURL()
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for url in urls where isValidImageFileName(url.lastPathComponent) {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// 앱의 명시적 전체 삭제에서만 사용한다. 활성 이미지뿐 아니라 아직 앱에
    /// 들어오지 않은 payload와 실패/만료 격리본, Share 설정 파일까지 제거한다.
    static func removeAllData(containerURL: URL? = nil) throws {
        let container = try resolvedContainerURL(containerURL)
        let removableDirectories = [
            "PendingClips", pendingBatchesDirectoryName, stagingBatchesDirectoryName,
            "SharedImages", "FailedClips", "FailedImages", "ExpiredClips", "ExpiredImages"
        ]
        for name in removableDirectories {
            let directory = container.appendingPathComponent(name, isDirectory: true)
            if FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
        }
        let configurationURL = container.appendingPathComponent(configurationFileName)
        if FileManager.default.fileExists(atPath: configurationURL.path) {
            try FileManager.default.removeItem(at: configurationURL)
        }
        try removeLegacyConfiguration(containerURL: containerURL)
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
        let pendingBytes = try pending.reduce(Int64(0)) { partial, item in
            partial + (try queuedBytes(for: item, containerURL: containerURL))
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
            pendingBytes: pendingBytes,
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

    static func cleanupStaleStagingBatches(
        containerURL: URL? = nil,
        now: Date = Date()
    ) throws {
        let directory = try stagingBatchesDirectoryURL(containerURL: containerURL)
        let candidates = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        for candidate in candidates {
            guard UUID(uuidString: candidate.lastPathComponent) != nil else { continue }
            let values = try candidate.resourceValues(
                forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey]
            )
            guard values.isDirectory == true,
                  values.isSymbolicLink != true,
                  let modifiedAt = values.contentModificationDate,
                  now.timeIntervalSince(modifiedAt) > maxStagingBatchAge else { continue }
            try FileManager.default.removeItem(at: candidate)
        }
    }

    private static func configurationFileURL(containerURL: URL? = nil) throws -> URL {
        let container = try resolvedContainerURL(containerURL)
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

    private static func removeLegacyConfiguration(containerURL: URL?) throws {
        let container = try resolvedContainerURL(containerURL)
        let fileURL = container
            .appendingPathComponent("Library/Preferences", isDirectory: true)
            .appendingPathComponent("\(appGroupIdentifier).plist")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data = try Data(contentsOf: fileURL)
        guard var dictionary = try PropertyListSerialization.propertyList(
            from: data,
            format: nil
        ) as? [String: Any] else { return }
        guard dictionary.removeValue(forKey: legacyConfigurationKey) != nil else { return }
        let updated = try PropertyListSerialization.data(
            fromPropertyList: dictionary,
            format: .binary,
            options: 0
        )
        try updated.write(to: fileURL, options: .atomic)
    }

    private static func legacyPendingDirectoryURL(containerURL override: URL? = nil) throws -> URL {
        let container = try resolvedContainerURL(override)
        let directory = container.appendingPathComponent("PendingClips", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func pendingBatchesDirectoryURL(containerURL override: URL? = nil) throws -> URL {
        let container = try resolvedContainerURL(override)
        let directory = container.appendingPathComponent(pendingBatchesDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func stagingBatchesDirectoryURL(containerURL override: URL? = nil) throws -> URL {
        let container = try resolvedContainerURL(override)
        let directory = container.appendingPathComponent(stagingBatchesDirectoryName, isDirectory: true)
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

    private static func batchDirectoryURLs(containerURL: URL) throws -> [URL] {
        let root = try pendingBatchesDirectoryURL(containerURL: containerURL)
        return try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ).filter { candidate in
            guard UUID(uuidString: candidate.lastPathComponent) != nil,
                  let values = try? candidate.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else {
                return false
            }
            return values.isDirectory == true && values.isSymbolicLink != true
        }
    }

    private static func decodePendingItem(
        at payloadURL: URL,
        batchDirectory: URL?,
        containerURL: URL,
        now: Date,
        decoder: JSONDecoder
    ) -> Item? {
        guard let data = try? Data(contentsOf: payloadURL),
              let payload = try? decoder.decode(SharedClipPayload.self, from: data) else {
            if let batchDirectory {
                try? quarantineBatchImageMatchingPayloadFile(
                    payloadURL,
                    batchDirectory: batchDirectory,
                    directoryName: "FailedImages",
                    containerURL: containerURL
                )
            }
            try? quarantine(payloadURL, directoryName: "FailedClips", containerURL: containerURL)
            try? cleanupCommittedBatchIfEmpty(batchDirectory)
            return nil
        }

        let pendingImageURL: URL?
        if let batchDirectory,
           let imageName = payload.sharedImageName,
           isValidImageFileName(imageName) {
            let candidate = batchDirectory
                .appendingPathComponent(batchImagesDirectoryName, isDirectory: true)
                .appendingPathComponent(imageName)
            pendingImageURL = FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
        } else {
            pendingImageURL = nil
        }
        let item = Item(
            fileURL: payloadURL,
            payload: payload,
            pendingImageURL: pendingImageURL,
            batchDirectoryURL: batchDirectory,
            sourceContainerURL: containerURL
        )
        if payload.type == .image {
            let promotedImageExists: Bool
            if let imageName = payload.sharedImageName,
               isValidImageFileName(imageName),
               let promotedURL = try? imagesDirectoryURL(containerURL: containerURL)
                .appendingPathComponent(imageName) {
                promotedImageExists = FileManager.default.fileExists(atPath: promotedURL.path)
            } else {
                promotedImageExists = false
            }
            guard pendingImageURL != nil || promotedImageExists else {
                try? quarantinePendingItem(
                    item,
                    directoryName: "FailedClips",
                    imageDirectoryName: "FailedImages"
                )
                return nil
            }
        }
        guard now.timeIntervalSince(payload.createdAt) <= maxPendingAge else {
            try? quarantinePendingItem(
                item,
                directoryName: "ExpiredClips",
                imageDirectoryName: "ExpiredImages"
            )
            return nil
        }
        return item
    }

    private static func quarantinePendingItem(
        _ item: Item,
        directoryName: String,
        imageDirectoryName: String
    ) throws {
        if let source = item.pendingImageURL,
           FileManager.default.fileExists(atPath: source.path) {
            try quarantine(source, directoryName: imageDirectoryName,
                           containerURL: item.sourceContainerURL)
        } else if item.batchDirectoryURL == nil,
                  let imageName = item.payload.sharedImageName,
                  isValidImageFileName(imageName) {
            let legacyImage = try imagesDirectoryURL(containerURL: item.sourceContainerURL)
                .appendingPathComponent(imageName)
            if FileManager.default.fileExists(atPath: legacyImage.path) {
                try quarantine(legacyImage, directoryName: imageDirectoryName,
                               containerURL: item.sourceContainerURL)
            }
        }
        if FileManager.default.fileExists(atPath: item.fileURL.path) {
            try quarantine(item.fileURL, directoryName: directoryName,
                           containerURL: item.sourceContainerURL)
        }
        try cleanupCommittedBatchIfEmpty(item.batchDirectoryURL)
    }

    private static func quarantineBatchImageMatchingPayloadFile(
        _ payloadURL: URL,
        batchDirectory: URL,
        directoryName: String,
        containerURL: URL
    ) throws {
        guard UUID(uuidString: payloadURL.deletingPathExtension().lastPathComponent) != nil else { return }
        let imagesDirectory = batchDirectory
            .appendingPathComponent(batchImagesDirectoryName, isDirectory: true)
        let images = (try? FileManager.default.contentsOfDirectory(
            at: imagesDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        for image in images where
            image.deletingPathExtension().lastPathComponent == payloadURL.deletingPathExtension().lastPathComponent
                && isValidImageFileName(image.lastPathComponent) {
            try quarantine(image, directoryName: directoryName, containerURL: containerURL)
        }
    }

    private static func cleanupCommittedBatchIfEmpty(_ batchDirectory: URL?) throws {
        guard let batchDirectory,
              FileManager.default.fileExists(atPath: batchDirectory.path) else { return }
        let payloadsDirectory = batchDirectory
            .appendingPathComponent(payloadsDirectoryName, isDirectory: true)
        let payloads = (try? FileManager.default.contentsOfDirectory(
            at: payloadsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        guard !payloads.contains(where: { $0.pathExtension == "json" }) else { return }
        try FileManager.default.removeItem(at: batchDirectory)
    }

    private static func fileError(_ code: Int, path: String) -> NSError {
        NSError(domain: NSCocoaErrorDomain, code: code, userInfo: [NSFilePathErrorKey: path])
    }

    private static func queuedBytes(for item: Item, containerURL: URL?) throws -> Int64 {
        let payloadBytes = Int64(try item.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        if let pendingImageURL = item.pendingImageURL {
            let imageBytes = Int64(
                try pendingImageURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            )
            return payloadBytes + imageBytes
        }
        guard let imageName = item.payload.sharedImageName,
              let imageURL = imageURL(named: imageName, containerURL: containerURL),
              FileManager.default.fileExists(atPath: imageURL.path) else { return payloadBytes }
        let imageBytes = Int64(try imageURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        return payloadBytes + imageBytes
    }
}
