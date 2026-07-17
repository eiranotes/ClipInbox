import Foundation
import Observation

/// 인박스 상단 필터. 윗줄은 폴더, 아랫줄은 태그를 나타낸다.
enum InboxFilter: Hashable, Identifiable {
    case all
    case folder(String)
    case tag(String)

    var id: String {
        switch self {
        case .all: return "all"
        case .folder(let label): return "folder:\(label)"
        case .tag(let tag): return "tag:\(tag)"
        }
    }

    var baseLabel: String {
        switch self {
        case .all: return "전체"
        case .folder(let label): return label
        case .tag(let tag): return tag
        }
    }
}

enum StoreError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        if case let .message(text) = self { return L10n.text(text) }
        return nil
    }
}

enum ManualCaptureType: String, CaseIterable, Identifiable {
    case link
    case text
    case photo
    case memo

    var id: String { rawValue }

    var label: String {
        switch self {
        case .link: return "링크"
        case .text: return "텍스트"
        case .photo: return "사진"
        case .memo: return "메모"
        }
    }
}

struct AppStorageSummary: Equatable {
    let snapshotBytes: Int64
    let originalImageCount: Int
    let originalImageBytes: Int64
    let pendingCount: Int
    let pendingPayloadBytes: Int64
    let quarantinedCount: Int
}

@Observable
final class AppStore {
    struct PendingDeletion: Identifiable {
        let id: UUID
        let clips: [Clip]

        var displayTitle: String {
            guard let first = clips.first else { return "" }
            return clips.count == 1
                ? first.presentationTitle
                : L10n.format("format.folder_clip_count", clips.count)
        }
    }

    var clips: [Clip]
    var folders: [Folder]
    var preferences: Preferences
    private(set) var recentSearches: [String]
    private(set) var tagCatalog: [String]
    private(set) var linkOpenMode: LinkOpenMode
    private(set) var bootstrapState: LibraryBootstrapState
    private(set) var storageErrorMessage: String?
    private(set) var pendingDeletion: PendingDeletion? = nil
    private(set) var recoveredLibraryNotice = false
    private(set) var sharedQueueNotice: String? = nil

    var toast: String?
    private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var deletionTask: Task<Void, Never>?

    private let repository: any ClipRepository
    private let userDefaults: UserDefaults
    private static let recentSearchesKey = "clip-inbox-recent-searches-v1"
    private static let recentSearchLimit = 5
    private static let tagCatalogKey = "clip-inbox-tag-catalog-v1"
    private static let linkOpenModeKey = "clip-inbox-link-open-mode-v1"
    private static let onboardingCompletedKey = "clip-inbox-onboarding-completed-v1"
    static let trashRetentionDays = 30
    private static let trashRetentionInterval: TimeInterval = 30 * 24 * 60 * 60

    init(fileURL: URL? = nil, userDefaults: UserDefaults = .standard,
         repository: (any ClipRepository)? = nil) {
        let base = fileURL ?? Self.defaultFileURL()
        self.repository = repository ?? FileClipRepository(fileURL: base)
        self.userDefaults = userDefaults
        recentSearches = Self.normalizeRecentSearches(
            userDefaults.stringArray(forKey: Self.recentSearchesKey) ?? []
        )
        if let storedTags = userDefaults.stringArray(forKey: Self.tagCatalogKey) {
            tagCatalog = Self.normalizeTags(storedTags)
        } else {
            tagCatalog = DefaultData.suggestedTags
        }
        linkOpenMode = LinkOpenMode(rawValue: userDefaults.string(forKey: Self.linkOpenModeKey) ?? "") ?? .direct

        do {
            switch try self.repository.bootstrap() {
            case .firstRun:
                clips = []
                folders = DefaultData.folders
                preferences = .standard
                bootstrapState = .firstRun
            case .loaded(let snapshot):
                let normalized = Self.normalize(snapshot)
                clips = normalized.clips
                folders = normalized.folders
                preferences = normalized.preferences
                bootstrapState = .ready
            case .recovered(let snapshot, _):
                let normalized = Self.normalize(snapshot)
                clips = normalized.clips
                folders = normalized.folders
                preferences = normalized.preferences
                bootstrapState = .recovered
                recoveredLibraryNotice = true
            }
            storageErrorMessage = nil
        } catch ClipRepositoryError.unsupportedVersion(let version) {
            clips = []
            folders = DefaultData.folders
            preferences = .standard
            bootstrapState = .updateRequired(version: version)
            storageErrorMessage = ClipRepositoryError.unsupportedVersion(version).localizedDescription
        } catch {
            clips = []
            folders = DefaultData.folders
            preferences = .standard
            bootstrapState = .recoveryRequired
            storageErrorMessage = error.localizedDescription
        }
        pendingDeletion = nil
        sharedQueueNotice = nil
        _ = purgeExpiredTrash(showFeedback: false)
        try? syncSharedConfiguration()
    }

    private static func defaultFileURL() -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("clip-inbox-data.json")
    }

    // MARK: - 영속화

    func snapshot() -> DataSnapshot {
        DataSnapshot(version: 2, clips: clips, folders: folders, preferences: preferences)
    }

    @discardableResult
    func persist() -> Bool {
        do {
            try repository.commit(snapshot())
            try syncSharedConfiguration()
            storageErrorMessage = nil
            switch bootstrapState {
            case .firstRun, .recovered, .recoveryRequired:
                bootstrapState = .ready
            case .ready, .updateRequired:
                break
            }
            return true
        } catch {
            storageErrorMessage = error.localizedDescription
            return false
        }
    }

    /// Share Extension이 App Group 큐에 남긴 항목을 앱의 기존 version-2 저장소로 옮긴다.
    /// 파일 단위 큐라서 앱과 확장이 동시에 실행되어도 완료된 payload만 읽는다.
    func importSharedClips(containerURL: URL? = nil) {
        let pending: [SharedClipQueue.Item]
        do {
            pending = try SharedClipQueue.pendingItems(containerURL: containerURL)
            let summary = try SharedClipQueue.storageSummary(containerURL: containerURL)
            if summary.quarantinedCount > 0 {
                sharedQueueNotice = L10n.format(
                    "format.quarantined_share_items",
                    summary.quarantinedCount
                )
            }
        } catch {
            sharedQueueNotice = error.localizedDescription
            #if DEBUG
            print("Share queue unavailable: \(error.localizedDescription)")
            #endif
            return
        }
        guard !pending.isEmpty else { return }
        let alreadyImported = pending.filter { item in
            clips.contains(where: { $0.sharePayloadID == item.payload.id })
        }
        for item in alreadyImported { try? SharedClipQueue.remove(item) }
        let candidates = pending.filter { item in
            !clips.contains(where: { $0.sharePayloadID == item.payload.id })
        }
        guard !candidates.isEmpty else { return }

        var nextID = clips.map(\.id).max().map { $0 + 1 } ?? 1

        guard commitMutation({
            for item in candidates {
                let payload = item.payload
                var destination = Self.cleanText(payload.folder, fallback: preferences.defaultFolder, maxLength: 40)
                if ["인박스", "기본 폴더"].contains(destination),
                   !folders.contains(where: { $0.label == destination }),
                   let renamedInbox = folders.first(where: { $0.icon == "inbox" }) {
                    destination = renamedInbox.label
                }
                if !folders.contains(where: { $0.label == destination }) {
                    folders.append(Folder(icon: "folder", label: destination))
                }

                let safeURL = Self.safeExternalURL(payload.url)
                let source = Self.cleanText(
                    payload.source,
                    fallback: URL(string: safeURL)?.host ?? "공유 시트",
                    maxLength: 120
                )
                let titleFallback: String
                switch payload.type {
                case .image: titleFallback = "공유한 이미지"
                case .text: titleFallback = "공유한 텍스트"
                case .link: titleFallback = URL(string: safeURL)?.host ?? "공유한 링크"
                }

                let cleanTags = Array(payload.tags.map {
                    Self.cleanText($0, maxLength: 50)
                }.filter { !$0.isEmpty }.prefix(12))
                let clip = Clip(
                    id: nextID,
                    type: {
                        switch payload.type {
                        case .link: return .link
                        case .text: return .memo
                        case .image: return .image
                        }
                    }(),
                    state: .unsorted,
                    title: Self.cleanText(payload.title, fallback: titleFallback),
                    source: source,
                    url: safeURL,
                    time: "방금 전",
                    folder: destination,
                    tags: cleanTags,
                    folderSuggestions: [destination, "나중에"],
                    sharedImageName: Self.safeSharedImageName(payload.sharedImageName),
                    sharePayloadID: payload.id,
                    description: Self.cleanText(payload.text, maxLength: 500),
                    memo: Self.cleanText(payload.memo, maxLength: 1000)
                )
                clips.insert(clip, at: 0)
                tagCatalog = Self.normalizeTags(tagCatalog + cleanTags)
                nextID += 1
            }
        }) else { return }

        saveTagCatalog()
        for item in candidates {
            try? SharedClipQueue.remove(item)
        }
        showToast(L10n.format("format.imported_shared_clips", candidates.count))
    }

    func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot())
    }

    func storageSummary(containerURL: URL? = nil) throws -> AppStorageSummary {
        let snapshotBytes = Int64(try JSONEncoder().encode(snapshot()).count)
        let shared = try SharedClipQueue.storageSummary(containerURL: containerURL)
        return AppStorageSummary(
            snapshotBytes: snapshotBytes,
            originalImageCount: shared.originalImageCount,
            originalImageBytes: shared.originalImageBytes,
            pendingCount: shared.pendingCount,
            pendingPayloadBytes: shared.pendingPayloadBytes,
            quarantinedCount: shared.quarantinedCount
        )
    }

    func importJSON(_ data: Data) throws {
        guard data.count <= 5_000_000 else { throw StoreError.message("백업 파일은 5MB 이하여야 합니다.") }
        guard let decoded = try? JSONDecoder().decode(DataSnapshot.self, from: data) else {
            throw StoreError.message("지원하지 않는 백업 형식입니다.")
        }
        guard decoded.version == FileClipRepository.supportedVersion else {
            throw StoreError.message(
                L10n.format("format.unsupported_library_version", decoded.version)
            )
        }
        let normalized = Self.normalize(decoded)
        guard commitMutation({
            clips = normalized.clips
            folders = normalized.folders
            preferences = normalized.preferences
            tagCatalog = Self.normalizeTags(
                tagCatalog + clips.flatMap(\.tags) + folders.compactMap(\.defaultTag)
            )
        }) else {
            throw StoreError.message(storageFailureMessage)
        }
        saveTagCatalog()
    }

    // MARK: - 정규화 (웹 프로토타입 normalizeData와 동일 규칙)

    static func cleanText(_ value: String?, fallback: String = "", maxLength: Int = 200) -> String {
        guard let value else { return fallback }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let sliced = String(trimmed.prefix(maxLength))
        return sliced.isEmpty ? fallback : sliced
    }

    static func safeExternalURL(_ value: String) -> String {
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else { return "" }
        return url.absoluteString
    }

    static func safeImagePath(_ value: String?) -> String? {
        guard let value else { return nil }
        let pattern = #"^/public/images/[a-z0-9_-]+\.(png|jpe?g|webp|avif)$"#
        return value.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil ? value : nil
    }

    static func safeSharedImageName(_ value: String?) -> String? {
        guard let value, SharedClipQueue.isValidImageFileName(value) else { return nil }
        return value
    }

    static func normalize(_ input: DataSnapshot) -> DataSnapshot {
        var seenClipIds = Set<Int>()
        var safeClips: [Clip] = []
        for var clip in input.clips {
            guard !seenClipIds.contains(clip.id) else { continue }
            seenClipIds.insert(clip.id)
            clip.title = cleanText(clip.title, fallback: "제목 없는 클립")
            clip.source = cleanText(clip.source, fallback: "출처 없음", maxLength: 120)
            clip.url = safeExternalURL(clip.url)
            if let repository = githubRepositoryTitle(for: clip.url) {
                clip.title = repository
            }
            clip.folder = cleanText(clip.folder, fallback: "인박스", maxLength: 40)
            clip.time = cleanText(clip.time, fallback: "저장됨", maxLength: 40)
            clip.description = cleanText(clip.description, maxLength: 500)
            clip.memo = clip.memo.map { cleanText($0, maxLength: 1000) }
            clip.image = safeImagePath(clip.image)
            clip.sharedImageName = safeSharedImageName(clip.sharedImageName)
            clip.tags = Array(clip.tags.map { cleanText($0, maxLength: 50) }.filter { !$0.isEmpty }.prefix(12))
            clip.folderSuggestions = normalizeFolderSuggestions(clip.folderSuggestions)
            safeClips.append(clip)
        }

        var seenFolderLabels = Set<String>()
        var safeFolders: [Folder] = []
        for folder in input.folders {
            let label = cleanText(folder.label, maxLength: 40)
            guard !label.isEmpty, !seenFolderLabels.contains(label.lowercased()) else { continue }
            seenFolderLabels.insert(label.lowercased())
            safeFolders.append(Folder(icon: cleanText(folder.icon, fallback: "folder", maxLength: 30),
                                      label: label,
                                      defaultTag: folder.defaultTag.map { cleanText($0, maxLength: 50) }))
        }
        safeFolders.removeAll { $0.icon == "trash" }
        if let conflictIndex = safeFolders.firstIndex(where: {
            $0.label.caseInsensitiveCompare("휴지통") == .orderedSame
        }) {
            let original = safeFolders[conflictIndex].label
            var replacement = "휴지통 보관함"
            var suffix = 2
            while safeFolders.contains(where: { $0.label.caseInsensitiveCompare(replacement) == .orderedSame }) {
                replacement = "휴지통 보관함 \(suffix)"
                suffix += 1
            }
            safeFolders[conflictIndex].label = replacement
            for index in safeClips.indices where safeClips[index].folder == original {
                safeClips[index].folder = replacement
            }
        }
        if !safeFolders.contains(where: { $0.icon == "archive" }) {
            safeFolders.insert(Folder(icon: "archive", label: "전체"), at: 0)
        }
        var migratedLegacyInbox = false
        var renamedInboxConflict: (original: String, replacement: String)?
        if let legacyInboxIndex = safeFolders.firstIndex(where: {
            $0.icon == "inbox" && $0.label == "기본 폴더"
        }) {
            if let conflictIndex = safeFolders.indices.first(where: {
                $0 != legacyInboxIndex
                    && safeFolders[$0].label.caseInsensitiveCompare("인박스") == .orderedSame
            }) {
                let original = safeFolders[conflictIndex].label
                var replacement = "인박스 보관함"
                var suffix = 2
                while safeFolders.contains(where: {
                    $0.label.caseInsensitiveCompare(replacement) == .orderedSame
                }) {
                    replacement = "인박스 보관함 \(suffix)"
                    suffix += 1
                }
                safeFolders[conflictIndex].label = replacement
                renamedInboxConflict = (original, replacement)
                for index in safeClips.indices {
                    if safeClips[index].folder.caseInsensitiveCompare(original) == .orderedSame {
                        safeClips[index].folder = replacement
                    }
                    safeClips[index].folderSuggestions = normalizeFolderSuggestions(
                        safeClips[index].folderSuggestions.map {
                            $0.caseInsensitiveCompare(original) == .orderedSame ? replacement : $0
                        }
                    )
                }
            }
            safeFolders[legacyInboxIndex].label = "인박스"
            migratedLegacyInbox = true
            for index in safeClips.indices {
                if safeClips[index].folder == "기본 폴더" {
                    safeClips[index].folder = "인박스"
                    safeClips[index].state = .unsorted
                }
                safeClips[index].folderSuggestions = normalizeFolderSuggestions(
                    safeClips[index].folderSuggestions.map { $0 == "기본 폴더" ? "인박스" : $0 }
                )
            }
        }
        if !safeFolders.contains(where: { $0.icon == "inbox" }) {
            safeFolders.insert(Folder(icon: "inbox", label: "인박스"), at: min(1, safeFolders.count))
        }
        let inboxLabel = safeFolders.first(where: { $0.icon == "inbox" })?.label ?? "인박스"
        let aggregateLabels = Set(
            safeFolders.filter { $0.icon == "archive" }.map { $0.label.lowercased() }
        )
        for index in safeClips.indices {
            if aggregateLabels.contains(safeClips[index].folder.lowercased()) {
                safeClips[index].folder = inboxLabel
            }
            if let match = safeFolders.first(where: { $0.label.lowercased() == safeClips[index].folder.lowercased() }) {
                safeClips[index].folder = match.label
            } else {
                safeFolders.append(Folder(icon: "folder", label: safeClips[index].folder))
            }
        }
        safeFolders.append(Folder(icon: "trash", label: "휴지통"))

        var preferences = input.preferences
        if let renamedInboxConflict,
           preferences.defaultFolder.caseInsensitiveCompare(renamedInboxConflict.original) == .orderedSame {
            preferences.defaultFolder = renamedInboxConflict.replacement
        }
        if migratedLegacyInbox, preferences.defaultFolder == "기본 폴더" {
            preferences.defaultFolder = inboxLabel
        }
        if !["켬", "끔"].contains(preferences.appLock) { preferences.appLock = Preferences.standard.appLock }
        if !["라이트", "다크", "시스템 설정"].contains(preferences.theme) { preferences.theme = Preferences.standard.theme }
        if !AppLanguage.allCases.map(\.rawValue).contains(preferences.language) {
            preferences.language = Preferences.standard.language
        }
        if SharedSaveMode(rawValue: preferences.shareMode) == nil {
            preferences.shareMode = Preferences.standard.shareMode
        }
        if !safeFolders.contains(where: {
            $0.icon != "archive" && $0.icon != "trash" && $0.label == preferences.defaultFolder
        }) {
            preferences.defaultFolder = inboxLabel
        }

        return DataSnapshot(version: 2, clips: safeClips, folders: safeFolders, preferences: preferences)
    }

    // MARK: - 조회

    func clip(id: Int?) -> Clip? {
        guard let id else { return nil }
        return clips.first { $0.id == id }
    }

    var activeClips: [Clip] { clips.filter { !$0.isInTrash } }

    var trashedClips: [Clip] {
        clips.filter(\.isInTrash).sorted {
            ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast)
        }
    }

    func filteredClips(_ filter: InboxFilter) -> [Clip] {
        switch filter {
        case .all:
            return activeClips
        case .folder(let label):
            return activeClips.filter { $0.folder == label }
        case .tag(let tag):
            return activeClips.filter { $0.tags.contains(tag) }
        }
    }

    func filterLabel(_ filter: InboxFilter) -> String {
        "\(L10n.text(filter.baseLabel)) \(filteredClips(filter).count)"
    }

    /// 인박스 필터 윗줄: 전체 + 이동 가능한 폴더 목록.
    var inboxFolderFilters: [InboxFilter] {
        [.all] + destinationFolders.map { .folder($0.label) }
    }

    /// 인박스 필터 아랫줄: 실제 클립에 붙어 있는 태그. 없으면 추천 태그 카탈로그를 보여 준다.
    var inboxTagFilters: [InboxFilter] {
        let used = Self.normalizeTags(activeClips.flatMap(\.tags))
        let tags = used.isEmpty ? tagCatalog : used
        return tags.map { .tag($0) }
    }

    func folderCount(_ label: String) -> Int {
        if isTrashFolder(label) { return trashedClips.count }
        return isAggregateFolder(label)
            ? activeClips.count
            : activeClips.filter { $0.folder == label }.count
    }

    func folderClips(_ label: String) -> [Clip] {
        if isTrashFolder(label) { return trashedClips }
        return isAggregateFolder(label) ? activeClips : activeClips.filter { $0.folder == label }
    }

    var destinationFolders: [Folder] {
        folders.filter { $0.icon != "archive" && $0.icon != "trash" }
    }

    var availableTags: [String] {
        Self.normalizeTags(tagCatalog + clips.flatMap(\.tags) + folders.compactMap(\.defaultTag))
    }

    func isAggregateFolder(_ label: String) -> Bool {
        folders.first(where: { $0.label == label })?.icon == "archive"
    }

    func isTrashFolder(_ label: String) -> Bool {
        folders.first(where: { $0.label == label })?.icon == "trash"
    }

    var unsortedClips: [Clip] { activeClips.filter { $0.state == .unsorted } }

    func searchResults(query: String, filter: InboxFilter) -> [Clip] {
        let term = query.trimmingCharacters(in: .whitespaces).lowercased()
        let matches = term.isEmpty
            ? activeClips
            : activeClips.filter { clip in
                [clip.title, clip.source, clip.tags.joined(separator: " "), clip.description, clip.memo ?? ""]
                    .joined(separator: " ").lowercased().contains(term)
            }
        let scoped: [Clip]
        switch filter {
        case .all:
            scoped = matches
        case .folder(let label):
            scoped = matches.filter { $0.folder == label }
        case .tag(let tag):
            scoped = matches.filter { $0.tags.contains(tag) }
        }
        return term.isEmpty ? Array(scoped.prefix(3)) : scoped
    }

    static func normalizeRecentSearches(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []
        for value in values {
            let clean = cleanText(value, maxLength: 80)
            let key = clean.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard !clean.isEmpty, seen.insert(key).inserted else { continue }
            normalized.append(clean)
            if normalized.count == recentSearchLimit { break }
        }
        return normalized
    }

    static func normalizeTags(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []
        for value in values {
            let clean = cleanText(value, maxLength: 50)
            let key = clean.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard !clean.isEmpty, seen.insert(key).inserted else { continue }
            normalized.append(clean)
        }
        return normalized
    }

    static func normalizeFolderSuggestions(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []
        for value in values {
            let clean = cleanText(value, maxLength: 40)
            let key = clean.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard !clean.isEmpty, seen.insert(key).inserted else { continue }
            normalized.append(clean)
            if normalized.count == 8 { break }
        }
        return normalized
    }

    func recordSearch(_ query: String) {
        guard let clean = Self.normalizeRecentSearches([query]).first else { return }
        let key = clean.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        recentSearches.removeAll {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == key
        }
        recentSearches.insert(clean, at: 0)
        recentSearches = Array(recentSearches.prefix(Self.recentSearchLimit))
        userDefaults.set(recentSearches, forKey: Self.recentSearchesKey)
    }

    // MARK: - 뮤테이션

    private struct RuntimeState {
        let clips: [Clip]
        let folders: [Folder]
        let preferences: Preferences
        let tagCatalog: [String]
        let linkOpenMode: LinkOpenMode
    }

    private var storageFailureMessage: String {
        storageErrorMessage
            ?? L10n.text("변경 내용을 기기에 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도하세요.")
    }

    @discardableResult
    private func commitMutation(_ changes: () -> Void) -> Bool {
        let previous = RuntimeState(
            clips: clips,
            folders: folders,
            preferences: preferences,
            tagCatalog: tagCatalog,
            linkOpenMode: linkOpenMode
        )
        changes()
        guard persist() else {
            clips = previous.clips
            folders = previous.folders
            preferences = previous.preferences
            tagCatalog = previous.tagCatalog
            linkOpenMode = previous.linkOpenMode
            try? repository.commit(snapshot())
            try? syncSharedConfiguration()
            showToast(storageFailureMessage)
            return false
        }
        return true
    }

    @discardableResult
    private func mutate(id: Int, _ update: (inout Clip) -> Void) -> Bool {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return false }
        return commitMutation { update(&clips[index]) }
    }

    @discardableResult
    func toggleBookmark(id: Int) -> Bool {
        mutate(id: id) { $0.bookmarked.toggle() }
    }

    @discardableResult
    func moveClip(id: Int, to folder: String) -> Bool {
        guard mutate(id: id, {
            $0.folder = folder
            $0.state = nil
        }) else { return false }
        showToast(L10n.format("format.moved_to_folder", L10n.text(folder)))
        return true
    }

    /// 선택한 활성 클립을 한 번의 저장 트랜잭션으로 옮긴다.
    @discardableResult
    func moveClips(ids: Set<Int>, to folder: String) -> Bool {
        let activeIDs = Set(clips.lazy.filter { ids.contains($0.id) && !$0.isInTrash }.map(\.id))
        guard !activeIDs.isEmpty else { return false }
        guard commitMutation({
            for index in clips.indices where activeIDs.contains(clips[index].id) {
                clips[index].folder = folder
                clips[index].state = nil
            }
        }) else { return false }
        showToast(L10n.format(
            "format.moved_clips_to_folder",
            activeIDs.count,
            L10n.text(folder)
        ))
        return true
    }

    func updateClip(id: Int, title: String, memo: String, tags: [String]) throws {
        let cleanTitle = Self.cleanText(title, maxLength: 200)
        guard !cleanTitle.isEmpty else { throw StoreError.message("클립 제목을 입력하세요.") }
        guard clips.contains(where: { $0.id == id }) else { throw StoreError.message("클립을 찾을 수 없습니다") }
        let cleanTags = Self.normalizeTags(tags)
        guard commitMutation({
            guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
            clips[index].title = cleanTitle
            clips[index].memo = Self.cleanText(memo, maxLength: 1000)
            clips[index].tags = cleanTags
            tagCatalog = Self.normalizeTags(tagCatalog + cleanTags)
        }) else {
            throw StoreError.message(storageFailureMessage)
        }
        saveTagCatalog()
        showToast("변경 내용을 저장했습니다")
    }

    /// 상세 화면의 태그 행에서 태그만 바로 저장한다. 값이 같으면 저장·토스트를 생략한다.
    @discardableResult
    func updateTags(id: Int, tags: [String]) -> Bool {
        let clean = Array(tags.map { Self.cleanText($0, maxLength: 50) }.filter { !$0.isEmpty }.prefix(12))
        guard let current = clip(id: id) else { return false }
        guard current.tags != clean else { return true }
        guard commitMutation({
            guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
            clips[index].tags = clean
            tagCatalog = Self.normalizeTags(tagCatalog + clean)
        }) else { return false }
        saveTagCatalog()
        showToast("태그를 저장했습니다")
        return true
    }

    @discardableResult
    func updateMemo(id: Int, memo: String) -> Bool {
        guard mutate(id: id, { $0.memo = Self.cleanText(memo, maxLength: 1_000) }) else { return false }
        showToast("노트를 저장했습니다")
        return true
    }

    @discardableResult
    func deleteClip(id: Int) -> Bool {
        deleteClips(ids: [id])
    }

    /// 선택한 활성 클립을 원자적으로 휴지통에 넣고 하나의 Undo 단위로 보존한다.
    @discardableResult
    func deleteClips(ids: Set<Int>) -> Bool {
        let indexes = clips.indices.filter { ids.contains(clips[$0].id) && !clips[$0].isInTrash }
        guard !indexes.isEmpty else { return false }
        finalizePendingDeletion()
        let originals = indexes.map { clips[$0] }
        let deletedAt = Date()
        guard commitMutation({
            for index in indexes { clips[index].deletedAt = deletedAt }
        }) else { return false }
        let deletion = PendingDeletion(id: UUID(), clips: originals)
        pendingDeletion = deletion
        scheduleDeletionFinalization(deletion)
        return true
    }

    @discardableResult
    func undoDelete() -> Bool {
        guard let deletion = pendingDeletion else { return false }
        deletionTask?.cancel()
        let originals = Dictionary(uniqueKeysWithValues: deletion.clips.map { ($0.id, $0) })
        let restorableIDs = Set(clips.lazy.filter {
            originals[$0.id] != nil && $0.isInTrash
        }.map(\.id))
        guard !restorableIDs.isEmpty else {
            pendingDeletion = nil
            deletionTask = nil
            return false
        }
        guard commitMutation({
            for index in clips.indices {
                guard restorableIDs.contains(clips[index].id),
                      let original = originals[clips[index].id] else { continue }
                clips[index] = original
            }
        }) else {
            scheduleDeletionFinalization(deletion)
            return false
        }
        pendingDeletion = nil
        deletionTask = nil
        showToast("삭제를 취소했습니다")
        return true
    }

    @discardableResult
    func restoreClip(id: Int) -> Bool {
        guard let index = clips.firstIndex(where: { $0.id == id && $0.isInTrash }) else { return false }
        guard commitMutation({ clips[index].deletedAt = nil }) else { return false }
        if pendingDeletion?.clips.contains(where: { $0.id == id }) == true { finalizePendingDeletion() }
        showToast("클립을 복원했습니다")
        return true
    }

    @discardableResult
    func emptyTrash() -> Bool {
        let removed = trashedClips
        guard !removed.isEmpty else { return true }
        guard commitMutation({ clips.removeAll { $0.isInTrash } }) else { return false }
        if let pendingIDs = pendingDeletion.map({ Set($0.clips.map(\.id)) }),
           removed.contains(where: { pendingIDs.contains($0.id) }) {
            finalizePendingDeletion()
        }
        removeStoredImages(for: removed)
        showToast("휴지통을 비웠습니다")
        return true
    }

    @discardableResult
    func purgeExpiredTrash(now: Date = Date(), showFeedback: Bool = false) -> Int {
        let cutoff = now.addingTimeInterval(-Self.trashRetentionInterval)
        let expired = clips.filter { clip in
            guard let deletedAt = clip.deletedAt else { return false }
            return deletedAt <= cutoff
        }
        guard !expired.isEmpty else { return 0 }
        let expiredIDs = Set(expired.map(\.id))
        guard commitMutation({ clips.removeAll { expiredIDs.contains($0.id) } }) else { return 0 }
        removeStoredImages(for: expired)
        if showFeedback { showToast(L10n.format("format.auto_deleted_trash", expired.count)) }
        return expired.count
    }

    func trashDaysRemaining(for clip: Clip, now: Date = Date()) -> Int {
        guard let deletedAt = clip.deletedAt else { return Self.trashRetentionDays }
        let expiry = deletedAt.addingTimeInterval(Self.trashRetentionInterval)
        return max(0, Int(ceil(expiry.timeIntervalSince(now) / (24 * 60 * 60))))
    }

    func dismissRecoveredLibraryNotice() {
        recoveredLibraryNotice = false
    }

    func dismissSharedQueueNotice() {
        sharedQueueNotice = nil
    }

    func canonicalManualURL(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host?.lowercased(), !host.isEmpty else { return nil }
        components.scheme = scheme
        components.host = host
        components.fragment = nil
        if components.path == "/" { components.path = "" }
        if (scheme == "https" && components.port == 443) || (scheme == "http" && components.port == 80) {
            components.port = nil
        }
        return components.url?.absoluteString
    }

    @discardableResult
    func createManualClip(type: ManualCaptureType, title: String, url: String, text: String,
                          destination: String, tags: [String], memo: String,
                          imageAsset: SharedImageAsset? = nil) throws -> Clip {
        let id = clips.map(\.id).max().map { $0 + 1 } ?? 1
        let cleanTags = Self.normalizeTags(tags)
        let cleanDestination = Self.cleanText(destination, fallback: preferences.defaultFolder, maxLength: 40)
        let cleanText = Self.cleanText(text, maxLength: 5_000)
        let cleanMemo = Self.cleanText(memo, maxLength: 1_000)
        let cleanTitle = Self.cleanText(title, maxLength: 200)

        let clipType: ClipType
        let finalTitle: String
        let source: String
        let safeURL: String
        let description: String
        var sharedImageName: String?
        var newlyStoredImageName: String?

        switch type {
        case .link:
            guard let normalizedURL = canonicalManualURL(url) else {
                throw StoreError.message("올바른 http 또는 https URL을 입력하세요.")
            }
            clipType = .link
            safeURL = normalizedURL
            source = URL(string: normalizedURL)?.host ?? "직접 추가"
            finalTitle = cleanTitle.isEmpty ? source : cleanTitle
            description = cleanText
        case .text:
            guard !cleanText.isEmpty else { throw StoreError.message("저장할 텍스트를 입력하세요.") }
            clipType = .memo
            safeURL = ""
            source = "직접 추가"
            let firstLine = cleanText.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? "저장한 텍스트"
            finalTitle = cleanTitle.isEmpty ? Self.cleanText(firstLine, maxLength: 200) : cleanTitle
            description = cleanText
        case .memo:
            guard !cleanText.isEmpty else { throw StoreError.message("메모 내용을 입력하세요.") }
            clipType = .memo
            safeURL = ""
            source = "나의 메모"
            let firstLine = cleanText.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? "새 메모"
            finalTitle = cleanTitle.isEmpty ? Self.cleanText(firstLine, maxLength: 200) : cleanTitle
            description = cleanText
        case .photo:
            guard let imageAsset else { throw StoreError.message("저장할 사진을 선택하세요.") }
            clipType = .image
            safeURL = ""
            source = "사진"
            finalTitle = cleanTitle.isEmpty ? "저장한 사진" : cleanTitle
            description = cleanText
            let imageID = UUID()
            do {
                sharedImageName = try SharedClipQueue.storeImageAsset(imageAsset, for: imageID)
                newlyStoredImageName = sharedImageName
            } catch {
                imageAsset.cleanupSourceIfNeeded()
                throw error
            }
            imageAsset.cleanupSourceIfNeeded()
        }

        let clip = Clip(id: id, type: clipType, state: .unsorted,
                        title: finalTitle, source: source, url: safeURL,
                        time: "방금 전", folder: cleanDestination,
                        tags: cleanTags, folderSuggestions: [cleanDestination],
                        sharedImageName: sharedImageName,
                        description: description, memo: cleanMemo)
        guard commitMutation({
            clips.insert(clip, at: 0)
            if !folders.contains(where: { $0.label == cleanDestination }) {
                folders.append(Folder(icon: "folder", label: cleanDestination))
            }
            tagCatalog = Self.normalizeTags(tagCatalog + cleanTags)
        }) else {
            if let newlyStoredImageName { try? SharedClipQueue.removeImage(named: newlyStoredImageName) }
            throw StoreError.message(storageFailureMessage)
        }
        saveTagCatalog()
        showToast(L10n.format("format.saved_to_folder", L10n.text(cleanDestination)))
        return clip
    }

    func createFolder(name: String, defaultTag: String) throws -> String {
        let clean = Self.cleanText(name, maxLength: 40)
        guard !clean.isEmpty else { throw StoreError.message("폴더 이름을 입력하세요.") }
        guard !folders.contains(where: { $0.label.lowercased() == clean.lowercased() }) else {
            throw StoreError.message("같은 이름의 폴더가 이미 있습니다.")
        }
        let cleanDefaultTag = Self.cleanText(defaultTag, maxLength: 50)
        guard commitMutation({
            folders.append(Folder(icon: "folder", label: clean,
                                  defaultTag: cleanDefaultTag.isEmpty ? nil : cleanDefaultTag))
            tagCatalog = Self.normalizeTags(tagCatalog + [cleanDefaultTag])
        }) else {
            throw StoreError.message(storageFailureMessage)
        }
        saveTagCatalog()
        showToast(L10n.format("format.created_folder", clean))
        return clean
    }

    @discardableResult
    func addTag(_ value: String) throws -> String {
        let clean = Self.cleanText(value, maxLength: 50)
        guard !clean.isEmpty else { throw StoreError.message("태그 이름을 입력하세요.") }
        guard !availableTags.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) else {
            throw StoreError.message("같은 이름의 태그가 이미 있습니다.")
        }
        tagCatalog.append(clean)
        saveTagCatalog()
        showToast("태그를 추가했습니다")
        return clean
    }

    func renameTag(from original: String, to value: String) throws {
        let clean = Self.cleanText(value, maxLength: 50)
        guard !clean.isEmpty else { throw StoreError.message("태그 이름을 입력하세요.") }
        guard original != clean else { return }
        guard !availableTags.contains(where: {
            $0 != original && $0.caseInsensitiveCompare(clean) == .orderedSame
        }) else {
            throw StoreError.message("같은 이름의 태그가 이미 있습니다.")
        }

        guard commitMutation({
            tagCatalog = tagCatalog.map { $0 == original ? clean : $0 }
            if !tagCatalog.contains(clean) { tagCatalog.append(clean) }
            for index in clips.indices {
                clips[index].tags = Self.normalizeTags(clips[index].tags.map { $0 == original ? clean : $0 })
            }
            for index in folders.indices where folders[index].defaultTag == original {
                folders[index].defaultTag = clean
            }
        }) else { throw StoreError.message(storageFailureMessage) }
        saveTagCatalog()
        showToast("태그 이름을 변경했습니다")
    }

    @discardableResult
    func deleteTag(_ tag: String) -> Bool {
        guard commitMutation({
            tagCatalog.removeAll { $0 == tag }
            for index in clips.indices {
                clips[index].tags.removeAll { $0 == tag }
            }
            for index in folders.indices where folders[index].defaultTag == tag {
                folders[index].defaultTag = nil
            }
        }) else { return false }
        saveTagCatalog()
        showToast("태그를 삭제했습니다")
        return true
    }

    func renameFolder(from originalLabel: String, to name: String) throws -> String {
        let clean = Self.cleanText(name, maxLength: 40)
        guard !clean.isEmpty else { throw StoreError.message("폴더 이름을 입력하세요.") }
        guard let folderIndex = folders.firstIndex(where: { $0.label == originalLabel }) else {
            throw StoreError.message("폴더를 찾을 수 없습니다.")
        }
        guard !folders.enumerated().contains(where: { index, folder in
            index != folderIndex && folder.label.caseInsensitiveCompare(clean) == .orderedSame
        }) else {
            throw StoreError.message("같은 이름의 폴더가 이미 있습니다.")
        }
        guard clean != originalLabel else { return originalLabel }

        guard commitMutation({
            folders[folderIndex].label = clean
            for index in clips.indices {
                if clips[index].folder == originalLabel {
                    clips[index].folder = clean
                }
                clips[index].folderSuggestions = clips[index].folderSuggestions.map {
                    $0 == originalLabel ? clean : $0
                }
            }
            if preferences.defaultFolder == originalLabel {
                preferences.defaultFolder = clean
            }
        }) else { throw StoreError.message(storageFailureMessage) }
        showToast("폴더 이름을 변경했습니다")
        return clean
    }

    /// 폴더 관리에서 일반 폴더를 제거한다. 안의 클립과 기본 폴더 설정은 인박스로 안전하게 되돌린다.
    @discardableResult
    func deleteFolder(_ label: String) throws -> Bool {
        guard let folder = folders.first(where: { $0.label == label }) else {
            throw StoreError.message("폴더를 찾을 수 없습니다.")
        }
        guard folder.icon != "archive", folder.icon != "inbox", folder.icon != "trash" else {
            throw StoreError.message("기본 폴더는 삭제할 수 없습니다.")
        }
        let inboxLabel = folders.first(where: { $0.icon == "inbox" })?.label ?? "인박스"
        guard commitMutation({
            folders.removeAll { $0.label == label }
            for index in clips.indices {
                if clips[index].folder == label {
                    clips[index].folder = inboxLabel
                    clips[index].state = .unsorted
                }
                clips[index].folderSuggestions = Self.normalizeFolderSuggestions(
                    clips[index].folderSuggestions.map { $0 == label ? inboxLabel : $0 }
                )
            }
            if preferences.defaultFolder == label {
                preferences.defaultFolder = inboxLabel
            }
        }) else {
            throw StoreError.message(storageFailureMessage)
        }
        showToast("폴더를 삭제했습니다")
        return true
    }

    /// 분류하기: 첫 미정리 클립을 지정 폴더로 옮기고 state를 해제한다.
    @discardableResult
    func applySort(to destination: String) -> Bool {
        guard let index = clips.firstIndex(where: { !$0.isInTrash && $0.state == .unsorted }) else { return false }
        return commitMutation {
            clips[index].folder = destination
            clips[index].state = nil
            if !folders.contains(where: { $0.label == destination }) {
                folders.append(Folder(icon: "folder", label: destination))
            }
        }
    }

    @discardableResult
    func updatePreference(key: Preferences.CodingKeys, value: String) -> Bool {
        guard commitMutation({
            switch key {
            case .appLock: preferences.appLock = value
            case .theme: preferences.theme = value
            case .language: preferences.language = value
            case .defaultFolder: preferences.defaultFolder = value
            case .shareMode: preferences.shareMode = value
            }
        }) else { return false }
        showToast("설정을 저장했습니다")
        return true
    }

    func updateLinkOpenMode(_ mode: LinkOpenMode) {
        linkOpenMode = mode
        userDefaults.set(mode.rawValue, forKey: Self.linkOpenModeKey)
        showToast("설정을 저장했습니다")
    }

    @MainActor
    @discardableResult
    func deleteAllData(metadata: URLMetadataCoordinator,
                       containerURL: URL? = nil) async -> Bool {
        deletionTask?.cancel()
        pendingDeletion = nil
        let emptySnapshot = DataSnapshot(
            version: FileClipRepository.supportedVersion,
            clips: [],
            folders: DefaultData.folders,
            preferences: .standard
        )
        do {
            try repository.eraseAllData(replacingWith: emptySnapshot)
        } catch {
            storageErrorMessage = error.localizedDescription
            showToast(storageFailureMessage)
            return false
        }

        clips = []
        folders = DefaultData.folders
        preferences = .standard
        recentSearches = []
        linkOpenMode = .direct
        tagCatalog = DefaultData.suggestedTags
        bootstrapState = .ready
        storageErrorMessage = nil
        recoveredLibraryNotice = false
        sharedQueueNotice = nil

        userDefaults.removeObject(forKey: Self.recentSearchesKey)
        userDefaults.removeObject(forKey: Self.linkOpenModeKey)
        userDefaults.removeObject(forKey: Self.tagCatalogKey)
        userDefaults.removeObject(forKey: Self.onboardingCompletedKey)
        SharedImageCache.removeAll()

        do {
            try SharedClipQueue.removeAllData(containerURL: containerURL)
            try await metadata.removeAllMetadata()
            try syncSharedConfiguration(containerURL: containerURL)
        } catch {
            storageErrorMessage = L10n.text("일부 로컬 데이터를 정리하지 못했습니다. 다시 시도하세요.")
            showToast(storageErrorMessage ?? error.localizedDescription)
            return false
        }

        showToast("로컬 데이터를 삭제했습니다")
        return true
    }

    /// 손상 원본이 복구 폴더에 격리된 뒤 사용자가 명시적으로 새 보관함을 선택할 때만 호출한다.
    @discardableResult
    func startFreshLibraryAfterRecoveryFailure() -> Bool {
        guard bootstrapState == .recoveryRequired else { return false }
        guard commitMutation({
            clips = []
            folders = DefaultData.folders
            preferences = .standard
            tagCatalog = DefaultData.suggestedTags
            linkOpenMode = .direct
        }) else { return false }
        userDefaults.removeObject(forKey: Self.linkOpenModeKey)
        saveTagCatalog()
        showToast("새 보관함을 시작했습니다")
        return true
    }

    // MARK: - 토스트

    func showToast(_ message: String) {
        toastTask?.cancel()
        toast = L10n.text(message)
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            if !Task.isCancelled { self?.toast = nil }
        }
    }

    private func syncSharedConfiguration(containerURL: URL? = nil) throws {
        let destinations = destinationFolders.map(\.label)
        try SharedClipQueue.saveConfiguration(
            SharedClipConfiguration(
                saveMode: preferences.sharedSaveMode,
                language: preferences.appLanguage.sharedValue,
                defaultFolder: preferences.defaultFolder,
                folders: destinations.isEmpty ? [preferences.defaultFolder] : destinations,
                theme: preferences.theme
            ),
            containerURL: containerURL
        )
    }

    private func mergeTagsIntoCatalog(_ tags: [String]) {
        let merged = Self.normalizeTags(tagCatalog + tags)
        guard merged != tagCatalog else { return }
        tagCatalog = merged
        saveTagCatalog()
    }

    private func saveTagCatalog() {
        userDefaults.set(tagCatalog, forKey: Self.tagCatalogKey)
    }

    private func scheduleDeletionFinalization(_ deletion: PendingDeletion) {
        deletionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.finalizePendingDeletion(id: deletion.id)
        }
    }

    private func finalizePendingDeletion(id: UUID? = nil) {
        guard let deletion = pendingDeletion,
              id == nil || deletion.id == id else { return }
        deletionTask?.cancel()
        pendingDeletion = nil
        deletionTask = nil
    }

    private func removeStoredImages(for clips: [Clip]) {
        for imageName in Set(clips.compactMap(\.sharedImageName)) {
            try? SharedClipQueue.removeImage(named: imageName)
        }
    }
}
