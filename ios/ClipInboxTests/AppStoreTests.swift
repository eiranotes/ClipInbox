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
}
