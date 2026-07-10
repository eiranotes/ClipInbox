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
        if case let .message(text) = self { return text }
        return nil
    }
}

@Observable
final class AppStore {
    var clips: [Clip]
    var folders: [Folder]
    var preferences: Preferences
    private(set) var recentSearches: [String]

    var toast: String?
    private var toastTask: Task<Void, Never>?

    private let fileURL: URL
    private let recentSearchDefaults: UserDefaults
    private static let recentSearchesKey = "clip-inbox-recent-searches-v1"
    private static let recentSearchLimit = 5

    init(fileURL: URL? = nil, userDefaults: UserDefaults = .standard) {
        let base = fileURL ?? Self.defaultFileURL()
        self.fileURL = base
        recentSearchDefaults = userDefaults
        recentSearches = Self.normalizeRecentSearches(
            userDefaults.stringArray(forKey: Self.recentSearchesKey) ?? []
        )
        if let data = try? Data(contentsOf: base),
           let snapshot = try? JSONDecoder().decode(DataSnapshot.self, from: data) {
            let normalized = Self.normalize(snapshot)
            clips = normalized.clips
            folders = normalized.folders
            preferences = normalized.preferences
        } else {
            clips = DefaultData.clips
            folders = DefaultData.folders
            preferences = .standard
        }
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
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(snapshot())
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
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
            var destination = Self.cleanText(payload.folder, fallback: "인박스", maxLength: 40)
            if destination == "인박스",
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
        showToast("공유한 클립 \(pending.count)개를 인박스에 추가했습니다")
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
        let normalized = Self.normalize(decoded)
        clips = normalized.clips
        folders = normalized.folders
        preferences = normalized.preferences
        persist()
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
        guard let value,
              value == (value as NSString).lastPathComponent,
              value.range(of: #"^[A-F0-9-]{36}\.jpg$"#, options: [.regularExpression, .caseInsensitive]) != nil else {
            return nil
        }
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
            clip.folder = cleanText(clip.folder, fallback: "인박스", maxLength: 40)
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

        var preferences = input.preferences
        if !["켬", "끔"].contains(preferences.appLock) { preferences.appLock = Preferences.standard.appLock }
        if !["라이트", "시스템 설정"].contains(preferences.theme) { preferences.theme = Preferences.standard.theme }
        if !["한국어", "English"].contains(preferences.language) { preferences.language = Preferences.standard.language }
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
        "\(filter.baseLabel) \(filteredClips(filter).count)"
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

    func recordSearch(_ query: String) {
        guard let clean = Self.normalizeRecentSearches([query]).first else { return }
        let key = clean.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        recentSearches.removeAll {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == key
        }
        recentSearches.insert(clean, at: 0)
        recentSearches = Array(recentSearches.prefix(Self.recentSearchLimit))
        recentSearchDefaults.set(recentSearches, forKey: Self.recentSearchesKey)
    }

    // MARK: - 뮤테이션

    private func mutate(id: Int, _ update: (inout Clip) -> Void) {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        update(&clips[index])
        persist()
    }

    func toggleBookmark(id: Int) {
        mutate(id: id) { $0.bookmarked.toggle() }
    }

    func moveClip(id: Int, to folder: String) {
        mutate(id: id) { $0.folder = folder }
        showToast("\(folder.withRoParticle) 이동했습니다")
    }

    func updateClip(id: Int, title: String, memo: String, tags: [String]) throws {
        let cleanTitle = Self.cleanText(title, maxLength: 200)
        guard !cleanTitle.isEmpty else { throw StoreError.message("클립 제목을 입력하세요.") }
        mutate(id: id) {
            $0.title = cleanTitle
            $0.memo = Self.cleanText(memo, maxLength: 1000)
            $0.tags = tags
        }
        showToast("변경 내용을 저장했습니다")
    }

    /// 상세 화면의 태그 행에서 태그만 바로 저장한다. 값이 같으면 저장·토스트를 생략한다.
    func updateTags(id: Int, tags: [String]) {
        let clean = Array(tags.map { Self.cleanText($0, maxLength: 50) }.filter { !$0.isEmpty }.prefix(12))
        guard let current = clip(id: id), current.tags != clean else { return }
        mutate(id: id) { $0.tags = clean }
        showToast("태그를 저장했습니다")
    }

    func updateMemo(id: Int, memo: String) {
        mutate(id: id) { $0.memo = Self.cleanText(memo, maxLength: 1_000) }
        showToast("노트를 저장했습니다")
    }

    func deleteClip(id: Int) {
        let sharedImageName = clips.first(where: { $0.id == id })?.sharedImageName
        clips.removeAll { $0.id == id }
        if persist(), let sharedImageName { try? SharedClipQueue.removeImage(named: sharedImageName) }
        showToast("클립을 삭제했습니다")
    }

    @discardableResult
    func saveNewClip(destination: String, tags: [String], memo: String) -> Clip {
        let id = clips.map(\.id).max().map { $0 + 1 } ?? 1
        let clip = Clip(id: id, type: .link, state: .new,
                        title: "미니멀 인테리어 아이디어 모음 50", source: "brunch.co.kr",
                        url: "https://brunch.co.kr", time: "방금 전", folder: destination,
                        tags: tags, folderSuggestions: [destination, "디자인", "나중에"],
                        image: "/public/images/clip-living-room.png",
                        description: "공유 화면에서 방금 저장한 클립입니다.",
                        memo: Self.cleanText(memo, maxLength: 1000))
        clips.insert(clip, at: 0)
        persist()
        showToast("\(destination)에 저장했습니다")
        return clip
    }

    func createFolder(name: String, defaultTag: String) throws -> String {
        let clean = Self.cleanText(name, maxLength: 40)
        guard !clean.isEmpty else { throw StoreError.message("폴더 이름을 입력하세요.") }
        guard !folders.contains(where: { $0.label.lowercased() == clean.lowercased() }) else {
            throw StoreError.message("같은 이름의 폴더가 이미 있습니다.")
        }
        folders.append(Folder(icon: "folder", label: clean, defaultTag: defaultTag))
        persist()
        showToast("\(clean) 폴더를 만들었습니다")
        return clean
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

        let originalFolders = folders
        let originalClips = clips
        let originalPreferences = preferences

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

        guard persist() else {
            folders = originalFolders
            clips = originalClips
            preferences = originalPreferences
            throw StoreError.message("폴더 이름을 저장하지 못했습니다.")
        }
        showToast("폴더 이름을 변경했습니다")
        return clean
    }

    /// 분류하기: 첫 미정리 클립을 지정 폴더로 옮기고 state를 해제한다.
    func applySort(to destination: String) {
        guard let index = clips.firstIndex(where: { $0.state == .unsorted }) else { return }
        clips[index].folder = destination
        clips[index].state = nil
        if !folders.contains(where: { $0.label == destination }) {
            folders.append(Folder(icon: "folder", label: destination))
        }
        persist()
    }

    func updatePreference(key: Preferences.CodingKeys, value: String) {
        switch key {
        case .appLock: preferences.appLock = value
        case .theme: preferences.theme = value
        case .language: preferences.language = value
        case .defaultFolder: preferences.defaultFolder = value
        }
        persist()
        showToast("설정을 저장했습니다")
    }

    func deleteAllData() {
        clips = []
        folders = DefaultData.folders
        preferences = .standard
        if persist() { try? SharedClipQueue.removeAllImages() }
        showToast("로컬 데이터를 삭제했습니다")
    }

    // MARK: - 토스트

    func showToast(_ message: String) {
        toastTask?.cancel()
        toast = message
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            if !Task.isCancelled { self?.toast = nil }
        }
    }
}
