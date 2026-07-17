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

    func testShareQueueBatchEnqueuesAndImportsEverySelectedImage() throws {
        let container = temporaryDirectory.appendingPathComponent("BatchImageQueue", isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.systemYellow.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let asset = try XCTUnwrap(SharedImageAsset(data: try XCTUnwrap(image.pngData())))
        let createdAt = Date()
        let payloads = try (0..<3).map { index in
            let id = UUID()
            let imageName = try SharedClipQueue.storeImageAsset(asset, for: id, containerURL: container)
            return SharedClipPayload(
                id: id,
                type: .image,
                title: "Shared image \(index + 1)",
                source: "Photos",
                sharedImageName: imageName,
                createdAt: createdAt.addingTimeInterval(Double(index) / 1_000)
            )
        }

        try SharedClipQueue.enqueue(payloads, containerURL: container)

        let queued = try SharedClipQueue.pendingItems(containerURL: container)
        XCTAssertEqual(queued.map(\.payload.id), payloads.map(\.id))
        XCTAssertEqual(queued.compactMap(\.payload.sharedImageName).count, 3)

        let store = AppStore(fileURL: dataURL, userDefaults: defaults)
        store.importSharedClips(containerURL: container)

        XCTAssertEqual(Set(store.clips.compactMap(\.sharePayloadID)), Set(payloads.map(\.id)))
        XCTAssertEqual(store.clips.filter { $0.type == .image }.count, 3)
        XCTAssertTrue(try SharedClipQueue.pendingItems(containerURL: container).isEmpty)
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
        let payload = SharedClipPayload(type: .text, title: "pending", source: "test", text: "pending")
        try SharedClipQueue.enqueue(payload, containerURL: container)
        let pendingDirectory = container.appendingPathComponent("PendingClips", isDirectory: true)
        try Data("broken".utf8).write(to: pendingDirectory.appendingPathComponent("broken.json"))

        let shared = try SharedClipQueue.storageSummary(containerURL: container)
        let store = AppStore(fileURL: dataURL, userDefaults: defaults)
        let app = try store.storageSummary(containerURL: container)

        XCTAssertEqual(shared.originalImageCount, 1)
        XCTAssertGreaterThan(shared.originalImageBytes, 0)
        XCTAssertEqual(shared.pendingCount, 1)
        XCTAssertGreaterThan(shared.pendingPayloadBytes, 0)
        XCTAssertEqual(shared.quarantinedCount, 1)
        XCTAssertGreaterThan(app.snapshotBytes, 0)
        XCTAssertEqual(app.originalImageCount, shared.originalImageCount)
    }
}
