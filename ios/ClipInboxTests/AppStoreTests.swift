import XCTest
@testable import ClipInbox

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

    func testRecentSearchesAreRealDeduplicatedLimitedAndPersisted() {
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        XCTAssertTrue(store.recentSearches.isEmpty)
        ["하나", "둘", "셋", "넷", "다섯", "여섯", "  셋  "].forEach(store.recordSearch)
        store.recordSearch("   ")

        XCTAssertEqual(store.recentSearches, ["셋", "여섯", "다섯", "넷", "둘"])

        let reloaded = AppStore(fileURL: dataURL, userDefaults: defaults)
        XCTAssertEqual(reloaded.recentSearches, store.recentSearches)
    }

    func testDefaultTagFiltersAndSearchUseClipTags() {
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        XCTAssertEqual(store.filteredClips(.interior).map(\.id), [1])
        XCTAssertEqual(store.filteredClips(.reference).map(\.id), [2])
        XCTAssertEqual(store.filteredClips(.idea).map(\.id), [3])
        XCTAssertEqual(store.filteredClips(.travel).map(\.id), [4])
        XCTAssertEqual(store.searchResults(query: "대시보드", filter: "레퍼런스").map(\.id), [2])
        XCTAssertEqual(store.searchResults(query: "아이디어", filter: "태그").map(\.id), [3])
    }

    func testPrimaryMutationsPersistAcrossReload() throws {
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        store.toggleBookmark(id: 1)
        store.moveClip(id: 1, to: "업무")
        store.updateMemo(id: 1, memo: "다시 확인할 메모")
        _ = try store.createFolder(name: "읽을거리", defaultTag: "읽을거리")
        let added = store.saveNewClip(destination: "업무", tags: ["읽을거리"], memo: "새 메모")
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
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)
        let original = try XCTUnwrap(store.clip(id: 1)?.tags)

        store.updateTags(id: 1, tags: original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dataURL.path))

        store.updateTags(id: 1, tags: ["  독서 ", "", "여행"])
        XCTAssertEqual(store.clip(id: 1)?.tags, ["독서", "여행"])

        let reloaded = AppStore(fileURL: dataURL, userDefaults: defaults)
        XCTAssertEqual(reloaded.clip(id: 1)?.tags, ["독서", "여행"])
    }

    func testDefaultFoldersCanBeRenamedAndReferencesPersist() throws {
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

    func testFolderRenameRejectsDuplicateNamesWithoutChangingData() {
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)

        XCTAssertThrowsError(try store.renameFolder(from: "기본 폴더", to: "폴더 1"))
        XCTAssertTrue(store.folders.contains { $0.label == "기본 폴더" })
        XCTAssertEqual(store.clip(id: 5)?.folder, "폴더 1")
    }

    func testTagCatalogRenameAndDeleteUpdateEveryReference() throws {
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
}
