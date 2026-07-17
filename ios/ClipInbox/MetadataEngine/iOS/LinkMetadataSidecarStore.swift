import Foundation

actor LinkMetadataSidecarStore {
    struct Entry: Codable, Equatable, Sendable {
        var clipID: Int
        var sourceURL: String
        var result: LinkMetadataResult
        var updatedAt: Date
    }

    private struct Snapshot: Codable {
        var version: Int
        var entries: [Entry]
    }

    private let fileURL: URL
    private var entries: [Int: Entry] = [:]
    private var loaded = false

    init(fileURL: URL = LinkMetadataSidecarStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    func all() -> [Int: LinkMetadataResult] {
        loadIfNeeded()
        return entries.mapValues(\.result)
    }

    func entry(for clipID: Int) -> Entry? {
        loadIfNeeded()
        return entries[clipID]
    }

    func store(_ result: LinkMetadataResult, clipID: Int, sourceURL: String) throws {
        loadIfNeeded()
        entries[clipID] = Entry(clipID: clipID, sourceURL: sourceURL, result: result, updatedAt: Date())
        try persist()
    }

    func remove(clipID: Int) throws {
        loadIfNeeded()
        entries[clipID] = nil
        try persist()
    }

    func prune(validClipIDs: Set<Int>) throws {
        loadIfNeeded()
        entries = entries.filter { validClipIDs.contains($0.key) }
        try persist()
    }

    func removeAll() throws {
        entries.removeAll()
        loaded = true
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder.sidecar.decode(Snapshot.self, from: data),
              snapshot.version == 1 else { return }
        entries = Dictionary(uniqueKeysWithValues: snapshot.entries.map { ($0.clipID, $0) })
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let snapshot = Snapshot(version: 1, entries: entries.values.sorted { $0.clipID < $1.clipID })
        let data = try JSONEncoder.sidecar.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }

    static func defaultDirectory() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("ClipInboxMetadata", isDirectory: true)
    }

    static func defaultFileURL() -> URL {
        defaultDirectory().appendingPathComponent("link-metadata-v1.json")
    }
}

private extension JSONEncoder {
    static var sidecar: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var sidecar: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
