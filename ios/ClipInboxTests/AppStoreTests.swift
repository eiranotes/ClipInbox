import XCTest
import UIKit
import UniformTypeIdentifiers
import LocalAuthentication
@testable import ClipInbox

private final class TestClipRepository: ClipRepository {
    let bootstrapHandler: () throws -> ClipBootstrapResult
    var commitError: Error?
    private(set) var committedSnapshots: [DataSnapshot] = []

    init(bootstrapHandler: @escaping () throws -> ClipBootstrapResult,
         commitError: Error? = nil) {
        self.bootstrapHandler = bootstrapHandler
        self.commitError = commitError
    }

    func bootstrap() throws -> ClipBootstrapResult {
        try bootstrapHandler()
    }

    func commit(_ snapshot: DataSnapshot) throws {
        if let commitError { throw commitError }
        committedSnapshots.append(snapshot)
    }

    func eraseAllData(replacingWith snapshot: DataSnapshot) throws {
        if let commitError { throw commitError }
        committedSnapshots.append(snapshot)
    }
}

private final class TestLockAuthenticator: AppLockAuthenticating {
    var available: Bool
    var result: Bool
    var error: Error?
    private(set) var cancelCount = 0

    init(available: Bool, result: Bool = false, error: Error? = nil) {
        self.available = available
        self.result = result
        self.error = error
    }

    func canAuthenticate() -> Bool { available }

    func authenticate(reason: String) async throws -> Bool {
        if let error { throw error }
        return result
    }

    func cancel() { cancelCount += 1 }
}

final class AppStoreTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var dataURL: URL!
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipInboxTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        dataURL = temporaryDirectory.appendingPathComponent("clip-inbox-data.json")

        defaultsSuiteName = "ClipInboxTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        try? FileManager.default.removeItem(at: temporaryDirectory)
        defaults = nil
        defaultsSuiteName = nil
        dataURL = nil
        temporaryDirectory = nil
    }

    private func seedDefaultLibrary() throws {
        let snapshot = DataSnapshot(
            version: 2,
            clips: DefaultData.clips,
            folders: DefaultData.folders,
            preferences: .standard
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(snapshot).write(to: dataURL, options: .atomic)
    }

    func testRecentSearchesAreRealDeduplicatedLimitedAndPersisted() {
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        XCTAssertTrue(store.recentSearches.isEmpty)
        ["하나", "둘", "셋", "넷", "다섯", "여섯", "  셋  "].forEach(store.recordSearch)
        store.recordSearch("   ")

        XCTAssertEqual(store.recentSearches, ["셋", "여섯", "다섯", "넷", "둘"])

        let reloaded = AppStore(fileURL: dataURL, userDefaults: defaults)
        XCTAssertEqual(reloaded.recentSearches, store.recentSearches)
    }

    func testDefaultTagFiltersAndSearchUseClipTags() throws {
        try seedDefaultLibrary()
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        XCTAssertEqual(store.filteredClips(.tag("인테리어")).map(\.id), [1])
        XCTAssertEqual(store.filteredClips(.tag("레퍼런스")).map(\.id), [2])
        XCTAssertEqual(store.filteredClips(.tag("아이디어")).map(\.id), [3])
        XCTAssertEqual(store.filteredClips(.tag("여행")).map(\.id), [4])
        XCTAssertEqual(store.filteredClips(.folder("폴더 2")).map(\.id), [1])
        XCTAssertEqual(store.filteredClips(.all).count, store.activeClips.count)
        XCTAssertEqual(store.searchResults(query: "대시보드", filter: .tag("레퍼런스")).map(\.id), [2])
        XCTAssertEqual(store.searchResults(query: "아이디어", filter: .tag("아이디어")).map(\.id), [3])
    }

    func testSmartViewsContainOnlyActiveMatchingClips() throws {
        try seedDefaultLibrary()
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        XCTAssertEqual(store.filteredClips(.unsorted).map(\.id), [1, 5])
        XCTAssertFalse(store.filteredClips(.unsorted).contains { $0.state == .new })
        XCTAssertTrue(store.toggleBookmark(id: 2))
        XCTAssertEqual(store.filteredClips(.bookmarked).map(\.id), [2])
        XCTAssertTrue(store.deleteClip(id: 1))
        XCTAssertEqual(store.filteredClips(.unsorted).map(\.id), [5])
        XCTAssertEqual(Array(store.inboxScopeFilters.prefix(3)), [.all, .unsorted, .bookmarked])
    }

    func testSearchIncludesURLsMetadataAndIntersectsSmartView() throws {
        try seedDefaultLibrary()
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)
        let metadataText = [1: "Café accessibility research"]

        XCTAssertEqual(store.searchResults(query: "product-store", filter: .all).map(\.id), [5])
        XCTAssertEqual(
            store.searchResults(
                query: "CAFE",
                filter: .unsorted,
                additionalTextByClipID: metadataText
            ).map(\.id),
            [1]
        )
        XCTAssertTrue(store.toggleBookmark(id: 1))
        XCTAssertEqual(
            store.searchResults(
                query: "accessibility",
                filter: .bookmarked,
                additionalTextByClipID: metadataText
            ).map(\.id),
            [1]
        )
        XCTAssertTrue(store.toggleBookmark(id: 1))
        XCTAssertTrue(
            store.searchResults(
                query: "accessibility",
                filter: .bookmarked,
                additionalTextByClipID: metadataText
            ).isEmpty
        )
    }

    func testMetadataSearchProjectionIncludesContentAndExcludesDiagnostics() {
        let result = LinkMetadataResult(
            originalURL: "https://example.com/original",
            resolvedURL: "https://example.com/resolved",
            platform: "knowledge",
            contentType: "article",
            title: ExtractedField(value: "Readable title", source: .openGraph, confidence: 1),
            description: ExtractedField(value: "Useful description", source: .semanticDOM, confidence: 1),
            summaryShort: ExtractedField(value: "Concise summary", source: .derived, confidence: 1),
            siteName: ExtractedField(value: "Example Site", source: .openGraph, confidence: 1),
            creator: ExtractedField(value: "Ada", source: .jsonLD, confidence: 1),
            thumbnail: ExtractedField(value: "https://secret.example/thumbnail.jpg", source: .openGraph, confidence: 1),
            originalTags: [ExtractedField(value: ["Research"], source: .jsonLD, confidence: 1)],
            derivedTopics: [ExtractedField(value: ["Accessibility"], source: .derived, confidence: 1)],
            attributes: [
                "nested": ExtractedField(
                    value: .object(["topic": .array([.string("Deep Work"), .number(42)])]),
                    source: .jsonLD,
                    confidence: 1
                )
            ],
            volatileAttributes: [
                "private": ExtractedField(value: .string("volatile-secret"), source: .embeddedState, confidence: 1)
            ],
            status: .failed,
            extractionAttempts: [
                ExtractionAttempt(
                    stage: .http,
                    startedAt: "start",
                    finishedAt: "finish",
                    succeeded: false,
                    message: "diagnostic-secret",
                    errorCode: "E_SECRET"
                )
            ]
        )

        XCTAssertTrue(result.searchableText.contains("Readable title"))
        XCTAssertTrue(result.searchableText.contains("Accessibility"))
        XCTAssertTrue(result.searchableText.contains("Deep Work"))
        XCTAssertTrue(result.searchableText.contains("42"))
        XCTAssertFalse(result.searchableText.contains("thumbnail.jpg"))
        XCTAssertFalse(result.searchableText.contains("volatile-secret"))
        XCTAssertFalse(result.searchableText.contains("diagnostic-secret"))
        XCTAssertFalse(result.searchableText.contains("E_SECRET"))
    }

    func testRecentSearchesCanBeClearedAndStayCleared() {
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)
        store.recordSearch("private query")

        store.clearRecentSearches()

        XCTAssertTrue(store.recentSearches.isEmpty)
        XCTAssertTrue(AppStore(fileURL: dataURL, userDefaults: defaults).recentSearches.isEmpty)
    }

    func testToastCarriesSemanticAndUniqueIdentity() {
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)
        store.showToast("정보", semantic: .info)
        let first = store.toast

        XCTAssertEqual(first?.message, L10n.text("정보"))
        XCTAssertEqual(first?.semantic, .info)

        store.showToast("오류", semantic: .error)

        XCTAssertEqual(store.toast?.semantic, .error)
        XCTAssertNotEqual(store.toast?.id, first?.id)
    }

    func testFolderDefaultTagIsAppliedToSingleBatchAndSortMoves() {
        var folders = DefaultData.folders
        folders.append(Folder(icon: "folder", label: "읽을거리", defaultTag: "읽을거리"))
        let repository = TestClipRepository(bootstrapHandler: {
            .loaded(DataSnapshot(
                version: 2,
                clips: DefaultData.clips,
                folders: folders,
                preferences: .standard
            ))
        })
        let store = AppStore(userDefaults: defaults, repository: repository)

        XCTAssertTrue(store.moveClip(id: 1, to: "읽을거리"))
        XCTAssertEqual(store.clip(id: 1)?.tags.last, "읽을거리")
        XCTAssertTrue(store.moveClip(id: 1, to: "읽을거리"))
        XCTAssertEqual(store.clip(id: 1)?.tags.filter { $0 == "읽을거리" }.count, 1)
        XCTAssertTrue(store.moveClips(ids: [2, 3], to: "읽을거리"))
        XCTAssertTrue(store.clip(id: 2)?.tags.contains("읽을거리") == true)
        XCTAssertTrue(store.clip(id: 3)?.tags.contains("읽을거리") == true)
        XCTAssertTrue(store.applySort(clipID: 5, to: "읽을거리"))
        XCTAssertTrue(store.clip(id: 5)?.tags.contains("읽을거리") == true)
    }

    func testFolderDefaultTagDeduplicatesCaseInsensitivelyAndPreservesTwelveUserTags() {
        var clips = DefaultData.clips
        clips[0].tags = ["Reference"]
        clips[1].tags = (1...12).map { "tag-\($0)" }
        var folders = DefaultData.folders
        folders.append(Folder(icon: "folder", label: "참고", defaultTag: "reference"))
        let repository = TestClipRepository(bootstrapHandler: {
            .loaded(DataSnapshot(version: 2, clips: clips, folders: folders, preferences: .standard))
        })
        let store = AppStore(userDefaults: defaults, repository: repository)

        XCTAssertTrue(store.moveClip(id: 1, to: "참고"))
        XCTAssertEqual(store.clip(id: 1)?.tags, ["Reference"])
        XCTAssertTrue(store.moveClip(id: 2, to: "참고"))
        XCTAssertEqual(store.clip(id: 2)?.tags, clips[1].tags)
    }

    func testFolderDefaultTagRollsBackWithFailedMove() {
        var folders = DefaultData.folders
        folders.append(Folder(icon: "folder", label: "읽을거리", defaultTag: "읽을거리"))
        let repository = TestClipRepository(bootstrapHandler: {
            .loaded(DataSnapshot(
                version: 2,
                clips: DefaultData.clips,
                folders: folders,
                preferences: .standard
            ))
        })
        let store = AppStore(userDefaults: defaults, repository: repository)
        let original = store.clip(id: 1)
        repository.commitError = ClipRepositoryError.writeFailed

        XCTAssertFalse(store.moveClip(id: 1, to: "읽을거리"))
        XCTAssertEqual(store.clip(id: 1), original)
    }

    func testPrimaryMutationsPersistAcrossReload() throws {
        try seedDefaultLibrary()
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        store.toggleBookmark(id: 1)
        store.moveClip(id: 1, to: "업무")
        store.updateMemo(id: 1, memo: "다시 확인할 메모")
        _ = try store.createFolder(name: "읽을거리", defaultTag: "읽을거리")
        let added = try store.createManualClip(
            type: .link,
            title: "읽을 링크",
            url: "example.com/read",
            text: "",
            destination: "업무",
            tags: ["읽을거리"],
            memo: "새 메모"
        )
        store.deleteClip(id: 5)

        let reloaded = AppStore(fileURL: dataURL, userDefaults: defaults)
        XCTAssertEqual(reloaded.clip(id: 1)?.bookmarked, true)
        XCTAssertEqual(reloaded.clip(id: 1)?.folder, "업무")
        XCTAssertEqual(reloaded.clip(id: 1)?.memo, "다시 확인할 메모")
        XCTAssertTrue(reloaded.folders.contains { $0.label == "읽을거리" })
        XCTAssertEqual(reloaded.clip(id: added.id)?.tags, ["읽을거리"])
        XCTAssertFalse(reloaded.activeClips.contains { $0.id == 5 })
        XCTAssertEqual(reloaded.trashedClips.map(\.id), [5])
    }

    func testDeleteCanBeUndoneAndPersistsRestoredClip() throws {
        try seedDefaultLibrary()
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        XCTAssertTrue(store.deleteClip(id: 1))
        XCTAssertNil(store.activeClips.first { $0.id == 1 })
        XCTAssertTrue(store.clip(id: 1)?.isInTrash == true)
        XCTAssertEqual(store.pendingDeletion?.clips.first?.id, 1)
        XCTAssertTrue(store.undoDelete())
        XCTAssertEqual(store.clip(id: 1)?.title, DefaultData.clips[0].title)
        XCTAssertNil(store.pendingDeletion)

        let reloaded = AppStore(fileURL: dataURL, userDefaults: defaults)
        XCTAssertNotNil(reloaded.clip(id: 1))
    }

    func testBatchMoveDeleteAndUndoCommitAsSingleTransactions() {
        let repository = TestClipRepository(bootstrapHandler: {
            .loaded(DataSnapshot(
                version: 2,
                clips: DefaultData.clips,
                folders: DefaultData.folders,
                preferences: .standard
            ))
        })
        let store = AppStore(userDefaults: defaults, repository: repository)
        let initialCommitCount = repository.committedSnapshots.count

        XCTAssertTrue(store.moveClips(ids: [1, 2], to: "폴더 4"))
        XCTAssertEqual(repository.committedSnapshots.count, initialCommitCount + 1)
        XCTAssertEqual(store.clip(id: 1)?.folder, "폴더 4")
        XCTAssertEqual(store.clip(id: 2)?.folder, "폴더 4")
        XCTAssertNil(store.clip(id: 1)?.state)

        XCTAssertTrue(store.deleteClips(ids: [1, 2]))
        XCTAssertEqual(repository.committedSnapshots.count, initialCommitCount + 2)
        XCTAssertEqual(Set(store.trashedClips.map(\.id)), Set([1, 2]))
        XCTAssertEqual(Set(store.pendingDeletion?.clips.map(\.id) ?? []), Set([1, 2]))

        XCTAssertTrue(store.undoDelete())
        XCTAssertEqual(repository.committedSnapshots.count, initialCommitCount + 3)
        XCTAssertEqual(Set(store.activeClips.filter { [1, 2].contains($0.id) }.map(\.id)), Set([1, 2]))
        XCTAssertTrue(store.trashedClips.isEmpty)
    }

    func testBatchMutationFailureRollsBackAndPreservesExistingUndo() {
        let repository = TestClipRepository(bootstrapHandler: {
            .loaded(DataSnapshot(
                version: 2,
                clips: DefaultData.clips,
                folders: DefaultData.folders,
                preferences: .standard
            ))
        })
        let store = AppStore(userDefaults: defaults, repository: repository)
        let originalFolder = store.clip(id: 2)?.folder

        XCTAssertTrue(store.deleteClip(id: 1))
        XCTAssertEqual(store.pendingDeletion?.clips.map(\.id), [1])
        repository.commitError = ClipRepositoryError.writeFailed

        XCTAssertFalse(store.moveClips(ids: [2, 3], to: "폴더 5"))
        XCTAssertEqual(store.clip(id: 2)?.folder, originalFolder)
        XCTAssertFalse(store.deleteClips(ids: [2, 3]))
        XCTAssertEqual(store.pendingDeletion?.clips.map(\.id), [1])
        XCTAssertFalse(store.clip(id: 2)?.isInTrash == true)
        XCTAssertFalse(store.clip(id: 3)?.isInTrash == true)
    }

    func testSortMutatesOnlyThePresentedClipID() {
        let repository = TestClipRepository(bootstrapHandler: {
            .loaded(DataSnapshot(
                version: 2,
                clips: DefaultData.clips,
                folders: DefaultData.folders,
                preferences: .standard
            ))
        })
        let store = AppStore(userDefaults: defaults, repository: repository)

        XCTAssertTrue(store.applySort(clipID: 5, to: "폴더 4"))
        XCTAssertEqual(store.clip(id: 5)?.folder, "폴더 4")
        XCTAssertNil(store.clip(id: 5)?.state)
        XCTAssertEqual(store.clip(id: 1)?.state, .unsorted)
        XCTAssertEqual(store.clip(id: 1)?.folder, DefaultData.clips[0].folder)
        XCTAssertFalse(store.applySort(clipID: 3, to: "폴더 4"))
    }

    func testTrashRestoreEmptyAndThirtyDayExpiry() throws {
        try seedDefaultLibrary()
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        XCTAssertTrue(store.deleteClip(id: 1))
        XCTAssertEqual(store.folderCount("휴지통"), 1)
        XCTAssertTrue(store.restoreClip(id: 1))
        XCTAssertTrue(store.trashedClips.isEmpty)

        XCTAssertTrue(store.deleteClip(id: 2))
        XCTAssertTrue(store.emptyTrash())
        XCTAssertNil(store.clip(id: 2))
        XCTAssertFalse(store.undoDelete())

        var expired = DefaultData.clips[0]
        expired.deletedAt = Date().addingTimeInterval(-31 * 24 * 60 * 60)
        var retained = DefaultData.clips[1]
        retained.deletedAt = Date().addingTimeInterval(-29 * 24 * 60 * 60)
        let repository = TestClipRepository(bootstrapHandler: {
            .loaded(DataSnapshot(version: 2, clips: [expired, retained],
                                 folders: DefaultData.folders, preferences: .standard))
        })
        let reloaded = AppStore(userDefaults: defaults, repository: repository)

        XCTAssertNil(reloaded.clip(id: expired.id))
        XCTAssertEqual(reloaded.trashedClips.map(\.id), [retained.id])
        XCTAssertEqual(repository.committedSnapshots.last?.clips.map(\.id), [retained.id])
    }

    func testFailedPermanentAttachmentRemovalPersistsLedgerAndRetriesOnNextInitialization() throws {
        let attachmentFileName = "\(UUID().uuidString).pdf"
        let attachmentURL = temporaryDirectory.appendingPathComponent(attachmentFileName)
        let attachmentData = Data("%PDF-1.4\nPending cleanup\n%%EOF".utf8)
        try attachmentData.write(to: attachmentURL)
        let trashedClip = Clip(
            id: 1,
            type: .file,
            state: .saved,
            title: "Pending cleanup",
            source: "Files",
            url: "",
            time: "저장됨",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            folder: "인박스",
            attachments: [
                SharedClipAttachment(
                    kind: .file,
                    originalFileName: "pending-cleanup.pdf",
                    storedFileName: attachmentFileName,
                    typeIdentifier: UTType.pdf.identifier,
                    byteCount: Int64(attachmentData.count)
                )
            ],
            deletedAt: Date()
        )
        try FileClipRepository(fileURL: dataURL).commit(DataSnapshot(
            version: 2,
            clips: [trashedClip],
            folders: DefaultData.folders,
            preferences: .standard
        ))
        var failedRemovalAttempts: [String] = []
        let firstStore = AppStore(
            fileURL: dataURL,
            userDefaults: defaults,
            attachmentRemover: { fileName in
                failedRemovalAttempts.append(fileName)
                throw CocoaError(.fileWriteNoPermission)
            }
        )

        XCTAssertFalse(firstStore.emptyTrash())
        XCTAssertTrue(firstStore.clips.isEmpty)
        XCTAssertEqual(failedRemovalAttempts, [attachmentFileName])
        XCTAssertEqual(firstStore.pendingAttachmentCleanupFileNames, [attachmentFileName])
        XCTAssertTrue(FileManager.default.fileExists(atPath: attachmentURL.path))

        var successfulRemovalAttempts: [String] = []
        let reloaded = AppStore(
            fileURL: dataURL,
            userDefaults: defaults,
            attachmentRemover: { fileName in
                successfulRemovalAttempts.append(fileName)
                XCTAssertEqual(fileName, attachmentFileName)
                try FileManager.default.removeItem(at: attachmentURL)
            }
        )

        XCTAssertTrue(reloaded.clips.isEmpty)
        XCTAssertEqual(successfulRemovalAttempts, [attachmentFileName])
        XCTAssertTrue(reloaded.pendingAttachmentCleanupFileNames.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: attachmentURL.path))
    }

    func testUpdateTagsCleansValuesPersistsAndSkipsNoOp() throws {
        try seedDefaultLibrary()
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)
        let original = try XCTUnwrap(store.clip(id: 1)?.tags)
        let dataBeforeNoOp = try Data(contentsOf: dataURL)

        store.updateTags(id: 1, tags: original)
        XCTAssertEqual(try Data(contentsOf: dataURL), dataBeforeNoOp)

        store.updateTags(id: 1, tags: ["  독서 ", "", "여행"])
        XCTAssertEqual(store.clip(id: 1)?.tags, ["독서", "여행"])

        let reloaded = AppStore(fileURL: dataURL, userDefaults: defaults)
        XCTAssertEqual(reloaded.clip(id: 1)?.tags, ["독서", "여행"])
    }

    func testDefaultFoldersCanBeRenamedAndReferencesPersist() throws {
        try seedDefaultLibrary()
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        store.moveClip(id: 5, to: "인박스")
        store.updatePreference(key: .defaultFolder, value: "인박스")
        XCTAssertEqual(try store.renameFolder(from: "인박스", to: "받은 클립"), "받은 클립")
        XCTAssertEqual(try store.renameFolder(from: "전체", to: "모든 클립"), "모든 클립")

        let reloaded = AppStore(fileURL: dataURL, userDefaults: defaults)
        XCTAssertTrue(reloaded.folders.contains { $0.label == "받은 클립" && $0.icon == "inbox" })
        XCTAssertTrue(reloaded.folders.contains { $0.label == "모든 클립" && $0.icon == "archive" })
        XCTAssertFalse(reloaded.folders.contains { $0.label == "인박스" })
        XCTAssertFalse(reloaded.folders.contains { $0.label == "전체" })
        XCTAssertEqual(reloaded.preferences.defaultFolder, "받은 클립")
        XCTAssertEqual(reloaded.clip(id: 5)?.folder, "받은 클립")
        XCTAssertEqual(reloaded.folderCount("모든 클립"), reloaded.clips.count)
    }

    func testFolderRenameRejectsDuplicateNamesWithoutChangingData() throws {
        try seedDefaultLibrary()
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        XCTAssertThrowsError(try store.renameFolder(from: "인박스", to: "폴더 1"))
        XCTAssertTrue(store.folders.contains { $0.label == "인박스" })
        XCTAssertEqual(store.clip(id: 5)?.folder, "폴더 1")
    }

    func testTagCatalogRenameAndDeleteUpdateEveryReference() throws {
        try seedDefaultLibrary()
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        XCTAssertTrue(store.availableTags.contains("인테리어"))
        try store.renameTag(from: "인테리어", to: "공간")
        XCTAssertFalse(store.availableTags.contains("인테리어"))
        XCTAssertTrue(store.availableTags.contains("공간"))
        XCTAssertEqual(store.clip(id: 1)?.tags, ["공간", "거실", "미니멀"])

        store.deleteTag("공간")
        XCTAssertFalse(store.availableTags.contains("공간"))
        XCTAssertEqual(store.clip(id: 1)?.tags, ["거실", "미니멀"])

        let reloaded = AppStore(fileURL: dataURL, userDefaults: defaults)
        XCTAssertFalse(reloaded.availableTags.contains("인테리어"))
        XCTAssertFalse(reloaded.availableTags.contains("공간"))
        XCTAssertEqual(reloaded.clip(id: 1)?.tags, ["거실", "미니멀"])
    }

    func testFreshFoldersUseGenericRenameFriendlyOrderAndDarkThemePersists() {
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        XCTAssertTrue(store.clips.isEmpty)
        XCTAssertEqual(store.bootstrapState, .firstRun)
        XCTAssertEqual(store.folders.map(\.label), [
            "전체", "인박스", "폴더 1", "폴더 2", "폴더 3", "폴더 4", "폴더 5", "휴지통"
        ])
        XCTAssertFalse(store.destinationFolders.contains { $0.icon == "trash" })
        store.updatePreference(key: .theme, value: "다크")

        let reloaded = AppStore(fileURL: dataURL, userDefaults: defaults)
        XCTAssertEqual(reloaded.preferences.theme, "다크")
    }

    func testLegacyDefaultFolderMigratesToInboxAndBecomesUnsorted() {
        let legacyClip = Clip(
            id: 901, type: .link, state: .new,
            title: "Legacy", source: "example.com", url: "https://example.com",
            time: "now", folder: "기본 폴더"
        )
        let legacy = DataSnapshot(
            version: 2,
            clips: [legacyClip],
            folders: [
                Folder(icon: "archive", label: "전체"),
                Folder(icon: "inbox", label: "기본 폴더"),
                Folder(icon: "folder", label: "업무"),
                Folder(icon: "trash", label: "휴지통")
            ],
            preferences: Preferences(
                appLock: "끔", theme: "라이트", language: "한국어",
                defaultFolder: "기본 폴더"
            )
        )
        let repository = TestClipRepository(bootstrapHandler: { .loaded(legacy) })

        let store = AppStore(userDefaults: defaults, repository: repository)

        XCTAssertEqual(store.folders.first(where: { $0.icon == "inbox" })?.label, "인박스")
        XCTAssertEqual(store.preferences.defaultFolder, "인박스")
        XCTAssertEqual(store.clip(id: legacyClip.id)?.folder, "인박스")
        XCTAssertEqual(store.unsortedClips.map(\.id), [legacyClip.id])
    }

    func testLegacyInboxMigrationPreservesAnExistingCustomInboxFolder() {
        let legacy = DataSnapshot(
            version: 2,
            clips: [
                Clip(id: 910, type: .memo, state: .new, title: "Default", source: "memo", url: "",
                     time: "now", folder: "기본 폴더", folderSuggestions: ["기본 폴더"]),
                Clip(id: 911, type: .memo, title: "Custom", source: "memo", url: "",
                     time: "now", folder: "인박스", folderSuggestions: ["인박스"])
            ],
            folders: [
                Folder(icon: "archive", label: "전체"),
                Folder(icon: "inbox", label: "기본 폴더"),
                Folder(icon: "folder", label: "인박스")
            ],
            preferences: Preferences(
                appLock: "끔", theme: "라이트", language: "한국어",
                defaultFolder: "기본 폴더"
            )
        )
        let repository = TestClipRepository(bootstrapHandler: { .loaded(legacy) })

        let store = AppStore(userDefaults: defaults, repository: repository)

        XCTAssertEqual(store.folders.filter { $0.label == "인박스" }.count, 1)
        XCTAssertEqual(store.folders.first(where: { $0.icon == "inbox" })?.label, "인박스")
        XCTAssertEqual(store.clip(id: 910)?.folder, "인박스")
        XCTAssertEqual(store.clip(id: 910)?.state, .unsorted)
        XCTAssertEqual(store.clip(id: 911)?.folder, "인박스 보관함")
        XCTAssertEqual(store.clip(id: 911)?.folderSuggestions, ["인박스 보관함"])
    }

    func testNewCaptureStaysUnsortedUntilExplicitFolderMove() throws {
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)
        let clip = try store.createManualClip(
            type: .memo, title: "분류 전", url: "", text: "내용",
            destination: "인박스", tags: [], memo: ""
        )

        XCTAssertEqual(store.clip(id: clip.id)?.state, .unsorted)
        XCTAssertEqual(store.unsortedClips.map(\.id), [clip.id])

        XCTAssertTrue(store.moveClip(id: clip.id, to: "폴더 1"))
        XCTAssertNil(store.clip(id: clip.id)?.state)
        XCTAssertTrue(store.unsortedClips.isEmpty)
    }

    func testFolderDeletionReturnsClipsAndDefaultToInbox() throws {
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)
        let clip = try store.createManualClip(
            type: .memo, title: "업무 메모", url: "", text: "내용",
            destination: "폴더 1", tags: [], memo: ""
        )
        store.updatePreference(key: .defaultFolder, value: "폴더 1")

        XCTAssertTrue(try store.deleteFolder("폴더 1"))

        XCTAssertFalse(store.folders.contains { $0.label == "폴더 1" })
        XCTAssertEqual(store.clip(id: clip.id)?.folder, "인박스")
        XCTAssertEqual(store.clip(id: clip.id)?.state, .unsorted)
        XCTAssertEqual(store.preferences.defaultFolder, "인박스")
    }

    func testGitHubRepositoryTitleUsesOnlyOwnerAndRepository() {
        let clip = Clip(
            id: 902, type: .link,
            title: "eiranotes/ClipInbox: Private-first clip organizer for iOS",
            source: "github.com", url: "https://github.com/eiranotes/ClipInbox",
            time: "now", folder: "인박스"
        )

        XCTAssertEqual(AppStore.githubRepositoryTitle(for: clip.url), "eiranotes/ClipInbox")
        XCTAssertEqual(clip.presentationTitle, "eiranotes/ClipInbox")
        XCTAssertNil(AppStore.githubRepositoryTitle(for: "https://github.com/eiranotes/ClipInbox/issues/1"))
    }

    func testRoParticleFollowsFinalConsonant() {
        XCTAssertEqual("디자인".withRoParticle, "디자인으로")
        XCTAssertEqual("인박스".withRoParticle, "인박스로")
        XCTAssertEqual("여행".withRoParticle, "여행으로")
        XCTAssertEqual("나중에 볼 글".withRoParticle, "나중에 볼 글로")
        XCTAssertEqual("Work".withRoParticle, "Work로")
    }

    func testEnablingAppLockDefersLockUntilLifecycleRequiresIt() {
        let lock = AppLockController()

        lock.configure(enabled: true)
        XCTAssertTrue(lock.isEnabled)
        XCTAssertFalse(lock.isLocked)

        lock.lockIfNeeded()
        XCTAssertTrue(lock.isLocked)

        lock.configure(enabled: false)
        XCTAssertFalse(lock.isEnabled)
        XCTAssertFalse(lock.isLocked)
    }

    @MainActor
    func testUnavailableAuthenticationKeepsAppLocked() async {
        let authenticator = TestLockAuthenticator(available: false)
        let lock = AppLockController(authenticator: authenticator)
        lock.configure(enabled: true, lockImmediately: true)

        await lock.authenticate()

        XCTAssertTrue(lock.isLocked)
        XCTAssertNotNil(lock.notice)
        XCTAssertFalse(lock.canEnableLock())
    }

    @MainActor
    func testAuthenticationFailureStaysLockedAndSuccessUnlocks() async {
        let authenticator = TestLockAuthenticator(
            available: true,
            error: NSError(domain: LAError.errorDomain, code: LAError.authenticationFailed.rawValue)
        )
        let lock = AppLockController(authenticator: authenticator)
        lock.configure(enabled: true, lockImmediately: true)

        await lock.authenticate()
        XCTAssertTrue(lock.isLocked)

        authenticator.error = nil
        authenticator.result = true
        await lock.authenticate()
        XCTAssertFalse(lock.isLocked)
    }

    func testReleaseDefaultsKeepLockOffAndQuickSaveOn() {
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        XCTAssertEqual(store.preferences.appLock, "끔")
        XCTAssertEqual(store.preferences.sharedSaveMode, .quick)
    }

    func testJapaneseLanguageAndShareReviewModePersist() {
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        store.updatePreference(key: .language, value: AppLanguage.japanese.rawValue)
        store.updatePreference(key: .shareMode, value: SharedSaveMode.review.rawValue)

        let reloaded = AppStore(fileURL: dataURL, userDefaults: defaults)
        XCTAssertEqual(reloaded.preferences.appLanguage, .japanese)
        XCTAssertEqual(reloaded.preferences.sharedSaveMode, .review)
        XCTAssertEqual(L10n.text("설정", language: .english), "Settings")
        XCTAssertEqual(L10n.text("설정", language: .japanese), "設定")
        XCTAssertEqual(L10n.text("클립 인박스", language: .korean), "클립 인박스")
        XCTAssertEqual(L10n.text("클립 인박스", language: .english), "Clip Inbox")
        XCTAssertEqual(L10n.text("클립 인박스", language: .japanese), "Clip Inbox")
        XCTAssertEqual(L10n.text("Clip Inbox를 선택해요", language: .korean), "클립 인박스를 선택해요")
        XCTAssertEqual(L10n.text("Clip Inbox를 선택해요", language: .english), "Choose Clip Inbox")
        XCTAssertEqual(L10n.text("Clip Inbox를 선택해요", language: .japanese), "Clip Inboxを選択")
    }

    func testLinkOpeningDefaultsToDirectAndPersistsConfirmationChoice() {
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        XCTAssertEqual(store.linkOpenMode, .direct)
        store.updateLinkOpenMode(.confirm)

        let reloaded = AppStore(fileURL: dataURL, userDefaults: defaults)
        XCTAssertEqual(reloaded.linkOpenMode, .confirm)
    }

    func testDetailCopyKindUsesClipTypeInsteadOfThumbnailPresence() {
        let linkWithThumbnail = Clip(
            id: 101, type: .link, title: "Link", source: "example.com",
            url: "https://example.com", time: "now", folder: "기본 폴더",
            image: "/public/images/clip-beach.png"
        )
        let image = Clip(
            id: 102, type: .image, title: "Image", source: "사진",
            url: "", time: "now", folder: "기본 폴더",
            image: "/public/images/clip-beach.png"
        )
        let missingImage = Clip(
            id: 103, type: .screenshot, title: "Missing", source: "사진",
            url: "", time: "now", folder: "기본 폴더"
        )

        XCTAssertEqual(ClipDetailCopyKind.resolve(for: linkWithThumbnail), .link)
        XCTAssertEqual(ClipDetailCopyKind.resolve(for: image), .image)
        XCTAssertNil(ClipDetailCopyKind.resolve(for: missingImage))
    }

    func testTabNavigationResetOnlyPopsSelectedTabToRoot() {
        var navigation = TabNavigationState(
            inbox: [.detail(1)],
            folders: [.folderDetail("읽을거리")],
            search: [.detail(2)],
            settings: [.settingDetail(.about)]
        )

        navigation.reset(.folders)

        XCTAssertEqual(navigation.inbox, [.detail(1)])
        XCTAssertTrue(navigation.folders.isEmpty)
        XCTAssertEqual(navigation.search, [.detail(2)])
        XCTAssertEqual(navigation.settings, [.settingDetail(.about)])
    }

    func testNavigationExitGuardBlocksUntilItsOwnerUnregisters() throws {
        let guardOwner = try XCTUnwrap(
            UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")
        )
        let unrelatedOwner = try XCTUnwrap(
            UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")
        )
        let exitGuard = NavigationExitGuard()
        var handlerCallCount = 0
        exitGuard.register(ownerID: guardOwner) {
            handlerCallCount += 1
            return false
        }

        XCTAssertFalse(exitGuard.attemptExit())
        XCTAssertEqual(handlerCallCount, 1)

        exitGuard.unregister(ownerID: unrelatedOwner)
        XCTAssertFalse(exitGuard.attemptExit(), "Another owner must not remove the active guard")
        XCTAssertEqual(handlerCallCount, 2)

        exitGuard.unregister(ownerID: guardOwner)
        XCTAssertTrue(exitGuard.attemptExit())
        XCTAssertEqual(handlerCallCount, 2)
    }

    func testSharedImageAssetPreservesOriginalBytesFormatAndDimensions() throws {
        let sourceSize = CGSize(width: 2_400, height: 1_800)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: sourceSize, format: format).image { context in
            UIColor.systemYellow.setFill()
            context.fill(CGRect(origin: .zero, size: sourceSize))
        }
        let originalData = try XCTUnwrap(image.pngData())
        let asset = try XCTUnwrap(SharedImageAsset(data: originalData, typeIdentifier: UTType.png.identifier))
        let mislabeledAsset = try XCTUnwrap(SharedImageAsset(
            data: originalData,
            typeIdentifier: UTType.jpeg.identifier,
            suggestedFileExtension: "jpg"
        ))
        let decoded = try XCTUnwrap(UIImage(data: asset.data))

        XCTAssertEqual(asset.data, originalData)
        XCTAssertEqual(asset.fileExtension, "png")
        XCTAssertEqual(mislabeledAsset.fileExtension, "png")
        XCTAssertEqual(decoded.size, sourceSize)
        XCTAssertTrue(SharedClipQueue.isValidImageFileName("C8D6F4A3-3120-4A18-A105-43F4ED7B2EB1.png"))
        XCTAssertFalse(SharedClipQueue.isValidImageFileName("../image.png"))
    }

    func testCorruptCurrentSnapshotRecoversPreviousAndQuarantinesOriginal() throws {
        let repository = FileClipRepository(fileURL: dataURL)
        let previous = DataSnapshot(
            version: 2,
            clips: [DefaultData.clips[0]],
            folders: DefaultData.folders,
            preferences: .standard
        )
        let current = DataSnapshot(
            version: 2,
            clips: [DefaultData.clips[1]],
            folders: DefaultData.folders,
            preferences: .standard
        )
        try repository.commit(previous)
        try repository.commit(current)
        try Data("not-json".utf8).write(to: dataURL, options: .atomic)

        let recovered = AppStore(fileURL: dataURL, userDefaults: defaults)

        XCTAssertEqual(recovered.bootstrapState, .recovered)
        XCTAssertEqual(recovered.clips.map(\.id), [1])
        let recoveryFiles = try FileManager.default.contentsOfDirectory(
            at: repository.recoveryDirectoryURL,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(recoveryFiles.count, 1)
        XCTAssertEqual(try Data(contentsOf: recoveryFiles[0]), Data("not-json".utf8))
    }

    @MainActor
    func testDeleteAllDataRemovesRecoverySearchQueueAndMetadataArtifacts() async throws {
        let repository = FileClipRepository(fileURL: dataURL)
        let original = DataSnapshot(
            version: 2,
            clips: DefaultData.clips,
            folders: DefaultData.folders,
            preferences: .standard
        )
        try repository.commit(original)
        try repository.commit(original)
        try FileManager.default.createDirectory(
            at: repository.recoveryDirectoryURL,
            withIntermediateDirectories: true
        )
        let recoveryArtifact = repository.recoveryDirectoryURL.appendingPathComponent("corrupt.json")
        try Data("recoverable library".utf8).write(to: recoveryArtifact)

        let queueContainer = temporaryDirectory.appendingPathComponent("DeleteAllQueue", isDirectory: true)
        for directoryName in ["PendingClips", "SharedImages", "FailedClips", "ExpiredClips", "ExpiredImages"] {
            let directory = queueContainer.appendingPathComponent(directoryName, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data("stale".utf8).write(to: directory.appendingPathComponent("artifact"))
        }
        let staleConfiguration = SharedClipConfiguration(
            saveMode: .review,
            language: .ja,
            defaultFolder: "개인",
            folders: ["개인"],
            theme: "다크"
        )
        try JSONEncoder().encode(staleConfiguration).write(
            to: queueContainer.appendingPathComponent("ShareConfiguration-v1.json")
        )

        let metadataDirectory = temporaryDirectory.appendingPathComponent("DeleteAllMetadata", isDirectory: true)
        try FileManager.default.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
        let sidecarURL = metadataDirectory.appendingPathComponent("link-metadata-v1.json")
        let cacheURL = metadataDirectory.appendingPathComponent("canonical-cache-v1.json")
        try Data("stale sidecar".utf8).write(to: sidecarURL)
        try Data("stale cache".utf8).write(to: cacheURL)

        let store = AppStore(fileURL: dataURL, userDefaults: defaults)
        store.recordSearch("private query")
        store.updateLinkOpenMode(.confirm)
        let metadata = URLMetadataCoordinator(
            sidecar: LinkMetadataSidecarStore(fileURL: sidecarURL),
            cacheURL: cacheURL
        )

        let deleted = await store.deleteAllData(metadata: metadata, containerURL: queueContainer)

        XCTAssertTrue(deleted)
        XCTAssertTrue(store.clips.isEmpty)
        XCTAssertTrue(store.recentSearches.isEmpty)
        XCTAssertEqual(store.preferences, .standard)
        let persistedData = try Data(contentsOf: dataURL)
        XCTAssertFalse(String(decoding: persistedData, as: UTF8.self).contains(DefaultData.clips[0].title))
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.previousURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.recoveryDirectoryURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: sidecarURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheURL.path))
        for directoryName in ["PendingClips", "SharedImages", "FailedClips", "ExpiredClips", "ExpiredImages"] {
            let directory = queueContainer.appendingPathComponent(directoryName, isDirectory: true)
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        }

        let savedConfigurationData = try Data(
            contentsOf: queueContainer.appendingPathComponent("ShareConfiguration-v1.json")
        )
        let savedConfiguration = try JSONDecoder().decode(
            SharedClipConfiguration.self,
            from: savedConfigurationData
        )
        XCTAssertEqual(savedConfiguration.saveMode, .quick)
        XCTAssertEqual(savedConfiguration.defaultFolder, "인박스")

        let reloaded = AppStore(fileURL: dataURL, userDefaults: defaults)
        XCTAssertTrue(reloaded.clips.isEmpty)
        XCTAssertTrue(reloaded.recentSearches.isEmpty)
        XCTAssertEqual(reloaded.linkOpenMode, .direct)
    }

    @MainActor
    func testDeleteAllDataDoesNotClearSideDataWhenLibraryResetFails() async throws {
        let initial = DataSnapshot(
            version: 2,
            clips: [DefaultData.clips[0]],
            folders: DefaultData.folders,
            preferences: .standard
        )
        let repository = TestClipRepository(
            bootstrapHandler: { .loaded(initial) },
            commitError: ClipRepositoryError.writeFailed
        )
        let queueContainer = temporaryDirectory.appendingPathComponent("FailedDeleteQueue", isDirectory: true)
        let pendingDirectory = queueContainer.appendingPathComponent("PendingClips", isDirectory: true)
        try FileManager.default.createDirectory(at: pendingDirectory, withIntermediateDirectories: true)
        let pendingArtifact = pendingDirectory.appendingPathComponent("keep.json")
        try Data("keep".utf8).write(to: pendingArtifact)
        let metadata = URLMetadataCoordinator(
            sidecar: LinkMetadataSidecarStore(
                fileURL: temporaryDirectory.appendingPathComponent("failed-sidecar.json")
            ),
            cacheURL: temporaryDirectory.appendingPathComponent("failed-cache.json")
        )
        let store = AppStore(userDefaults: defaults, repository: repository)
        store.recordSearch("keep search")

        let deleted = await store.deleteAllData(metadata: metadata, containerURL: queueContainer)

        XCTAssertFalse(deleted)
        XCTAssertEqual(store.clips.map(\.id), [1])
        XCTAssertEqual(store.recentSearches, ["keep search"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: pendingArtifact.path))
        XCTAssertNotNil(store.storageErrorMessage)
    }

    func testCorruptSnapshotWithoutPreviousBlocksInsteadOfLoadingSamples() throws {
        try Data("not-json".utf8).write(to: dataURL, options: .atomic)

        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        XCTAssertEqual(store.bootstrapState, .recoveryRequired)
        XCTAssertTrue(store.clips.isEmpty)
        XCTAssertTrue(store.bootstrapState.blocksLibrary)
    }

    func testFutureSnapshotVersionRequiresUpdateWithoutLoadingData() throws {
        let future = DataSnapshot(
            version: 99,
            clips: DefaultData.clips,
            folders: DefaultData.folders,
            preferences: .standard
        )
        try JSONEncoder().encode(future).write(to: dataURL, options: .atomic)

        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        XCTAssertEqual(store.bootstrapState, .updateRequired(version: 99))
        XCTAssertTrue(store.clips.isEmpty)
        XCTAssertTrue(store.bootstrapState.blocksLibrary)
    }

    func testMutationRollsBackWhenRepositoryCommitFails() {
        let initial = DataSnapshot(
            version: 2,
            clips: [DefaultData.clips[0]],
            folders: DefaultData.folders,
            preferences: .standard
        )
        let repository = TestClipRepository(
            bootstrapHandler: { .loaded(initial) },
            commitError: ClipRepositoryError.writeFailed
        )
        let store = AppStore(userDefaults: defaults, repository: repository)

        XCTAssertFalse(store.toggleBookmark(id: 1))
        XCTAssertEqual(store.clip(id: 1)?.bookmarked, false)
        XCTAssertNotNil(store.storageErrorMessage)
        XCTAssertNotNil(store.toast)
    }

    func testImportRollsBackWhenRepositoryCommitFails() throws {
        let initial = DataSnapshot(
            version: 2,
            clips: [DefaultData.clips[0]],
            folders: DefaultData.folders,
            preferences: .standard
        )
        let incoming = DataSnapshot(
            version: 2,
            clips: [DefaultData.clips[1]],
            folders: DefaultData.folders,
            preferences: .standard
        )
        let repository = TestClipRepository(
            bootstrapHandler: { .loaded(initial) },
            commitError: ClipRepositoryError.writeFailed
        )
        let store = AppStore(userDefaults: defaults, repository: repository)

        XCTAssertThrowsError(try store.importJSON(JSONEncoder().encode(incoming)))
        XCTAssertEqual(store.clips.map(\.id), [1])
    }

    func testImportRejectsUnsupportedVersionBeforeMutation() throws {
        try seedDefaultLibrary()
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)
        let future = DataSnapshot(
            version: 3,
            clips: [DefaultData.clips[1]],
            folders: DefaultData.folders,
            preferences: .standard
        )

        XCTAssertThrowsError(try store.importJSON(JSONEncoder().encode(future)))
        XCTAssertEqual(store.clips.map(\.id), DefaultData.clips.map(\.id))
    }

    func testManualCaptureCreatesRealLinkTextAndMemoPayloads() throws {
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        let link = try store.createManualClip(
            type: .link, title: "", url: "Example.com/path#section", text: "",
            destination: "인박스", tags: ["읽을거리"], memo: "확인"
        )
        let text = try store.createManualClip(
            type: .text, title: "", url: "", text: "첫 줄\n둘째 줄",
            destination: "인박스", tags: [], memo: ""
        )
        let memo = try store.createManualClip(
            type: .memo, title: "", url: "", text: "기억할 내용",
            destination: "인박스", tags: [], memo: ""
        )

        XCTAssertEqual(link.url, "https://example.com/path")
        XCTAssertEqual(link.title, "example.com")
        XCTAssertEqual(text.title, "첫 줄")
        XCTAssertEqual(text.description, "첫 줄\n둘째 줄")
        XCTAssertEqual(memo.source, "나의 메모")
        let duplicate = try store.createManualClip(
            type: .link, title: "같은 링크도 저장", url: "https://EXAMPLE.com/path#other", text: "",
            destination: "인박스", tags: [], memo: ""
        )
        XCTAssertNotEqual(duplicate.id, link.id)
        XCTAssertThrowsError(try store.createManualClip(
            type: .link, title: "", url: "javascript:alert(1)", text: "",
            destination: "인박스", tags: [], memo: ""
        ))
    }

    func testManualClipCreatedAtPersistsAcrossReload() throws {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        let clip = try store.createManualClip(
            type: .memo,
            title: "Timestamped memo",
            url: "",
            text: "Persist this timestamp",
            destination: "인박스",
            tags: [],
            memo: "",
            createdAt: createdAt
        )

        XCTAssertEqual(clip.createdAt, createdAt)
        let reloaded = AppStore(fileURL: dataURL, userDefaults: defaults)
        XCTAssertEqual(reloaded.clip(id: clip.id)?.createdAt, createdAt)
    }

    func testLegacyJustNowClipWithoutCreatedAtReloadsAsSaved() throws {
        let legacyClip = Clip(
            id: 42,
            type: .memo,
            title: "Legacy memo",
            source: "Legacy import",
            url: "",
            time: "방금 전",
            createdAt: nil,
            folder: "인박스",
            description: "Old data"
        )
        let legacyData = try JSONEncoder().encode(DataSnapshot(
            version: 2,
            clips: [legacyClip],
            folders: DefaultData.folders,
            preferences: .standard
        ))
        let legacyObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: legacyData) as? [String: Any]
        )
        let encodedClips = try XCTUnwrap(legacyObject["clips"] as? [[String: Any]])
        XCTAssertNil(encodedClips.first?["createdAt"])
        try legacyData.write(to: dataURL, options: .atomic)

        let reloaded = AppStore(fileURL: dataURL, userDefaults: defaults)
        let decoded = try XCTUnwrap(reloaded.clip(id: legacyClip.id))
        let label = decoded.timeLabel(
            relativeTo: Date(timeIntervalSince1970: 1_800_000_000),
            locale: Locale(identifier: "en_US")
        )

        XCTAssertNil(decoded.createdAt)
        XCTAssertEqual(label, "Saved")
        XCTAssertNotEqual(label, "Just now")
        for legacyRelativeTime in ["2시간 전", "yesterday", "3日前"] {
            var variant = decoded
            variant.time = legacyRelativeTime
            XCTAssertEqual(
                variant.timeLabel(
                    relativeTo: Date(timeIntervalSince1970: 1_800_000_000),
                    locale: Locale(identifier: "en_US")
                ),
                "Saved",
                "Legacy relative label \(legacyRelativeTime) must not remain time-sensitive"
            )
        }
    }

    func testShareQueueSortsQuarantinesExpiresAndIsIdempotent() throws {
        let container = temporaryDirectory.appendingPathComponent("QueueContainer", isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let now = Date()
        let later = SharedClipPayload(
            id: UUID(), type: .text, title: "later", source: "test", text: "later",
            createdAt: now.addingTimeInterval(-10)
        )
        let earlier = SharedClipPayload(
            id: UUID(), type: .text, title: "earlier", source: "test", text: "earlier",
            createdAt: now.addingTimeInterval(-20)
        )
        let expired = SharedClipPayload(
            id: UUID(), type: .text, title: "expired", source: "test", text: "expired",
            createdAt: now.addingTimeInterval(-SharedClipQueue.maxPendingAge - 1)
        )
        try SharedClipQueue.enqueue(later, containerURL: container)
        try SharedClipQueue.enqueue(earlier, containerURL: container)
        try SharedClipQueue.enqueue(earlier, containerURL: container)
        try SharedClipQueue.enqueue(expired, containerURL: container)
        let pending = container.appendingPathComponent("PendingClips", isDirectory: true)
        try Data("broken".utf8).write(to: pending.appendingPathComponent("broken.json"))

        let items = try SharedClipQueue.pendingItems(containerURL: container, now: now)

        XCTAssertEqual(items.map(\.payload.title), ["earlier", "later"])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(
            at: container.appendingPathComponent("FailedClips"),
            includingPropertiesForKeys: nil
        ).count, 1)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(
            at: container.appendingPathComponent("ExpiredClips"),
            includingPropertiesForKeys: nil
        ).count, 1)
    }

    func testSharedPayloadWithoutCreatedAtFailsDecodingAndIsQuarantined() throws {
        let payload = SharedClipPayload(
            id: UUID(),
            type: .text,
            title: "Missing timestamp",
            source: "Legacy share",
            text: "Must not import",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let encoded = try JSONEncoder().encode(payload)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "createdAt")
        let missingCreatedAtData = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )

        XCTAssertThrowsError(
            try JSONDecoder().decode(SharedClipPayload.self, from: missingCreatedAtData)
        ) { error in
            guard case DecodingError.keyNotFound(let key, _) = error else {
                return XCTFail("Expected missing createdAt to fail with keyNotFound, got \(error)")
            }
            XCTAssertEqual(key.stringValue, "createdAt")
        }

        let container = temporaryDirectory.appendingPathComponent(
            "MissingCreatedAtQueue",
            isDirectory: true
        )
        let pendingDirectory = container.appendingPathComponent("PendingClips", isDirectory: true)
        try FileManager.default.createDirectory(
            at: pendingDirectory,
            withIntermediateDirectories: true
        )
        let pendingURL = pendingDirectory
            .appendingPathComponent(payload.id.uuidString)
            .appendingPathExtension("json")
        try missingCreatedAtData.write(to: pendingURL)

        XCTAssertTrue(try SharedClipQueue.pendingItems(containerURL: container).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL.path))
        let failedURLs = try FileManager.default.contentsOfDirectory(
            at: container.appendingPathComponent("FailedClips", isDirectory: true),
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(failedURLs.count, 1)
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(failedURLs.first)), missingCreatedAtData)
    }

    func testUndecodableCommittedGroupedPayloadQuarantinesEveryOriginalAttachment() throws {
        let container = temporaryDirectory.appendingPathComponent(
            "UndecodableGroupedBatch",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 6, height: 4)).image { context in
            UIColor.systemPurple.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 6, height: 4))
        }
        let imageData = try XCTUnwrap(image.pngData())
        let imageAsset = try SharedImageAsset(
            validatingData: imageData,
            typeIdentifier: UTType.png.identifier
        )
        let pdfData = Data("%PDF-1.4\nGrouped attachment\n%%EOF".utf8)
        let pdfURL = temporaryDirectory.appendingPathComponent("grouped-corrupt-payload.pdf")
        try pdfData.write(to: pdfURL)
        let attachmentAssets = [
            SharedAttachmentAsset(
                imageAsset: imageAsset,
                originalFileName: "original.png",
                typeIdentifier: UTType.png.identifier
            ),
            try SharedAttachmentAsset(
                validatingFileAt: pdfURL,
                typeIdentifier: UTType.pdf.identifier,
                originalFileName: "original.pdf"
            )
        ]
        let payload = SharedClipPayload(
            type: .file,
            title: "Grouped originals",
            source: "Files",
            createdAt: Date()
        )
        try SharedClipQueue.enqueueBatch(
            [SharedClipQueue.BatchItem(payload: payload, attachmentAssets: attachmentAssets)],
            containerURL: container
        )

        let queued = try XCTUnwrap(
            SharedClipQueue.pendingItems(containerURL: container).first?.payload
        )
        XCTAssertEqual(queued.attachments.map(\.originalFileName), ["original.png", "original.pdf"])
        let expectedDataByFileName = try Dictionary(uniqueKeysWithValues:
            zip(queued.attachments, [imageData, pdfData]).map { attachment, data in
                (try XCTUnwrap(attachment.storedFileName), data)
            }
        )

        let committedRoot = container.appendingPathComponent(
            SharedClipQueue.pendingBatchesDirectoryName,
            isDirectory: true
        )
        let batchDirectory = try XCTUnwrap(FileManager.default.contentsOfDirectory(
            at: committedRoot,
            includingPropertiesForKeys: [.isDirectoryKey]
        ).first)
        let payloadURL = batchDirectory
            .appendingPathComponent("Payloads", isDirectory: true)
            .appendingPathComponent(payload.id.uuidString)
            .appendingPathExtension("json")
        let validPayloadData = try Data(contentsOf: payloadURL)
        var payloadObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: validPayloadData) as? [String: Any]
        )
        payloadObject.removeValue(forKey: "createdAt")
        let undecodablePayloadData = try JSONSerialization.data(
            withJSONObject: payloadObject,
            options: [.sortedKeys]
        )
        try undecodablePayloadData.write(to: payloadURL, options: .atomic)
        XCTAssertThrowsError(
            try JSONDecoder().decode(SharedClipPayload.self, from: undecodablePayloadData)
        )

        XCTAssertTrue(try SharedClipQueue.pendingItems(containerURL: container).isEmpty)

        let failedClipRoot = container.appendingPathComponent("FailedClips", isDirectory: true)
        let failedClipURLs = try FileManager.default.contentsOfDirectory(
            at: failedClipRoot,
            includingPropertiesForKeys: nil
        )
        let quarantinedPayloadURL = try XCTUnwrap(failedClipURLs.first { url in
            url.lastPathComponent.hasSuffix("\(payload.id.uuidString).json")
        })
        XCTAssertEqual(try Data(contentsOf: quarantinedPayloadURL), undecodablePayloadData)

        let quarantineRoots = [
            failedClipRoot,
            container.appendingPathComponent("FailedImages", isDirectory: true)
        ]
        let quarantinedURLs = quarantineRoots.flatMap { root -> [URL] in
            guard FileManager.default.fileExists(atPath: root.path),
                  let enumerator = FileManager.default.enumerator(
                    at: root,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles],
                    errorHandler: nil
                  ) else { return [] }
            return enumerator.compactMap { $0 as? URL }.filter { url in
                (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            }
        }
        let quarantinedByFileName = Dictionary(
            quarantinedURLs.map { ($0.lastPathComponent, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        XCTAssertEqual(
            Set(expectedDataByFileName.keys).intersection(Set(quarantinedByFileName.keys)).count,
            expectedDataByFileName.count,
            "Every grouped original must survive payload quarantine"
        )
        for (fileName, expectedData) in expectedDataByFileName {
            let quarantinedURL = try XCTUnwrap(quarantinedByFileName[fileName])
            XCTAssertEqual(try Data(contentsOf: quarantinedURL), expectedData)
        }
    }

    func testCommittedBatchDoesNotExposeLeadingValidPayloadWhenLaterPayloadIsCorrupt() throws {
        let validPayloadID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000001")
        )
        let corruptPayloadID = try XCTUnwrap(
            UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
        )
        let validAttachmentID = try XCTUnwrap(
            UUID(uuidString: "11111111-1111-1111-1111-111111111111")
        )
        let corruptAttachmentID = try XCTUnwrap(
            UUID(uuidString: "22222222-2222-2222-2222-222222222222")
        )
        let container = temporaryDirectory.appendingPathComponent(
            "LeadingValidThenCorruptBatch",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 5, height: 5)).image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 5, height: 5))
        }
        let imageData = try XCTUnwrap(image.pngData())
        let imageAsset = try SharedImageAsset(
            validatingData: imageData,
            typeIdentifier: UTType.png.identifier
        )
        let pdfData = Data("%PDF-1.4\nLater corrupt payload\n%%EOF".utf8)
        let pdfURL = temporaryDirectory.appendingPathComponent("later-corrupt.pdf")
        try pdfData.write(to: pdfURL)
        let validAttachment = SharedAttachmentAsset(
            imageAsset: imageAsset,
            originalFileName: "leading-valid.png",
            typeIdentifier: UTType.png.identifier,
            id: validAttachmentID
        )
        let corruptAttachment = try SharedAttachmentAsset(
            validatingFileAt: pdfURL,
            typeIdentifier: UTType.pdf.identifier,
            originalFileName: "later-corrupt.pdf",
            id: corruptAttachmentID
        )
        let createdAt = Date()
        let validPayload = SharedClipPayload(
            id: validPayloadID,
            type: .image,
            title: "Leading valid payload",
            source: "Photos",
            createdAt: createdAt
        )
        let corruptPayload = SharedClipPayload(
            id: corruptPayloadID,
            type: .file,
            title: "Later corrupt payload",
            source: "Files",
            createdAt: createdAt
        )
        // Write the corrupt item first so filename sorting, rather than insertion order,
        // establishes that the valid payload is decoded before the corrupt payload.
        try SharedClipQueue.enqueueBatch(
            [
                SharedClipQueue.BatchItem(
                    payload: corruptPayload,
                    attachmentAssets: [corruptAttachment]
                ),
                SharedClipQueue.BatchItem(
                    payload: validPayload,
                    attachmentAssets: [validAttachment]
                )
            ],
            containerURL: container
        )

        let committedRoot = container.appendingPathComponent(
            SharedClipQueue.pendingBatchesDirectoryName,
            isDirectory: true
        )
        let batchDirectory = try XCTUnwrap(FileManager.default.contentsOfDirectory(
            at: committedRoot,
            includingPropertiesForKeys: [.isDirectoryKey]
        ).first)
        let payloadsDirectory = batchDirectory.appendingPathComponent("Payloads", isDirectory: true)
        let payloadURLs = try FileManager.default.contentsOfDirectory(
            at: payloadsDirectory,
            includingPropertiesForKeys: nil
        ).sorted { $0.lastPathComponent < $1.lastPathComponent }
        let validPayloadURL = payloadsDirectory
            .appendingPathComponent(validPayloadID.uuidString)
            .appendingPathExtension("json")
        let corruptPayloadURL = payloadsDirectory
            .appendingPathComponent(corruptPayloadID.uuidString)
            .appendingPathExtension("json")
        XCTAssertEqual(payloadURLs.map(\.lastPathComponent), [
            validPayloadURL.lastPathComponent,
            corruptPayloadURL.lastPathComponent
        ])
        XCTAssertLessThan(validPayloadURL.lastPathComponent, corruptPayloadURL.lastPathComponent)
        let validPayloadData = try Data(contentsOf: validPayloadURL)
        let originalCorruptPayloadData = try Data(contentsOf: corruptPayloadURL)
        var corruptObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: originalCorruptPayloadData) as? [String: Any]
        )
        corruptObject.removeValue(forKey: "createdAt")
        let corruptPayloadData = try JSONSerialization.data(
            withJSONObject: corruptObject,
            options: [.sortedKeys]
        )
        try corruptPayloadData.write(to: corruptPayloadURL, options: .atomic)

        let pending = try SharedClipQueue.pendingItems(containerURL: container)

        XCTAssertTrue(pending.isEmpty, "No leading valid Item may escape a corrupt atomic batch")
        let failedPayloadURLs = try FileManager.default.contentsOfDirectory(
            at: container.appendingPathComponent("FailedClips", isDirectory: true),
            includingPropertiesForKeys: nil
        )
        let failedPayloadData = try Dictionary(uniqueKeysWithValues: failedPayloadURLs.map {
            ($0.lastPathComponent, try Data(contentsOf: $0))
        })
        XCTAssertEqual(failedPayloadData[validPayloadURL.lastPathComponent], validPayloadData)
        XCTAssertEqual(failedPayloadData[corruptPayloadURL.lastPathComponent], corruptPayloadData)

        let expectedOriginals = [
            try XCTUnwrap(validAttachment.attachment.storedFileName): imageData,
            try XCTUnwrap(corruptAttachment.attachment.storedFileName): pdfData
        ]
        let failedOriginalURLs = try FileManager.default.contentsOfDirectory(
            at: container.appendingPathComponent("FailedImages", isDirectory: true),
            includingPropertiesForKeys: nil
        )
        let failedOriginalData = try Dictionary(uniqueKeysWithValues: failedOriginalURLs.map {
            ($0.lastPathComponent, try Data(contentsOf: $0))
        })
        XCTAssertEqual(Set(failedOriginalData.keys), Set(expectedOriginals.keys))
        for (fileName, expectedData) in expectedOriginals {
            XCTAssertEqual(failedOriginalData[fileName], expectedData)
        }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(
            at: committedRoot,
            includingPropertiesForKeys: nil
        ).isEmpty)
    }

    func testShareQueueKeepsLegacyMultiPayloadImageBatchImportCompatible() throws {
        let container = temporaryDirectory.appendingPathComponent("BatchImageQueue", isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.systemYellow.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let asset = try XCTUnwrap(SharedImageAsset(data: try XCTUnwrap(image.pngData())))
        let createdAt = Date()
        let payloads = (0..<3).map { index in
            let id = UUID()
            return SharedClipPayload(
                id: id,
                type: .image,
                title: "Shared image \(index + 1)",
                source: "Photos",
                createdAt: createdAt.addingTimeInterval(Double(index) / 1_000)
            )
        }

        try SharedClipQueue.enqueueBatch(
            payloads.map { SharedClipQueue.BatchItem(payload: $0, imageAsset: asset) },
            containerURL: container
        )

        let queued = try SharedClipQueue.pendingItems(containerURL: container)
        XCTAssertEqual(queued.map(\.payload.id), payloads.map(\.id))
        XCTAssertEqual(queued.compactMap(\.payload.sharedImageName).count, 3)
        let pendingImageURLs = try queued.map { item in
            try XCTUnwrap(SharedClipQueue.imageURL(
                named: try XCTUnwrap(item.payload.sharedImageName),
                containerURL: container
            ))
        }
        XCTAssertTrue(pendingImageURLs.allSatisfy {
            $0.path.contains(SharedClipQueue.pendingBatchesDirectoryName)
        })

        let store = AppStore(fileURL: dataURL, userDefaults: defaults)
        store.importSharedClips(containerURL: container)

        XCTAssertEqual(store.clips.compactMap(\.sharePayloadID), payloads.map(\.id))
        XCTAssertEqual(store.clips.filter { $0.type == .image }.count, 3)
        XCTAssertTrue(try SharedClipQueue.pendingItems(containerURL: container).isEmpty)
        let promotedURLs = try store.clips.compactMap(\.sharedImageName).map { name in
            try XCTUnwrap(SharedClipQueue.imageURL(named: name, containerURL: container))
        }
        XCTAssertTrue(promotedURLs.allSatisfy { $0.path.contains("SharedImages") })
        XCTAssertTrue(promotedURLs.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
    }

    func testShareAttachmentBundleImportsAsOneClipWithEveryOriginal() throws {
        let container = temporaryDirectory.appendingPathComponent("GroupedAttachmentQueue", isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let imageAsset = try SharedImageAsset(
            validatingData: try XCTUnwrap(image.pngData()),
            typeIdentifier: UTType.png.identifier
        )
        let pdfURL = temporaryDirectory.appendingPathComponent("reference.pdf")
        try Data("%PDF-1.4\n%%EOF".utf8).write(to: pdfURL)
        let attachmentAssets = [
            SharedAttachmentAsset(
                imageAsset: imageAsset,
                originalFileName: "cover.png",
                typeIdentifier: UTType.png.identifier
            ),
            SharedAttachmentAsset(
                imageAsset: imageAsset,
                originalFileName: "detail.png",
                typeIdentifier: UTType.png.identifier
            ),
            try SharedAttachmentAsset(
                validatingFileAt: pdfURL,
                typeIdentifier: UTType.pdf.identifier,
                originalFileName: "reference.pdf"
            )
        ]
        let payload = SharedClipPayload(
            type: .file,
            title: "cover.png 외 2개",
            source: "파일"
        )

        try SharedClipQueue.enqueueBatch(
            [SharedClipQueue.BatchItem(payload: payload, attachmentAssets: attachmentAssets)],
            containerURL: container
        )

        let queued = try SharedClipQueue.pendingItems(containerURL: container)
        XCTAssertEqual(queued.count, 1)
        XCTAssertEqual(queued.first?.payload.id, payload.id)
        XCTAssertEqual(queued.first?.payload.attachments.count, 3)
        XCTAssertEqual(queued.first?.payload.attachments.map(\.originalFileName), [
            "cover.png", "detail.png", "reference.pdf"
        ])
        XCTAssertEqual(queued.first?.payload.type, .file)
        XCTAssertNotNil(queued.first?.payload.sharedImageName)

        let store = AppStore(fileURL: dataURL, userDefaults: defaults)
        store.importSharedClips(containerURL: container)

        let imported = try XCTUnwrap(store.clips.first(where: { $0.sharePayloadID == payload.id }))
        XCTAssertEqual(store.clips.filter { $0.sharePayloadID == payload.id }.count, 1)
        XCTAssertEqual(imported.type, .file)
        XCTAssertEqual(imported.attachments.count, 3)
        let importedURLs = imported.attachments.compactMap { attachment in
            attachment.storedFileName.flatMap {
                SharedClipQueue.attachmentURL(named: $0, containerURL: container)
            }
        }
        XCTAssertEqual(importedURLs.count, 3)
        XCTAssertTrue(importedURLs.allSatisfy {
            $0.path.contains("SharedImages")
                && FileManager.default.fileExists(atPath: $0.path)
        })
        XCTAssertTrue(try SharedClipQueue.pendingItems(containerURL: container).isEmpty)
    }

    func testGroupedSharePayloadCreatedAtImportsAndPersistsAcrossReload() throws {
        let container = temporaryDirectory.appendingPathComponent(
            "GroupedAttachmentCreatedAtQueue",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let firstURL = temporaryDirectory.appendingPathComponent("grouped-first.txt")
        let secondURL = temporaryDirectory.appendingPathComponent("grouped-second.pdf")
        try Data("first attachment".utf8).write(to: firstURL)
        try Data("%PDF-1.4\nsecond attachment".utf8).write(to: secondURL)
        let attachmentAssets = [
            try SharedAttachmentAsset(
                validatingFileAt: firstURL,
                typeIdentifier: UTType.plainText.identifier,
                originalFileName: "first.txt"
            ),
            try SharedAttachmentAsset(
                validatingFileAt: secondURL,
                typeIdentifier: UTType.pdf.identifier,
                originalFileName: "second.pdf"
            )
        ]
        let createdAt = Date(
            timeIntervalSince1970: floor(Date().timeIntervalSince1970) - 60
        )
        let payload = SharedClipPayload(
            type: .file,
            title: "Grouped files",
            source: "Files",
            createdAt: createdAt
        )
        try SharedClipQueue.enqueueBatch(
            [SharedClipQueue.BatchItem(payload: payload, attachmentAssets: attachmentAssets)],
            containerURL: container
        )

        let queued = try XCTUnwrap(
            SharedClipQueue.pendingItems(containerURL: container).first?.payload
        )
        XCTAssertEqual(queued.createdAt, createdAt)
        XCTAssertEqual(queued.attachments.count, 2)

        let store = AppStore(fileURL: dataURL, userDefaults: defaults)
        store.importSharedClips(containerURL: container)
        let imported = try XCTUnwrap(
            store.clips.first(where: { $0.sharePayloadID == payload.id })
        )
        XCTAssertEqual(imported.createdAt, createdAt)
        XCTAssertEqual(imported.attachments.count, 2)

        let reloaded = AppStore(fileURL: dataURL, userDefaults: defaults)
        let persisted = try XCTUnwrap(
            reloaded.clips.first(where: { $0.sharePayloadID == payload.id })
        )
        XCTAssertEqual(persisted.createdAt, createdAt)
        XCTAssertEqual(persisted.attachments.map(\.originalFileName), ["first.txt", "second.pdf"])
    }

    func testAttachmentPasteboardPreparationPreservesAllAndSelectedOrderDataAndUTI() throws {
        let sourceDirectory = temporaryDirectory.appendingPathComponent(
            "PasteboardAttachmentSources",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: sourceDirectory,
            withIntermediateDirectories: true
        )
        let fixtures: [(UUID, String, Data, UTType)] = [
            (UUID(), "first.bin", Data([0x01, 0x02]), .png),
            (UUID(), "second.bin", Data([0x10, 0x11, 0x12]), .pdf),
            (UUID(), "third.bin", Data("third".utf8), .plainText)
        ]
        let items = try fixtures.map { id, name, data, type in
            let url = sourceDirectory.appendingPathComponent(name)
            try data.write(to: url)
            return ClipStoredAttachment(
                attachment: SharedClipAttachment(
                    id: id,
                    kind: type.conforms(to: .image) ? .image : .file,
                    originalFileName: name,
                    typeIdentifier: type.identifier,
                    byteCount: Int64(data.count)
                ),
                url: url
            )
        }

        let allPayloads = try ClipAttachmentPasteboard.prepareAttachments(items)
        XCTAssertEqual(allPayloads.map(\.data), fixtures.map { $0.2 })
        XCTAssertEqual(allPayloads.map(\.typeIdentifier), fixtures.map { $0.3.identifier })

        let selectedItems = ClipAttachmentPasteboard.selectedAttachments(
            from: items,
            selectedIDs: Set([fixtures[2].0, fixtures[0].0])
        )
        XCTAssertEqual(selectedItems.map(\.id), [fixtures[0].0, fixtures[2].0])
        let selectedPayloads = try ClipAttachmentPasteboard.prepareAttachments(selectedItems)
        XCTAssertEqual(selectedPayloads.map(\.data), [fixtures[0].2, fixtures[2].2])
        XCTAssertEqual(
            selectedPayloads.map(\.typeIdentifier),
            [fixtures[0].3.identifier, fixtures[2].3.identifier]
        )
    }

    func testAttachmentPasteboardPreparationFailsWithoutReturningPartialPayloads() throws {
        let validData = Data([0xCA, 0xFE, 0xBA, 0xBE])
        let validURL = temporaryDirectory.appendingPathComponent("pasteboard-valid.bin")
        try validData.write(to: validURL)
        let missingURL = temporaryDirectory.appendingPathComponent("pasteboard-missing.bin")
        let validID = UUID()
        let missingID = UUID()
        let items = [
            ClipStoredAttachment(
                attachment: SharedClipAttachment(
                    id: validID,
                    kind: .file,
                    originalFileName: "valid.bin",
                    typeIdentifier: UTType.data.identifier,
                    byteCount: Int64(validData.count)
                ),
                url: validURL
            ),
            ClipStoredAttachment(
                attachment: SharedClipAttachment(
                    id: missingID,
                    kind: .file,
                    originalFileName: "missing.bin",
                    typeIdentifier: UTType.data.identifier,
                    byteCount: 1
                ),
                url: missingURL
            )
        ]
        var attachmentPayloads: [ClipPasteboardPayload]?
        XCTAssertThrowsError(
            attachmentPayloads = try ClipAttachmentPasteboard.prepareAttachments(items)
        )
        XCTAssertNil(attachmentPayloads)

        let imageSources = [
            ClipImageSource(
                id: "valid",
                attachmentID: validID,
                displayName: "valid.bin",
                fileURL: validURL,
                assetName: nil,
                typeIdentifier: UTType.png.identifier
            ),
            ClipImageSource(
                id: "missing",
                attachmentID: missingID,
                displayName: "missing.bin",
                fileURL: missingURL,
                assetName: nil,
                typeIdentifier: UTType.png.identifier
            )
        ]
        var imagePayloads: [ClipPasteboardPayload]?
        XCTAssertThrowsError(
            imagePayloads = try ClipAttachmentPasteboard.prepareImageSources(imageSources)
        )
        XCTAssertNil(imagePayloads)
    }

    func testShareQueueRejectsAttachmentBundleAboveInvocationLimit() throws {
        let container = temporaryDirectory.appendingPathComponent("OversizedAttachmentBundle", isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.systemIndigo.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let imageAsset = try SharedImageAsset(
            validatingData: try XCTUnwrap(image.pngData()),
            typeIdentifier: UTType.png.identifier
        )
        let attachment = SharedAttachmentAsset(
            imageAsset: imageAsset,
            originalFileName: "item.png",
            typeIdentifier: UTType.png.identifier
        )
        let item = SharedClipQueue.BatchItem(
            payload: SharedClipPayload(type: .image, title: "Too many", source: "test"),
            attachmentAssets: Array(
                repeating: attachment,
                count: SharedClipQueue.maxShareBatchItemCount + 1
            )
        )

        XCTAssertThrowsError(try SharedClipQueue.enqueueBatch([item], containerURL: container)) { error in
            XCTAssertEqual(
                error as? SharedClipQueue.QueueError,
                .batchItemLimitReached(SharedClipQueue.maxShareBatchItemCount)
            )
        }
        XCTAssertTrue(try SharedClipQueue.pendingItems(containerURL: container).isEmpty)
    }

    func testShareImportShowsNewerInvocationsFirstWithoutReversingEachSelection() throws {
        let container = temporaryDirectory.appendingPathComponent("BatchDisplayOrder", isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let baseDate = Date().addingTimeInterval(-120)
        let older = (0..<2).map { index in
            SharedClipPayload(
                type: .text,
                title: "Older \(index + 1)",
                source: "Share sheet",
                text: "Older \(index + 1)",
                createdAt: baseDate.addingTimeInterval(Double(index) / 1_000)
            )
        }
        let newer = (0..<2).map { index in
            SharedClipPayload(
                type: .text,
                title: "Newer \(index + 1)",
                source: "Share sheet",
                text: "Newer \(index + 1)",
                createdAt: baseDate.addingTimeInterval(60 + Double(index) / 1_000)
            )
        }
        try SharedClipQueue.enqueueBatch(
            older.map { SharedClipQueue.BatchItem(payload: $0) },
            containerURL: container
        )
        try SharedClipQueue.enqueueBatch(
            newer.map { SharedClipQueue.BatchItem(payload: $0) },
            containerURL: container
        )

        let store = AppStore(fileURL: dataURL, userDefaults: defaults)
        store.importSharedClips(containerURL: container)

        XCTAssertEqual(
            store.clips.compactMap(\.sharePayloadID),
            newer.map(\.id) + older.map(\.id)
        )
    }

    func testShareQueueRejectsOversizedInvocationWithoutArtifacts() throws {
        let container = temporaryDirectory.appendingPathComponent("OversizedBatchQueue", isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let items = (0...SharedClipQueue.maxShareBatchItemCount).map { index in
            SharedClipQueue.BatchItem(payload: SharedClipPayload(
                type: .text,
                title: "Shared text \(index)",
                source: "test",
                text: "value"
            ))
        }

        XCTAssertThrowsError(try SharedClipQueue.enqueueBatch(items, containerURL: container)) { error in
            XCTAssertEqual(
                error as? SharedClipQueue.QueueError,
                .batchItemLimitReached(SharedClipQueue.maxShareBatchItemCount)
            )
        }
        XCTAssertTrue(try SharedClipQueue.pendingItems(containerURL: container).isEmpty)
        let committedRoot = container.appendingPathComponent(
            SharedClipQueue.pendingBatchesDirectoryName,
            isDirectory: true
        )
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(
            at: committedRoot,
            includingPropertiesForKeys: nil
        ).isEmpty)
    }

    func testShareQueueFailedBatchWriteLeavesNoVisibleOrStagedArtifacts() throws {
        let container = temporaryDirectory.appendingPathComponent("FailedBatchQueue", isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let data = try XCTUnwrap(image.pngData())
        let validAsset = try SharedImageAsset(validatingData: data, typeIdentifier: UTType.png.identifier)
        let disappearingSource = temporaryDirectory.appendingPathComponent("disappearing.png")
        try data.write(to: disappearingSource)
        let missingAsset = try SharedImageAsset(
            validatingFileAt: disappearingSource,
            typeIdentifier: UTType.png.identifier
        )
        try FileManager.default.removeItem(at: disappearingSource)
        let items = [validAsset, missingAsset].enumerated().map { index, asset in
            SharedClipQueue.BatchItem(
                payload: SharedClipPayload(
                    type: .image,
                    title: "Shared image \(index)",
                    source: "Photos",
                    createdAt: Date().addingTimeInterval(Double(index) / 1_000)
                ),
                imageAsset: asset
            )
        }

        XCTAssertThrowsError(try SharedClipQueue.enqueueBatch(items, containerURL: container))
        XCTAssertTrue(try SharedClipQueue.pendingItems(containerURL: container).isEmpty)
        for directoryName in [
            SharedClipQueue.pendingBatchesDirectoryName,
            SharedClipQueue.stagingBatchesDirectoryName
        ] {
            let directory = container.appendingPathComponent(directoryName, isDirectory: true)
            XCTAssertTrue(try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).isEmpty)
        }
    }

    func testShareImportCommitFailureLeavesAtomicBatchAvailableForRetry() throws {
        let container = temporaryDirectory.appendingPathComponent("RetryBatchQueue", isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.systemYellow.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let asset = try SharedImageAsset(
            validatingData: try XCTUnwrap(image.pngData()),
            typeIdentifier: UTType.png.identifier
        )
        let payload = SharedClipPayload(
            type: .image,
            title: "Retry image",
            source: "Photos"
        )
        try SharedClipQueue.enqueueBatch(
            [SharedClipQueue.BatchItem(payload: payload, imageAsset: asset)],
            containerURL: container
        )
        let repository = TestClipRepository(
            bootstrapHandler: {
                .loaded(DataSnapshot(version: 2, clips: [], folders: DefaultData.folders,
                                     preferences: .standard))
            },
            commitError: ClipRepositoryError.writeFailed
        )
        let store = AppStore(userDefaults: defaults, repository: repository)

        store.importSharedClips(containerURL: container)

        XCTAssertTrue(store.clips.isEmpty)
        let pending = try SharedClipQueue.pendingItems(containerURL: container)
        XCTAssertEqual(pending.map(\.payload.id), [payload.id])
        let imageName = try XCTUnwrap(pending.first?.payload.sharedImageName)
        let pendingImage = try XCTUnwrap(SharedClipQueue.imageURL(
            named: imageName,
            containerURL: container
        ))
        XCTAssertTrue(pendingImage.path.contains(SharedClipQueue.pendingBatchesDirectoryName))
        XCTAssertTrue(FileManager.default.fileExists(atPath: pendingImage.path))
    }

    func testShareQueueQuarantinesCommittedImagePayloadWhenOriginalIsMissing() throws {
        let container = temporaryDirectory.appendingPathComponent("MissingBatchImage", isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let asset = try SharedImageAsset(
            validatingData: try XCTUnwrap(image.pngData()),
            typeIdentifier: UTType.png.identifier
        )
        let payload = SharedClipPayload(type: .image, title: "Missing image", source: "Photos")
        try SharedClipQueue.enqueueBatch(
            [SharedClipQueue.BatchItem(payload: payload, imageAsset: asset)],
            containerURL: container
        )
        let queued = try XCTUnwrap(SharedClipQueue.pendingItems(containerURL: container).first)
        let imageName = try XCTUnwrap(queued.payload.sharedImageName)
        let pendingImage = try XCTUnwrap(SharedClipQueue.imageURL(
            named: imageName,
            containerURL: container
        ))
        try FileManager.default.removeItem(at: pendingImage)

        XCTAssertTrue(try SharedClipQueue.pendingItems(containerURL: container).isEmpty)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(
            at: container.appendingPathComponent("FailedClips", isDirectory: true),
            includingPropertiesForKeys: nil
        ).count, 1)
    }

    func testShareQueueCleansOnlyStaleStagingBatches() throws {
        let container = temporaryDirectory.appendingPathComponent("StaleBatchQueue", isDirectory: true)
        let stagingRoot = container.appendingPathComponent(
            SharedClipQueue.stagingBatchesDirectoryName,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
        let stale = stagingRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let recent = stagingRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: stale, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: recent, withIntermediateDirectories: true)
        let now = Date()
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-SharedClipQueue.maxStagingBatchAge - 1)],
            ofItemAtPath: stale.path
        )

        _ = try SharedClipQueue.pendingItems(containerURL: container, now: now)

        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recent.path))
    }

    func testShareQueueRejectsNewItemsAtCountLimit() throws {
        let container = temporaryDirectory.appendingPathComponent("QueueLimit", isDirectory: true)
        let pending = container.appendingPathComponent("PendingClips", isDirectory: true)
        try FileManager.default.createDirectory(at: pending, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        for index in 0..<SharedClipQueue.maxPendingItemCount {
            let payload = SharedClipPayload(
                id: UUID(), type: .text, title: "\(index)", source: "test", text: "value"
            )
            try encoder.encode(payload).write(
                to: pending.appendingPathComponent(payload.id.uuidString).appendingPathExtension("json")
            )
        }

        XCTAssertThrowsError(try SharedClipQueue.enqueue(
            SharedClipPayload(type: .text, title: "extra", source: "test", text: "extra"),
            containerURL: container
        )) { error in
            XCTAssertEqual(error as? SharedClipQueue.QueueError,
                           .itemLimitReached(SharedClipQueue.maxPendingItemCount))
        }
    }

    func testProviderDeadlineTimesOutAndCancelsUnderlyingProgress() async {
        let progress = Progress(totalUnitCount: 1)

        do {
            let _: String = try await ProviderDeadline.load(timeout: 0.01) { _ in progress }
            XCTFail("Expected provider deadline to time out")
        } catch {
            XCTAssertEqual(error as? ProviderDeadlineError, .timedOut)
            XCTAssertTrue(progress.isCancelled)
        }
    }

    func testShareImportIdentityPreventsDuplicateAfterQueueRemovalFailureWindow() throws {
        let container = temporaryDirectory.appendingPathComponent("ImportQueue", isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let payload = SharedClipPayload(
            id: UUID(), type: .link, title: "Example", source: "example.com",
            url: "https://example.com", createdAt: Date()
        )
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        try SharedClipQueue.enqueue(payload, containerURL: container)
        store.importSharedClips(containerURL: container)
        try SharedClipQueue.enqueue(payload, containerURL: container)
        store.importSharedClips(containerURL: container)

        XCTAssertEqual(store.clips.count, 1)
        XCTAssertEqual(store.clips.first?.sharePayloadID, payload.id)
        XCTAssertTrue(try SharedClipQueue.pendingItems(containerURL: container).isEmpty)
    }

    func testFileBackedImageAssetEnforcesByteCapAndPreservesBytes() throws {
        let sourceSize = CGSize(width: 32, height: 24)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: sourceSize, format: format).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: sourceSize))
        }
        let originalData = try XCTUnwrap(image.pngData())
        let sourceURL = temporaryDirectory.appendingPathComponent("source.png")
        try originalData.write(to: sourceURL)
        let asset = try SharedImageAsset(validatingFileAt: sourceURL, typeIdentifier: UTType.png.identifier)
        let container = temporaryDirectory.appendingPathComponent("ImageContainer", isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)

        let name = try SharedClipQueue.storeImageAsset(asset, for: UUID(), containerURL: container)
        let storedURL = try XCTUnwrap(SharedClipQueue.imageURL(named: name, containerURL: container))
        XCTAssertEqual(try Data(contentsOf: storedURL), originalData)
        XCTAssertEqual(asset.pixelCount, 32 * 24)

        let oversizedURL = temporaryDirectory.appendingPathComponent("oversized.png")
        FileManager.default.createFile(atPath: oversizedURL.path, contents: Data([0]))
        let handle = try FileHandle(forWritingTo: oversizedURL)
        try handle.truncate(atOffset: UInt64(SharedImageAsset.maxBytes + 1))
        try handle.close()
        XCTAssertThrowsError(try SharedImageAsset(validatingFileAt: oversizedURL)) { error in
            XCTAssertEqual(error as? SharedImageAssetError, .tooLarge(maxMegabytes: 50))
        }
    }

    func testStorageSummarySeparatesSnapshotImagesPendingAndQuarantine() throws {
        let container = temporaryDirectory.appendingPathComponent("StorageSummary", isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let asset = try XCTUnwrap(SharedImageAsset(data: try XCTUnwrap(image.pngData())))
        _ = try SharedClipQueue.storeImageAsset(asset, for: UUID(), containerURL: container)
        let payload = SharedClipPayload(type: .image, title: "pending", source: "test")
        try SharedClipQueue.enqueueBatch(
            [SharedClipQueue.BatchItem(payload: payload, imageAsset: asset)],
            containerURL: container
        )
        let pendingDirectory = container.appendingPathComponent("PendingClips", isDirectory: true)
        try Data("broken".utf8).write(to: pendingDirectory.appendingPathComponent("broken.json"))

        let shared = try SharedClipQueue.storageSummary(containerURL: container)
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)
        let app = try store.storageSummary(containerURL: container)

        XCTAssertEqual(shared.originalAttachmentCount, 1)
        XCTAssertGreaterThan(shared.originalAttachmentBytes, 0)
        XCTAssertEqual(shared.pendingCount, 1)
        XCTAssertGreaterThan(shared.pendingBytes, asset.byteCount)
        XCTAssertEqual(shared.quarantinedCount, 1)
        XCTAssertGreaterThan(app.snapshotBytes, 0)
        XCTAssertEqual(app.originalAttachmentCount, shared.originalAttachmentCount)
    }
}
