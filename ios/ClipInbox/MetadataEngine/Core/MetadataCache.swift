import Foundation

protocol MetadataCaching: Sendable {
    func value(for key: String) async -> LinkMetadataResult?
    func store(_ value: LinkMetadataResult, for keys: [String], ttl: TimeInterval) async
    func removeAll() async
}

actor MemoryMetadataCache: MetadataCaching {
    private struct Entry: Sendable {
        var value: LinkMetadataResult
        var expiresAt: Date
    }

    private var entries: [String: Entry] = [:]

    func value(for key: String) -> LinkMetadataResult? {
        let normalized = Self.normalize(key)
        guard let entry = entries[normalized] else { return nil }
        guard entry.expiresAt > Date() else {
            entries[normalized] = nil
            return nil
        }
        return entry.value
    }

    func store(_ value: LinkMetadataResult, for keys: [String], ttl: TimeInterval) {
        let entry = Entry(value: value, expiresAt: Date().addingTimeInterval(ttl))
        for key in keys where !key.isEmpty {
            entries[Self.normalize(key)] = entry
        }
    }

    func removeAll() {
        entries.removeAll()
    }

    private static func normalize(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

actor DiskMetadataCache: MetadataCaching {
    private struct Entry: Codable, Sendable {
        var value: LinkMetadataResult
        var expiresAt: Date
    }

    private let fileURL: URL
    private var loaded = false
    private var entries: [String: Entry] = [:]

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func value(for key: String) async -> LinkMetadataResult? {
        await loadIfNeeded()
        let normalized = Self.normalize(key)
        guard let entry = entries[normalized] else { return nil }
        guard entry.expiresAt > Date() else {
            entries[normalized] = nil
            try? persist()
            return nil
        }
        return entry.value
    }

    func store(_ value: LinkMetadataResult, for keys: [String], ttl: TimeInterval) async {
        await loadIfNeeded()
        let entry = Entry(value: value, expiresAt: Date().addingTimeInterval(ttl))
        for key in keys where !key.isEmpty {
            entries[Self.normalize(key)] = entry
        }
        prune()
        try? persist()
    }

    func removeAll() async {
        entries.removeAll()
        loaded = true
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func loadIfNeeded() async {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder.cache.decode([String: Entry].self, from: data) else { return }
        entries = decoded
        prune()
    }

    private func prune() {
        let now = Date()
        entries = entries.filter { $0.value.expiresAt > now }
        if entries.count > 1_000 {
            let retained = entries.sorted { $0.value.expiresAt > $1.value.expiresAt }.prefix(750)
            entries = Dictionary(uniqueKeysWithValues: retained.map { ($0.key, $0.value) })
        }
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.cache.encode(entries)
        try data.write(to: fileURL, options: [.atomic])
    }

    private static func normalize(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private extension JSONEncoder {
    static var cache: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var cache: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
