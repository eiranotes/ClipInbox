import Foundation

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

enum SharedClipQueue {
    static let appGroupIdentifier = "group.app.clipinbox.ClipInbox"

    struct Item {
        let fileURL: URL
        let payload: SharedClipPayload
    }

    enum QueueError: LocalizedError {
        case appGroupUnavailable

        var errorDescription: String? {
            "Clip Inbox App Group 컨테이너를 열 수 없습니다. 서명과 App Group 권한을 확인하세요."
        }
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

    static func storeImageData(_ data: Data, for id: UUID) throws -> String {
        let fileName = "\(id.uuidString).jpg"
        let fileURL = try imagesDirectoryURL().appendingPathComponent(fileName)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        return fileName
    }

    static func imageURL(named fileName: String) -> URL? {
        guard fileName == (fileName as NSString).lastPathComponent,
              fileName.range(of: #"^[A-F0-9-]{36}\.jpg$"#, options: [.regularExpression, .caseInsensitive]) != nil else {
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
        for url in urls where url.pathExtension.lowercased() == "jpg" {
            try FileManager.default.removeItem(at: url)
        }
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
