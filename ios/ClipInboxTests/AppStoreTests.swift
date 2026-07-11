import XCTest
import UIKit
import UniformTypeIdentifiers
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

        XCTAssertEqual(store.filteredClips(.interior).map(\.id), [1])
        XCTAssertEqual(store.filteredClips(.reference).map(\.id), [2])
        XCTAssertEqual(store.filteredClips(.idea).map(\.id), [3])
        XCTAssertEqual(store.filteredClips(.travel).map(\.id), [4])
        XCTAssertEqual(store.searchResults(query: "대시보드", filter: "레퍼런스").map(\.id), [2])
        XCTAssertEqual(store.searchResults(query: "아이디어", filter: "태그").map(\.id), [3])
    }

    func testPrimaryMutationsPersistAcrossReload() throws {
        try seedDefaultLibrary()
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        store.toggleBookmark(id: 1)
        store.moveClip(id: 1, to: "업무")
        store.updateMemo(id: 1, memo: "다시 확인할 메모")
        _ = try store.createFolder(name: "읽을거리", defaultTag: "읽을거리")
        let added = try store.saveNewClip(destination: "업무", tags: ["읽을거리"], memo: "새 메모")
        store.deleteClip(id: 5)

        let reloaded = AppStore(fileURL: dataURL, userDefaults: defaults)
        XCTAssertEqual(reloaded.clip(id: 1)?.bookmarked, true)
        XCTAssertEqual(reloaded.clip(id: 1)?.folder, "업무")
        XCTAssertEqual(reloaded.clip(id: 1)?.memo, "다시 확인할 메모")
        XCTAssertTrue(reloaded.folders.contains { $0.label == "읽을거리" })
        XCTAssertEqual(reloaded.clip(id: added.id)?.tags, ["읽을거리"])
        XCTAssertNil(reloaded.clip(id: 5))
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

        store.moveClip(id: 5, to: "기본 폴더")
        store.updatePreference(key: .defaultFolder, value: "기본 폴더")
        XCTAssertEqual(try store.renameFolder(from: "기본 폴더", to: "받은 클립"), "받은 클립")
        XCTAssertEqual(try store.renameFolder(from: "전체", to: "모든 클립"), "모든 클립")

        let reloaded = AppStore(fileURL: dataURL, userDefaults: defaults)
        XCTAssertTrue(reloaded.folders.contains { $0.label == "받은 클립" && $0.icon == "inbox" })
        XCTAssertTrue(reloaded.folders.contains { $0.label == "모든 클립" && $0.icon == "archive" })
        XCTAssertFalse(reloaded.folders.contains { $0.label == "기본 폴더" })
        XCTAssertFalse(reloaded.folders.contains { $0.label == "전체" })
        XCTAssertEqual(reloaded.preferences.defaultFolder, "받은 클립")
        XCTAssertEqual(reloaded.clip(id: 5)?.folder, "받은 클립")
        XCTAssertEqual(reloaded.folderCount("모든 클립"), reloaded.clips.count)
    }

    func testFolderRenameRejectsDuplicateNamesWithoutChangingData() throws {
        try seedDefaultLibrary()
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        XCTAssertThrowsError(try store.renameFolder(from: "기본 폴더", to: "폴더 1"))
        XCTAssertTrue(store.folders.contains { $0.label == "기본 폴더" })
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
            "전체", "기본 폴더", "폴더 1", "폴더 2", "폴더 3", "폴더 4", "폴더 5"
        ])
        store.updatePreference(key: .theme, value: "다크")

        let reloaded = AppStore(fileURL: dataURL, userDefaults: defaults)
        XCTAssertEqual(reloaded.preferences.theme, "다크")
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
    }

    func testLinkOpeningDefaultsToDirectAndPersistsConfirmationChoice() {
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        XCTAssertEqual(store.linkOpenMode, .direct)
        store.updateLinkOpenMode(.confirm)

        let reloaded = AppStore(fileURL: dataURL, userDefaults: defaults)
        XCTAssertEqual(reloaded.linkOpenMode, .confirm)
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
}
