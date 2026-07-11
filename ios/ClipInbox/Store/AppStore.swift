import Foundation
import Observation

enum InboxFilter: String, CaseIterable, Identifiable {
    case all, unsorted, link, image, memo, screenshot
    case interior, reference, idea, travel

    var id: String { rawValue }

    var clipType: ClipType? {
        switch self {
        case .link: return .link
        case .image: return .image
        case .memo: return .memo
        case .screenshot: return .screenshot
        default: return nil
        }
    }

    var baseLabel: String {
        switch self {
        case .all: return "전체"
        case .unsorted: return "미정리"
        case .interior: return "인테리어"
        case .reference: return "레퍼런스"
        case .idea: return "아이디어"
        case .travel: return "여행"
        default: return clipType?.label ?? ""
        }
    }

    var tag: String? {
        switch self {
        case .interior, .reference, .idea, .travel: return baseLabel
        default: return nil
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

@Observable
final class AppStore {
    var clips: [Clip]
    var folders: [Folder]
    var preferences: Preferences
    private(set) var recentSearches: [String]
    private(set) var tagCatalog: [String]
    private(set) var linkOpenMode: LinkOpenMode
    private(set) var bootstrapState: LibraryBootstrapState
    private(set) var storageErrorMessage: String?

    var toast: String?
    private var toastTask: Task<Void, Never>?

    private let repository: any ClipRepository
    private let userDefaults: UserDefaults
    private static let recentSearchesKey = "clip-inbox-recent-searches-v1"
    private static let recentSearchLimit = 5
    private static let tagCatalogKey = "clip-inbox-tag-catalog-v1"
    private static let linkOpenModeKey = "clip-inbox-link-open-mode-v1"

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
        syncSharedConfiguration()
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
            storageErrorMessage = nil
            switch bootstrapState {
            case .firstRun, .recovered, .recoveryRequired:
                bootstrapState = .ready
            case .ready, .updateRequired:
                break
            }
            syncSharedConfiguration()
            return true
        } catch {
            storageErrorMessage = error.localizedDescription
            return false
        }
    }

    /// Share Extension이 App Group 큐에 남긴 항목을 앱의 기존 version-2 저장소로 옮긴다.
    /// 파일 단위 큐라서 앱과 확장이 동시에 실행되어도 완료된 payload만 읽는다.
    func importSharedClips() {
        let pending: [SharedClipQueue.Item]
        do {
            pending = try SharedClipQueue.pendingItems()
        } catch {
            #if DEBUG
            print("Share queue unavailable: \(error.localizedDescription)")
            #endif
            return
        }
        guard !pending.isEmpty else { return }

        let originalClips = clips
        let originalFolders = folders
        var nextID = clips.map(\.id).max().map { $0 + 1 } ?? 1

        for item in pending {
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

            let clip = Clip(
                id: nextID,
                type: {
                    switch payload.type {
                    case .link: return .link
                    case .text: return .memo
                    case .image: return .image
                    }
                }(),
                state: .new,
                title: Self.cleanText(payload.title, fallback: titleFallback),
                source: source,
                url: safeURL,
                time: "방금 전",
                folder: destination,
                tags: Array(payload.tags.map { Self.cleanText($0, maxLength: 50) }.filter { !$0.isEmpty }.prefix(12)),
                folderSuggestions: [destination, "나중에"],
                sharedImageName: Self.safeSharedImageName(payload.sharedImageName),
                description: Self.cleanText(payload.text, maxLength: 500),
                memo: Self.cleanText(payload.memo, maxLength: 1000)
            )
            clips.insert(clip, at: 0)
            nextID += 1
        }

        guard persist() else {
            clips = originalClips
            folders = originalFolders
            showToast("공유한 클립을 가져오지 못했습니다")
            return
        }

        for item in pending {
            try? SharedClipQueue.remove(item)
        }
        mergeTagsIntoCatalog(pending.flatMap(\.payload.tags))
        showToast(L10n.format("format.imported_shared_clips", pending.count))
    }

    func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot())
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
            clip.folder = cleanText(clip.folder, fallback: "기본 폴더", maxLength: 40)
            clip.time = cleanText(clip.time, fallback: "저장됨", maxLength: 40)
            clip.description = cleanText(clip.description, maxLength: 500)
            clip.memo = clip.memo.map { cleanText($0, maxLength: 1000) }
            clip.image = safeImagePath(clip.image)
            clip.sharedImageName = safeSharedImageName(clip.sharedImageName)
            clip.tags = Array(clip.tags.map { cleanText($0, maxLength: 50) }.filter { !$0.isEmpty }.prefix(12))
            clip.folderSuggestions = Array(clip.folderSuggestions.map { cleanText($0, maxLength: 40) }.filter { !$0.isEmpty }.prefix(8))
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
        if !safeFolders.contains(where: { $0.icon == "archive" }) {
            safeFolders.insert(Folder(icon: "archive", label: "전체"), at: 0)
        }
        if !safeFolders.contains(where: { $0.icon == "inbox" }) {
            safeFolders.insert(Folder(icon: "inbox", label: "기본 폴더"), at: min(1, safeFolders.count))
        }
        let inboxLabel = safeFolders.first(where: { $0.icon == "inbox" })?.label ?? "기본 폴더"
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

        var preferences = input.preferences
        if !["켬", "끔"].contains(preferences.appLock) { preferences.appLock = Preferences.standard.appLock }
        if !["라이트", "다크", "시스템 설정"].contains(preferences.theme) { preferences.theme = Preferences.standard.theme }
        if !AppLanguage.allCases.map(\.rawValue).contains(preferences.language) {
            preferences.language = Preferences.standard.language
        }
        if SharedSaveMode(rawValue: preferences.shareMode) == nil {
            preferences.shareMode = Preferences.standard.shareMode
        }
        if !safeFolders.contains(where: { $0.icon != "archive" && $0.label == preferences.defaultFolder }) {
            preferences.defaultFolder = inboxLabel
        }

        return DataSnapshot(version: 2, clips: safeClips, folders: safeFolders, preferences: preferences)
    }

    // MARK: - 조회

    func clip(id: Int?) -> Clip? {
        guard let id else { return nil }
        return clips.first { $0.id == id }
    }

    func filteredClips(_ filter: InboxFilter) -> [Clip] {
        if let tag = filter.tag {
            return clips.filter { $0.tags.contains(tag) }
        }
        switch filter {
        case .all: return clips
        case .unsorted: return clips.filter { $0.state == .unsorted }
        default: return clips.filter { $0.type == filter.clipType }
        }
    }

    func filterLabel(_ filter: InboxFilter) -> String {
        "\(L10n.text(filter.baseLabel)) \(filteredClips(filter).count)"
    }

    func folderCount(_ label: String) -> Int {
        isAggregateFolder(label) ? clips.count : clips.filter { $0.folder == label }.count
    }

    func folderClips(_ label: String) -> [Clip] {
        isAggregateFolder(label) ? clips : clips.filter { $0.folder == label }
    }

    var destinationFolders: [Folder] {
        folders.filter { $0.icon != "archive" }
    }

    var availableTags: [String] {
        Self.normalizeTags(tagCatalog + clips.flatMap(\.tags) + folders.compactMap(\.defaultTag))
    }

    func isAggregateFolder(_ label: String) -> Bool {
        folders.first(where: { $0.label == label })?.icon == "archive"
    }

    var unsortedClips: [Clip] { clips.filter { $0.state == .unsorted } }

    func searchResults(query: String, filter: String) -> [Clip] {
        let term = query.trimmingCharacters(in: .whitespaces).lowercased()
        let base: [Clip] = term.isEmpty
            ? Array(clips.prefix(3))
            : clips.filter { clip in
                [clip.title, clip.source, clip.tags.joined(separator: " "), clip.description, clip.memo ?? ""]
                    .joined(separator: " ").lowercased().contains(term)
            }
        if filter == "전체" { return base }
        if filter == "태그" {
            return term.isEmpty ? base : base.filter { $0.tags.joined(separator: " ").lowercased().contains(term) }
        }
        return base.filter { $0.type.label == filter || $0.tags.contains(filter) }
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
        guard mutate(id: id, { $0.folder = folder }) else { return false }
        showToast(L10n.format("format.moved_to_folder", L10n.text(folder)))
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
        let sharedImageName = clips.first(where: { $0.id == id })?.sharedImageName
        guard clips.contains(where: { $0.id == id }) else { return false }
        guard commitMutation({ clips.removeAll { $0.id == id } }) else { return false }
        if let sharedImageName { try? SharedClipQueue.removeImage(named: sharedImageName) }
        showToast("클립을 삭제했습니다")
        return true
    }

    @discardableResult
    func saveNewClip(destination: String, tags: [String], memo: String) throws -> Clip {
        let id = clips.map(\.id).max().map { $0 + 1 } ?? 1
        let cleanTags = Self.normalizeTags(tags)
        let clip = Clip(id: id, type: .link, state: .new,
                        title: "미니멀 인테리어 아이디어 모음 50", source: "brunch.co.kr",
                        url: "https://brunch.co.kr", time: "방금 전", folder: destination,
                        tags: cleanTags, folderSuggestions: [destination, "디자인", "나중에"],
                        image: "/public/images/clip-living-room.png",
                        description: "공유 화면에서 방금 저장한 클립입니다.",
                        memo: Self.cleanText(memo, maxLength: 1000))
        guard commitMutation({
            clips.insert(clip, at: 0)
            tagCatalog = Self.normalizeTags(tagCatalog + cleanTags)
        }) else {
            throw StoreError.message(storageFailureMessage)
        }
        saveTagCatalog()
        showToast(L10n.format("format.saved_to_folder", L10n.text(destination)))
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

    /// 분류하기: 첫 미정리 클립을 지정 폴더로 옮기고 state를 해제한다.
    @discardableResult
    func applySort(to destination: String) -> Bool {
        guard let index = clips.firstIndex(where: { $0.state == .unsorted }) else { return false }
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

    @discardableResult
    func deleteAllData() -> Bool {
        guard commitMutation({
            clips = []
            folders = DefaultData.folders
            preferences = .standard
            linkOpenMode = .direct
            tagCatalog = DefaultData.suggestedTags
        }) else { return false }
        userDefaults.removeObject(forKey: Self.linkOpenModeKey)
        saveTagCatalog()
        try? SharedClipQueue.removeAllImages()
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

    private func syncSharedConfiguration() {
        let destinations = destinationFolders.map(\.label)
        SharedClipQueue.saveConfiguration(
            SharedClipConfiguration(
                saveMode: preferences.sharedSaveMode,
                language: preferences.appLanguage.sharedValue,
                defaultFolder: preferences.defaultFolder,
                folders: destinations.isEmpty ? [preferences.defaultFolder] : destinations,
                theme: preferences.theme
            )
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
}
