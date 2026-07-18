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
    case file
}

enum SharedClipAttachmentKind: String, Codable, Sendable {
    case image
    case file
}

struct SharedClipAttachment: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var kind: SharedClipAttachmentKind
    var originalFileName: String
    var storedFileName: String?
    var typeIdentifier: String?
    var byteCount: Int64

    init(
        id: UUID = UUID(),
        kind: SharedClipAttachmentKind,
        originalFileName: String,
        storedFileName: String? = nil,
        typeIdentifier: String? = nil,
        byteCount: Int64 = 0
    ) {
        self.id = id
        self.kind = kind
        self.originalFileName = originalFileName
        self.storedFileName = storedFileName
        self.typeIdentifier = typeIdentifier
        self.byteCount = byteCount
    }
}

struct SharedClipPayload: Codable, Identifiable, Sendable {
    var id: UUID
    var type: SharedClipType
    var title: String
    var source: String
    var url: String
    var text: String
    var sharedImageName: String?
    var attachments: [SharedClipAttachment]
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
        attachments: [SharedClipAttachment] = [],
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
        self.attachments = attachments
        self.folder = folder
        self.tags = tags
        self.memo = memo
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(SharedClipType.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        source = try container.decode(String.self, forKey: .source)
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        sharedImageName = try container.decodeIfPresent(String.self, forKey: .sharedImageName)
        attachments = try container.decodeIfPresent([SharedClipAttachment].self, forKey: .attachments) ?? []
        folder = try container.decodeIfPresent(String.self, forKey: .folder) ?? "인박스"
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        memo = try container.decodeIfPresent(String.self, forKey: .memo) ?? ""
        createdAt = try container.decode(Date.self, forKey: .createdAt)
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

enum SharedAttachmentAssetError: LocalizedError, Equatable, Sendable {
    case unsupported
    case tooLarge(maxMegabytes: Int)

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return SharedL10n.text("지원하는 첨부 파일을 읽을 수 없습니다.")
        case .tooLarge(let maxMegabytes):
            return SharedL10n.format("format.attachment_too_large", maxMegabytes)
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

/// 이미지와 일반 파일을 같은 공유 호출의 한 클립에 묶기 위한 원본 첨부 파일이다.
/// 이미지는 기존 픽셀/형식 검증을 그대로 거치고, 일반 파일은 크기와 정규 파일 여부를
/// 확인한 뒤 원본 바이트를 staging 디렉터리로 복사한다.
struct SharedAttachmentAsset: Sendable {
    static let maxBytes = SharedImageAsset.maxBytes

    private enum Source: Sendable {
        case image(SharedImageAsset)
        case file(URL, removeAfterUse: Bool)
    }

    private let source: Source
    let id: UUID
    let kind: SharedClipAttachmentKind
    let originalFileName: String
    let typeIdentifier: String?
    let fileExtension: String
    let byteCount: Int64

    init(
        imageAsset: SharedImageAsset,
        originalFileName: String? = nil,
        typeIdentifier: String? = nil,
        id: UUID = UUID()
    ) {
        source = .image(imageAsset)
        self.id = id
        kind = .image
        self.typeIdentifier = typeIdentifier
        fileExtension = imageAsset.fileExtension
        byteCount = imageAsset.byteCount
        self.originalFileName = Self.displayFileName(
            originalFileName,
            fallback: "image.\(imageAsset.fileExtension)"
        )
    }

    init(
        validatingFileAt url: URL,
        typeIdentifier: String? = nil,
        originalFileName: String? = nil,
        removeAfterUse: Bool = false,
        id: UUID = UUID()
    ) throws {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true, let fileSize = values.fileSize, fileSize > 0 else {
            throw SharedAttachmentAssetError.unsupported
        }
        guard Int64(fileSize) <= Self.maxBytes else {
            throw SharedAttachmentAssetError.tooLarge(maxMegabytes: Int(Self.maxBytes / 1_024 / 1_024))
        }
        let candidates = [
            typeIdentifier.flatMap { UTType($0)?.preferredFilenameExtension },
            url.pathExtension,
            originalFileName.map { ($0 as NSString).pathExtension }
        ]
        let resolvedExtension = candidates.compactMap(SharedClipQueue.safeAttachmentFileExtension).first ?? "bin"
        source = .file(url, removeAfterUse: removeAfterUse)
        self.id = id
        kind = .file
        self.typeIdentifier = typeIdentifier
        fileExtension = resolvedExtension
        byteCount = Int64(fileSize)
        self.originalFileName = Self.displayFileName(
            originalFileName ?? url.lastPathComponent,
            fallback: "file.\(resolvedExtension)"
        )
    }

    var attachment: SharedClipAttachment {
        SharedClipAttachment(
            id: id,
            kind: kind,
            originalFileName: originalFileName,
            storedFileName: "\(id.uuidString).\(fileExtension)",
            typeIdentifier: typeIdentifier,
            byteCount: byteCount
        )
    }

    func write(to destination: URL) throws {
        switch source {
        case .image(let imageAsset):
            try imageAsset.write(to: destination)
        case .file(let sourceURL, _):
            let temporary = destination.deletingLastPathComponent()
                .appendingPathComponent(".\(UUID().uuidString).tmp")
            try FileManager.default.copyItem(at: sourceURL, to: temporary)
            do {
                try FileManager.default.moveItem(at: temporary, to: destination)
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
        switch source {
        case .image(let imageAsset):
            imageAsset.cleanupSourceIfNeeded()
        case .file(let url, let removeAfterUse):
            if removeAfterUse { try? FileManager.default.removeItem(at: url) }
        }
    }

    private static func displayFileName(_ value: String?, fallback: String) -> String {
        let candidate = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let leaf = (candidate as NSString).lastPathComponent
        return leaf.isEmpty ? fallback : String(leaf.prefix(200))
    }
}

enum SharedClipQueue {
    static let appGroupIdentifier = "group.app.eiradev.ClipInbox"
    static let maxPendingItemCount = 200
    static let maxPendingBytes: Int64 = 250 * 1_024 * 1_024
    static let maxPendingAge: TimeInterval = 30 * 24 * 60 * 60
    static let maxShareBatchItemCount = 20
    static let maxShareAttachmentCount = 20
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
        fileprivate let pendingAttachmentURLs: [String: URL]
        fileprivate let batchDirectoryURL: URL?
        fileprivate let sourceContainerURL: URL

        var importBatchIdentifier: String {
            batchDirectoryURL?.lastPathComponent ?? payload.id.uuidString
        }
    }

    struct BatchItem: Sendable {
        let payload: SharedClipPayload
        let imageAsset: SharedImageAsset?
        let attachmentAssets: [SharedAttachmentAsset]

        init(
            payload: SharedClipPayload,
            imageAsset: SharedImageAsset? = nil,
            attachmentAssets: [SharedAttachmentAsset] = []
        ) {
            self.payload = payload
            self.imageAsset = imageAsset
            self.attachmentAssets = attachmentAssets
        }
    }

    typealias BatchProgressHandler = @Sendable (_ completed: Int, _ total: Int) -> Void

    struct StorageSummary: Equatable, Sendable {
        let originalAttachmentCount: Int
        let originalAttachmentBytes: Int64
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

    /// payload와 원본 첨부 파일을 외부에서 보이지 않는 staging 디렉터리에 모두
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
        let attachmentCount = items.reduce(0) { partial, item in
            partial + max(item.attachmentAssets.count, item.imageAsset == nil ? 0 : 1)
        }
        guard attachmentCount <= maxShareAttachmentCount else {
            throw QueueError.batchItemLimitReached(maxShareAttachmentCount)
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
            let attachmentAssets = item.attachmentAssets
            if !attachmentAssets.isEmpty {
                payload.attachments = attachmentAssets.map(\.attachment)
                payload.sharedImageName = payload.attachments.first(where: { $0.kind == .image })?.storedFileName
                payload.type = payload.attachments.allSatisfy { $0.kind == .image } ? .image : .file
            } else if let asset = item.imageAsset {
                payload.sharedImageName = "\(payload.id.uuidString).\(asset.fileExtension)"
            }
            return (
                payload: payload,
                data: try encoder.encode(payload),
                imageAsset: item.imageAsset,
                attachmentAssets: attachmentAssets
            )
        }
        let existingBytes = try pending.reduce(Int64(0)) { partial, item in
            partial + (try queuedBytes(for: item, containerURL: containerURL))
        }
        let incomingBytes = encoded.reduce(Int64(0)) { partial, item in
            let imageBytes: Int64
            if !item.attachmentAssets.isEmpty {
                imageBytes = item.attachmentAssets.reduce(0) { $0 + $1.byteCount }
            } else if let asset = item.imageAsset {
                imageBytes = asset.byteCount
            } else {
                let names = Set(item.payload.attachments.compactMap(\.storedFileName)
                    + [item.payload.sharedImageName].compactMap { $0 })
                imageBytes = names.reduce(0) { bytes, fileName in
                    guard let fileURL = attachmentURL(named: fileName, containerURL: containerURL) else {
                        return bytes
                    }
                    return bytes + Int64(
                        (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    )
                }
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

        let progressTotal = encoded.reduce(0) { partial, item in
            partial + max(max(item.attachmentAssets.count, item.imageAsset == nil ? 0 : 1), 1)
        }
        var completedProgress = 0
        progress?(0, progressTotal)
        do {
            for item in encoded {
                for asset in item.attachmentAssets {
                    let fileName = asset.attachment.storedFileName ?? ""
                    try asset.write(to: imagesDirectory.appendingPathComponent(fileName))
                    completedProgress += 1
                    progress?(completedProgress, progressTotal)
                }
                if item.attachmentAssets.isEmpty,
                   let asset = item.imageAsset,
                   let imageName = item.payload.sharedImageName {
                    try asset.write(to: imagesDirectory.appendingPathComponent(imageName))
                    completedProgress += 1
                    progress?(completedProgress, progressTotal)
                }
                let payloadURL = payloadsDirectory
                    .appendingPathComponent(item.payload.id.uuidString)
                    .appendingPathExtension("json")
                try item.data.write(to: payloadURL, options: [.atomic, .completeFileProtectionUnlessOpen])
                if item.attachmentAssets.isEmpty && item.imageAsset == nil {
                    completedProgress += 1
                    progress?(completedProgress, progressTotal)
                }
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
            let payloadURLs = ((try? FileManager.default.contentsOfDirectory(
                at: payloadsDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []).sorted { $0.lastPathComponent < $1.lastPathComponent }
            var batchItems: [Item] = []
            var batchIDs = Set<UUID>()
            var batchIsValid = true
            for payloadURL in payloadURLs where payloadURL.pathExtension == "json" {
                guard let item = decodePendingItem(
                    at: payloadURL,
                    batchDirectory: batchDirectory,
                    containerURL: container,
                    now: now,
                    decoder: decoder
                ) else {
                    batchIsValid = false
                    break
                }
                guard !seenIDs.contains(item.payload.id),
                      batchIDs.insert(item.payload.id).inserted else {
                    batchIsValid = false
                    break
                }
                batchItems.append(item)
            }
            guard batchIsValid else {
                // 먼저 읽은 payload도 아직 전역 결과에 노출하지 않는다. 배치 하나가
                // 실패하면 남은 payload/원본까지 함께 격리해 부분 import를 막는다.
                try? quarantineCommittedBatch(
                    batchDirectory: batchDirectory,
                    containerURL: container
                )
                continue
            }
            seenIDs.formUnion(batchIDs)
            items.append(contentsOf: batchItems)
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

    /// 앱 저장소 commit 이후 호출한다. 새 배치의 첨부 파일은 먼저 SharedImages로
    /// 승격하고, 그 다음 payload를 제거한다. 중간 종료 뒤 재호출해도 안전하다.
    static func finalizeImport(_ items: [Item], containerURL: URL? = nil) throws {
        for item in items {
            let container = containerURL ?? item.sourceContainerURL
            let attachmentNames = Set(
                item.payload.attachments.compactMap(\.storedFileName)
                    + [item.payload.sharedImageName].compactMap { $0 }
            )
            for attachmentName in attachmentNames where item.batchDirectoryURL != nil {
                guard isValidAttachmentFileName(attachmentName) else {
                    throw SharedAttachmentAssetError.unsupported
                }
                let destination = try imagesDirectoryURL(containerURL: container)
                    .appendingPathComponent(attachmentName)
                let destinationExists = FileManager.default.fileExists(atPath: destination.path)
                if let source = item.pendingAttachmentURLs[attachmentName] {
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
                } else if !destinationExists {
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
        guard isValidImageFileName(fileName) else { return nil }
        return attachmentURL(named: fileName, containerURL: containerURL)
    }

    static func attachmentURL(named fileName: String, containerURL: URL? = nil) -> URL? {
        guard isValidAttachmentFileName(fileName) else { return nil }
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
        try removeAttachment(named: fileName, containerURL: containerURL)
    }

    static func removeAttachment(named fileName: String, containerURL: URL? = nil) throws {
        guard isValidAttachmentFileName(fileName) else { return }
        let fileURL = try imagesDirectoryURL(containerURL: containerURL).appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    static func removeAllImages() throws {
        let directory = try imagesDirectoryURL()
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for url in urls where isValidAttachmentFileName(url.lastPathComponent) {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// 앱의 명시적 전체 삭제에서만 사용한다. 활성 첨부 파일뿐 아니라 아직 앱에
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
        let attachments = try FileManager.default.contentsOfDirectory(
            at: imagesDirectoryURL(containerURL: containerURL),
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ).filter { isValidAttachmentFileName($0.lastPathComponent) }
        let attachmentBytes = try attachments.reduce(Int64(0)) { partial, url in
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
            originalAttachmentCount: attachments.count,
            originalAttachmentBytes: attachmentBytes,
            pendingCount: pending.count,
            pendingBytes: pendingBytes,
            quarantinedCount: quarantinedCount
        )
    }

    static func isValidImageFileName(_ fileName: String) -> Bool {
        guard isValidAttachmentFileName(fileName) else { return false }
        return safeImageFileExtension((fileName as NSString).pathExtension) != nil
    }

    static func isValidAttachmentFileName(_ fileName: String) -> Bool {
        guard fileName == (fileName as NSString).lastPathComponent else { return false }
        let stem = (fileName as NSString).deletingPathExtension
        guard UUID(uuidString: stem) != nil else { return false }
        return safeAttachmentFileExtension((fileName as NSString).pathExtension) != nil
    }

    static func safeImageFileExtension(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        return supportedImageFileExtensions.contains(normalized) ? normalized : nil
    }

    static func safeAttachmentFileExtension(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        guard normalized.range(of: #"^[a-z0-9_-]{1,12}$"#, options: .regularExpression) != nil else {
            return nil
        }
        return normalized
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
                // 한 Share 호출은 한 원자적 배치다. payload를 해석할 수 없으면
                // 첨부 이름도 신뢰할 수 없으므로 배치 안의 모든 payload/원본을
                // 함께 격리해 마지막 payload 정리 과정에서 원본이 유실되지 않게 한다.
                try? quarantineCommittedBatch(
                    batchDirectory: batchDirectory,
                    containerURL: containerURL
                )
                return nil
            }
            try? quarantine(payloadURL, directoryName: "FailedClips", containerURL: containerURL)
            return nil
        }

        let attachmentNames = Set(
            payload.attachments.compactMap(\.storedFileName)
                + [payload.sharedImageName].compactMap { $0 }
        )
        var pendingAttachmentURLs: [String: URL] = [:]
        if let batchDirectory {
            let attachmentsDirectory = batchDirectory
                .appendingPathComponent(batchImagesDirectoryName, isDirectory: true)
            for name in attachmentNames where isValidAttachmentFileName(name) {
                let candidate = attachmentsDirectory.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    pendingAttachmentURLs[name] = candidate
                }
            }
        }
        let item = Item(
            fileURL: payloadURL,
            payload: payload,
            pendingAttachmentURLs: pendingAttachmentURLs,
            batchDirectoryURL: batchDirectory,
            sourceContainerURL: containerURL
        )
        if payload.type == .image || payload.type == .file || !attachmentNames.isEmpty {
            let allAttachmentsExist = !attachmentNames.isEmpty && attachmentNames.allSatisfy { name in
                guard isValidAttachmentFileName(name) else { return false }
                if pendingAttachmentURLs[name] != nil { return true }
                guard let promotedURL = try? imagesDirectoryURL(containerURL: containerURL)
                    .appendingPathComponent(name) else { return false }
                return FileManager.default.fileExists(atPath: promotedURL.path)
            }
            guard allAttachmentsExist else {
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
        for source in item.pendingAttachmentURLs.values
            where FileManager.default.fileExists(atPath: source.path) {
            try quarantine(
                source,
                directoryName: imageDirectoryName,
                containerURL: item.sourceContainerURL
            )
        }
        if item.batchDirectoryURL == nil {
            let names = Set(
                item.payload.attachments.compactMap(\.storedFileName)
                    + [item.payload.sharedImageName].compactMap { $0 }
            )
            for name in names where isValidAttachmentFileName(name) {
                let legacyAttachment = try imagesDirectoryURL(containerURL: item.sourceContainerURL)
                    .appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: legacyAttachment.path) {
                    try quarantine(
                        legacyAttachment,
                        directoryName: imageDirectoryName,
                        containerURL: item.sourceContainerURL
                    )
                }
            }
        }
        if FileManager.default.fileExists(atPath: item.fileURL.path) {
            try quarantine(item.fileURL, directoryName: directoryName,
                           containerURL: item.sourceContainerURL)
        }
        try cleanupCommittedBatchIfEmpty(item.batchDirectoryURL)
    }

    private static func quarantineCommittedBatch(
        batchDirectory: URL,
        containerURL: URL
    ) throws {
        guard FileManager.default.fileExists(atPath: batchDirectory.path) else { return }

        let attachmentsDirectory = batchDirectory
            .appendingPathComponent(batchImagesDirectoryName, isDirectory: true)
        let attachments = (try? FileManager.default.contentsOfDirectory(
            at: attachmentsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        for attachment in attachments where FileManager.default.fileExists(atPath: attachment.path) {
            try quarantine(
                attachment,
                directoryName: "FailedImages",
                containerURL: containerURL
            )
        }

        let payloadsDirectory = batchDirectory
            .appendingPathComponent(payloadsDirectoryName, isDirectory: true)
        let payloads = (try? FileManager.default.contentsOfDirectory(
            at: payloadsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        for payload in payloads where FileManager.default.fileExists(atPath: payload.path) {
            try quarantine(
                payload,
                directoryName: "FailedClips",
                containerURL: containerURL
            )
        }

        if FileManager.default.fileExists(atPath: batchDirectory.path) {
            try FileManager.default.removeItem(at: batchDirectory)
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
        let names = Set(
            item.payload.attachments.compactMap(\.storedFileName)
                + [item.payload.sharedImageName].compactMap { $0 }
        )
        let attachmentBytes = try names.reduce(Int64(0)) { partial, name in
            let url = item.pendingAttachmentURLs[name]
                ?? attachmentURL(named: name, containerURL: containerURL)
            guard let url, FileManager.default.fileExists(atPath: url.path) else { return partial }
            return partial + Int64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        }
        return payloadBytes + attachmentBytes
    }
}
