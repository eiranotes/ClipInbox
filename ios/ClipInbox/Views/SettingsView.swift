import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum AppExternalLinks {
    static let privacyPolicy = URL(string: "https://shrouded-fennel-dd8.notion.site/Clip-Inbox-Privacy-Policy-39bb714ca5c680cc86cfd6dbd697bbc3")!
    static let support = URL(string: "https://shrouded-fennel-dd8.notion.site/Clip-Inbox-Support-39bb714ca5c6805bbfb9f4dacaf411d4")!
    static let termsOfUse = URL(string: "https://shrouded-fennel-dd8.notion.site/Clip-Inbox-Terms-of-Use-39bb714ca5c68000bcd3c412afcdb006")!
}

enum AppBuildInfo {
    static var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
}

enum SettingKey: String, Hashable, CaseIterable {
    case appLock = "app-lock"
    case theme
    case language
    case defaultFolder = "default-folder"
    case folders
    case tags
    case shareMode = "share-mode"
    case linkOpening = "link-opening"
    case storage
    case backup
    case importData = "import"
    case about
    case contact

    var title: String {
        switch self {
        case .appLock: return "앱 잠금"
        case .theme: return "테마"
        case .language: return "언어"
        case .defaultFolder: return "기본 폴더"
        case .folders: return "폴더 관리"
        case .tags: return "태그 관리"
        case .shareMode: return "공유 저장 방식"
        case .linkOpening: return "링크 열기 방식"
        case .storage: return "저장 공간"
        case .backup: return "백업 및 내보내기"
        case .importData: return "가져오기"
        case .about: return "앱 정보"
        case .contact: return "문의하기"
        }
    }

    var systemImage: String {
        switch self {
        case .appLock: return "lock"
        case .theme: return "paintpalette"
        case .language: return "character.bubble"
        case .defaultFolder: return "folder"
        case .folders: return "folder.badge.gearshape"
        case .tags: return "tag"
        case .shareMode: return "square.and.arrow.down"
        case .linkOpening: return "safari"
        case .storage: return "internaldrive"
        case .backup: return "square.and.arrow.up"
        case .importData: return "square.and.arrow.down"
        case .about: return "info.circle"
        case .contact: return "questionmark.circle"
        }
    }
}

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(URLMetadataCoordinator.self) private var metadata
    @Environment(\.locale) private var locale
    @State private var showDeleteConfirm = false
    @State private var isDeletingAllData = false

    var body: some View {
        ScreenScaffold(spacing: Tokens.formSectionGap,
                       additionalBottomPadding: Tokens.bottomNavigationClearance) {
            ScreenHeader("설정")

            settingsGroup([
                (.appLock, store.preferences.appLock),
                (.theme, store.preferences.theme),
                (.language, store.preferences.language),
                (.defaultFolder, store.preferences.defaultFolder),
                (.folders, "\(store.destinationFolders.count)"),
                (.tags, "\(store.availableTags.count)"),
                (.shareMode, shareModeLabel(store.preferences.sharedSaveMode)),
                (.linkOpening, linkOpenModeLabel(store.linkOpenMode))
            ])

            sectionHeading("데이터")
            settingsGroup([
                (.storage, ""),
                (.backup, "JSON"),
                (.importData, "JSON")
            ])

            sectionHeading("기타")
            otherSettingsGroup

            Button {
                showDeleteConfirm = true
            } label: {
                Text(isDeletingAllData ? "삭제 중…" : "모든 데이터 삭제")
            }
            .buttonStyle(SecondaryBoxButtonStyle(isDanger: true))
            .disabled(isDeletingAllData)

        }
        .alert("모든 데이터 삭제", isPresented: $showDeleteConfirm) {
            Button("삭제 확인", role: .destructive) {
                isDeletingAllData = true
                Task { @MainActor in
                    _ = await store.deleteAllData(metadata: metadata)
                    isDeletingAllData = false
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("클립, 폴더, 설정, 원본 첨부 파일, 검색 기록, 공유 대기 항목과 복구 사본을 모두 삭제합니다. 이 작업은 되돌릴 수 없습니다.")
        }
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(L10n.text(title, locale: locale))
            .font(Tokens.sectionTitle)
            .foregroundStyle(Tokens.textPrimary)
    }

    private func settingsGroup(_ rows: [(key: SettingKey, value: String)]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.key) { index, row in
                NavigationLink(value: Route.settingDetail(row.key)) {
                    DestinationRow(systemImage: row.key.systemImage,
                                   title: row.key.title,
                                   value: row.value)
                }
                .buttonStyle(ResponsivePressButtonStyle())
                if index < rows.count - 1 {
                    RowDivider()
                }
            }
        }
    }

    private var otherSettingsGroup: some View {
        VStack(spacing: 0) {
            NavigationLink {
                OnboardingView(isFirstRun: false, onComplete: nil)
                    .toolbar(.hidden, for: .navigationBar)
            } label: {
                DestinationRow(systemImage: "rectangle.portrait.and.arrow.right",
                               title: "공유 저장 가이드")
            }
            .buttonStyle(ResponsivePressButtonStyle())
            RowDivider()
            settingsGroup([
                (.about, AppBuildInfo.marketingVersion),
                (.contact, "")
            ])
            RowDivider()
            externalLinkRow(systemImage: "lifepreserver",
                            title: "고객지원",
                            destination: AppExternalLinks.support)
            RowDivider()
            externalLinkRow(systemImage: "hand.raised",
                            title: "개인정보 처리방침",
                            destination: AppExternalLinks.privacyPolicy)
            RowDivider()
            externalLinkRow(systemImage: "doc.text",
                            title: "이용약관",
                            destination: AppExternalLinks.termsOfUse)
        }
    }

    private func externalLinkRow(systemImage: String, title: String, destination: URL) -> some View {
        Link(destination: destination) {
            DestinationRow(systemImage: systemImage,
                           title: title,
                           trailingSystemImage: "arrow.up.right")
        }
        .buttonStyle(ResponsivePressButtonStyle())
    }
}

// MARK: - 설정 상세

struct JSONBackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct SettingDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppLockController.self) private var lock
    @Environment(\.dismiss) private var dismiss
    let key: SettingKey

    @State private var pending = ""
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportDocument: JSONBackupDocument?
    @State private var errorMessage: String?
    @State private var newTag = ""
    @State private var editingTag: TagEditTarget?
    @State private var deletingTag: String?
    @State private var newFolder = ""
    @State private var editingFolder: FolderEditTarget?
    @State private var deletingFolder: String?
    @State private var storageSummary: AppStorageSummary?

    var body: some View {
        ScreenScaffold {
            ScreenHeader(key.title, onBack: { dismiss() })

            Color.clear.frame(height: detailTopInset)

            controls

            if let errorMessage {
                Text(errorMessage)
                    .font(Tokens.metaBold)
                    .foregroundStyle(Tokens.danger)
            }
        }
        .onAppear {
            pending = currentValue
            if key == .storage { loadStorageSummary() }
        }
        .fileExporter(isPresented: $showExporter,
                      document: exportDocument,
                      contentType: .json,
                      defaultFilename: "clip-inbox-backup") { result in
            if case .success = result {
                store.showToast("JSON 백업을 저장했습니다")
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .sheet(item: $editingTag) { target in
            RenameTagSheet(originalTag: target.tag)
                .workflowSheet(.compact)
        }
        .sheet(item: $editingFolder) { target in
            RenameFolderSheet(originalLabel: target.label) { _ in }
                .workflowSheet(.compact)
        }
        .alert("태그 삭제", isPresented: Binding(
            get: { deletingTag != nil },
            set: { if !$0 { deletingTag = nil } }
        )) {
            Button("삭제 확인", role: .destructive) {
                if let deletingTag { store.deleteTag(deletingTag) }
                deletingTag = nil
            }
            Button("취소", role: .cancel) { deletingTag = nil }
        } message: {
            Text("이 태그는 모든 클립과 폴더 기본 태그에서 제거됩니다.")
        }
        .alert("폴더 삭제", isPresented: Binding(
            get: { deletingFolder != nil },
            set: { if !$0 { deletingFolder = nil } }
        )) {
            Button("삭제 확인", role: .destructive) {
                guard let deletingFolder else { return }
                do {
                    try store.deleteFolder(deletingFolder)
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
                self.deletingFolder = nil
            }
            Button("취소", role: .cancel) { deletingFolder = nil }
        } message: {
            Text("이 폴더의 클립은 인박스로 이동하고 미정리 상태가 됩니다.")
        }
    }

    private var options: [String] {
        switch key {
        case .appLock: return ["켬", "끔"]
        case .theme: return ["라이트", "다크", "시스템 설정"]
        case .language: return AppLanguage.allCases.map(\.rawValue)
        case .defaultFolder: return store.destinationFolders.map(\.label)
        case .shareMode: return SharedSaveMode.allCases.map(\.rawValue)
        case .linkOpening: return LinkOpenMode.allCases.map(\.rawValue)
        default: return []
        }
    }

    private var currentValue: String {
        switch key {
        case .appLock: return store.preferences.appLock
        case .theme: return store.preferences.theme
        case .language: return store.preferences.language
        case .defaultFolder: return store.preferences.defaultFolder
        case .shareMode: return store.preferences.shareMode
        case .linkOpening: return store.linkOpenMode.rawValue
        default: return ""
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch key {
        case .appLock, .theme, .language, .defaultFolder, .shareMode, .linkOpening:
            BoardSection(title: "옵션") {
                VStack(spacing: Tokens.rowGap) {
                    ForEach(options, id: \.self) { option in
                        ActionRow(systemImage: key.systemImage, label: optionLabel(option),
                                  isSelected: pending == option) {
                            pending = option
                        }
                    }
                }
            }
            Button {
                if savePreference() { dismiss() }
            } label: {
                Label("설정 저장", systemImage: "checkmark")
            }
            .buttonStyle(PrimaryBoxButtonStyle())

        case .folders:
            BoardSection(title: "새 폴더") {
                HStack(spacing: Tokens.rowGap) {
                    TextField("폴더 이름", text: $newFolder)
                        .font(Tokens.body)
                        .padding(.horizontal, Tokens.cardPad)
                        .frame(minHeight: Tokens.actionTarget)
                        .tokenSurface(radius: Tokens.radiusInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit(addFolder)
                    Button(action: addFolder) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Tokens.onAccent)
                            .frame(width: Tokens.actionTarget, height: Tokens.actionTarget)
                            .tokenSurface(fill: Tokens.accentYellow, radius: Tokens.radiusButton)
                    }
                    .buttonStyle(ResponsivePressButtonStyle())
                    .accessibilityLabel("폴더 추가")
                }
            }

            BoardSection(title: "폴더 목록", count: store.destinationFolders.count) {
                VStack(spacing: 0) {
                    ForEach(Array(store.destinationFolders.enumerated()), id: \.element.id) { index, folder in
                        HStack(spacing: Tokens.rowGap) {
                            Image(systemName: folder.systemImage)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Tokens.textSecondary)
                                .frame(width: Tokens.iconColumn)
                            Text(L10n.text(folder.label))
                                .font(Tokens.bodySemibold)
                                .foregroundStyle(Tokens.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: Tokens.rowGap)
                            UtilityIconButton(label: "폴더 이름 편집", systemImage: "pencil") {
                                editingFolder = FolderEditTarget(label: folder.label)
                            }
                            if folder.icon != "inbox" {
                                Button {
                                    deletingFolder = folder.label
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Tokens.danger)
                                        .frame(width: Tokens.touchTarget, height: Tokens.touchTarget)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(ResponsivePressButtonStyle())
                                .accessibilityLabel(L10n.text("폴더 삭제"))
                            } else {
                                Color.clear
                                    .frame(width: Tokens.touchTarget, height: Tokens.touchTarget)
                                    .accessibilityHidden(true)
                            }
                        }
                        .frame(minHeight: Tokens.actionTarget)
                        if index < store.destinationFolders.count - 1 {
                            RowDivider()
                        }
                    }
                }
            }

        case .tags:
            BoardSection(title: "새 태그") {
                HStack(spacing: Tokens.rowGap) {
                    TextField("태그 이름", text: $newTag)
                        .font(Tokens.body)
                        .padding(.horizontal, Tokens.cardPad)
                        .frame(minHeight: Tokens.actionTarget)
                        .tokenSurface(radius: Tokens.radiusInput)
                        .onSubmit(addTag)
                    Button(action: addTag) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Tokens.onAccent)
                            .frame(width: Tokens.actionTarget, height: Tokens.actionTarget)
                            .tokenSurface(fill: Tokens.accentYellow, radius: Tokens.radiusButton)
                    }
                    .buttonStyle(ResponsivePressButtonStyle())
                    .accessibilityLabel("태그 추가")
                }
            }

            BoardSection(title: "태그 목록", count: store.availableTags.count) {
                VStack(spacing: 0) {
                    ForEach(Array(store.availableTags.enumerated()), id: \.element) { index, tag in
                        HStack(spacing: Tokens.rowGap) {
                            Image(systemName: "tag")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Tokens.textSecondary)
                                .frame(width: Tokens.iconColumn)
                            Text(tag)
                                .font(Tokens.bodySemibold)
                                .foregroundStyle(Tokens.textPrimary)
                            Spacer(minLength: Tokens.rowGap)
                            UtilityIconButton(label: "태그 이름 편집", systemImage: "pencil") {
                                editingTag = TagEditTarget(tag: tag)
                            }
                            Button {
                                deletingTag = tag
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Tokens.danger)
                                    .frame(width: Tokens.touchTarget, height: Tokens.touchTarget)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(ResponsivePressButtonStyle())
                            .accessibilityLabel(L10n.text("태그 삭제"))
                        }
                        .frame(minHeight: Tokens.actionTarget)
                        if index < store.availableTags.count - 1 {
                            RowDivider()
                        }
                    }
                }
            }

        case .backup:
            BoardSection(title: "내보낼 항목", count: store.clips.count) {
                Text(L10n.format("format.backup_summary", store.clips.count,
                                 max(store.folders.count - 1, 0)))
                    .font(Tokens.body)
                    .foregroundStyle(Tokens.textPrimary)
                    .lineSpacing(Tokens.bodyLineSpacing)
            }
            StatePanel(
                systemImage: "exclamationmark.shield",
                title: "평문 JSON 백업",
                message: "클립, 폴더와 현재 설정만 포함합니다. 원본 첨부 파일, 최근 검색, 태그 카탈로그와 링크 열기 설정은 포함하지 않으며 선택한 파일 위치에 암호화되지 않은 사본이 남습니다."
            )
            Button {
                do {
                    exportDocument = JSONBackupDocument(data: try store.exportJSON())
                    showExporter = true
                } catch {
                    errorMessage = "백업 파일을 만들지 못했습니다."
                }
            } label: {
                Label("JSON 내보내기", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(PrimaryBoxButtonStyle())

        case .storage:
            if let storageSummary {
                BoardSection(title: "기기 저장 공간") {
                    VStack(spacing: 0) {
                        storageRow("클립 데이터", value: byteText(storageSummary.snapshotBytes))
                        storageRow("원본 첨부 파일", value: L10n.format(
                            "format.storage_images",
                            storageSummary.originalAttachmentCount,
                            byteText(storageSummary.originalAttachmentBytes)
                        ))
                        storageRow("가져오기 대기", value: L10n.format(
                            "format.storage_pending",
                            storageSummary.pendingCount,
                            byteText(storageSummary.pendingBytes)
                        ))
                        storageRow("격리된 항목", value: "\(storageSummary.quarantinedCount)")
                    }
                }
                StatePanel(
                    systemImage: "info.circle",
                    title: "원본 보존 정책",
                    message: "이미지와 파일은 원본 형식과 바이트를 유지합니다. 삭제한 클립은 휴지통에서 복원할 수 있으며 30일 후 원본 첨부 파일과 함께 자동 삭제됩니다."
                )
            } else if let errorMessage {
                StatePanel(systemImage: "externaldrive.badge.exclamationmark",
                           title: "저장 공간을 확인할 수 없습니다", message: errorMessage, isDanger: true)
            }

        case .importData:
            BoardSection(title: "백업 파일") {
                Text("Clip Inbox 백업 JSON만 지원합니다. 클립, 폴더와 백업에 포함된 설정은 백업 내용으로 대체됩니다. 최근 검색, 링크 열기 방식, 태그 카탈로그와 저장된 원본 첨부 파일은 유지됩니다. 원본 첨부 파일은 백업에 포함되지 않습니다.")
                    .font(Tokens.body)
                    .foregroundStyle(Tokens.textPrimary)
                    .lineSpacing(Tokens.bodyLineSpacing)
            }
            Button {
                showImporter = true
            } label: {
                Label("JSON 파일 선택", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(PrimaryBoxButtonStyle())

        case .about:
            BoardSection(title: "버전") {
                VStack(alignment: .leading, spacing: Tokens.rowGap) {
                    Text("Clip Inbox · \(AppBuildInfo.marketingVersion)")
                    Text("저장 위치 · 이 기기의 앱 데이터 폴더")
                }
                .font(Tokens.body)
                .foregroundStyle(Tokens.textPrimary)
            }

        case .contact:
            Button {
                UIPasteboard.general.string = "eiradev000@gmail.com"
                store.showToast("문의 이메일을 복사했습니다")
            } label: {
                Label("문의 이메일 복사", systemImage: "questionmark.circle")
            }
            .buttonStyle(PrimaryBoxButtonStyle())
        }
    }

    @discardableResult
    private func savePreference() -> Bool {
        if key == .appLock, pending == "켬", !lock.canEnableLock() {
            errorMessage = L10n.text("이 기기에서 앱 잠금을 사용할 수 없습니다. 기기 암호를 먼저 설정하세요.")
            return false
        }
        let saved: Bool
        switch key {
        case .appLock: saved = store.updatePreference(key: .appLock, value: pending)
        case .theme: saved = store.updatePreference(key: .theme, value: pending)
        case .language: saved = store.updatePreference(key: .language, value: pending)
        case .defaultFolder: saved = store.updatePreference(key: .defaultFolder, value: pending)
        case .shareMode: saved = store.updatePreference(key: .shareMode, value: pending)
        case .linkOpening:
            store.updateLinkOpenMode(LinkOpenMode(rawValue: pending) ?? .direct)
            saved = true
        default: saved = false
        }
        if !saved { errorMessage = store.storageErrorMessage }
        return saved
    }

    private var detailTopInset: CGFloat {
        switch key {
        case .defaultFolder, .folders, .tags: return 0
        case .appLock, .theme, .language, .shareMode, .linkOpening:
            return Tokens.settingChoiceTop
        case .storage: return 0
        default: return Tokens.settingActionTop
        }
    }

    private func addTag() {
        do {
            _ = try store.addTag(newTag)
            newTag = ""
            errorMessage = nil
            Keyboard.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addFolder() {
        do {
            _ = try store.createFolder(name: newFolder, defaultTag: "")
            newFolder = ""
            errorMessage = nil
            Keyboard.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadStorageSummary() {
        do {
            storageSummary = try store.storageSummary()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func byteText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func storageRow(_ label: String, value: String) -> some View {
        HStack(spacing: Tokens.cardGap) {
            Text(L10n.text(label))
                .font(Tokens.bodySemibold)
            Spacer(minLength: Tokens.rowGap)
            Text(value)
                .font(Tokens.meta)
                .foregroundStyle(Tokens.textSecondary)
        }
        .foregroundStyle(Tokens.textPrimary)
        .frame(minHeight: Tokens.actionTarget)
        .overlay(alignment: .bottom) {
            Tokens.borderSoft.frame(height: Tokens.borderChipWidth)
        }
    }

    private func optionLabel(_ option: String) -> String {
        switch key {
        case .shareMode: return shareModeLabel(SharedSaveMode(rawValue: option) ?? .quick)
        case .linkOpening: return linkOpenModeLabel(LinkOpenMode(rawValue: option) ?? .direct)
        default: return option
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case let .success(url) = result else { return }
        do {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            try store.importJSON(data)
            store.showToast("백업을 가져왔습니다")
            dismiss()
        } catch {
            errorMessage = (error as? StoreError)?.localizedDescription ?? "백업을 가져오지 못했습니다."
        }
    }
}

private struct TagEditTarget: Identifiable {
    let tag: String
    var id: String { tag }
}

private struct FolderEditTarget: Identifiable {
    let label: String
    var id: String { label }
}

private struct RenameTagSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let originalTag: String
    @State private var name: String
    @State private var errorMessage: String?

    init(originalTag: String) {
        self.originalTag = originalTag
        _name = State(initialValue: originalTag)
    }

    var body: some View {
        ScreenScaffold {
            ScreenHeader("태그 이름 편집", onBack: { dismiss() })
            BoardSection(title: "태그 이름") {
                TextField("태그 이름", text: $name)
                    .font(Tokens.body)
                    .padding(.horizontal, Tokens.cardPad)
                    .frame(minHeight: Tokens.actionTarget)
                    .tokenSurface(radius: Tokens.radiusInput)
                    .onSubmit(rename)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(Tokens.metaBold)
                    .foregroundStyle(Tokens.danger)
            }
            Button(action: rename) {
                Label("이름 저장", systemImage: "checkmark")
            }
            .buttonStyle(PrimaryBoxButtonStyle())
        }
    }

    private func rename() {
        do {
            try store.renameTag(from: originalTag, to: name)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private func shareModeLabel(_ mode: SharedSaveMode) -> String {
    switch mode {
    case .quick: return "바로 저장"
    case .review: return "폴더·메모 확인 후 저장"
    }
}

private func linkOpenModeLabel(_ mode: LinkOpenMode) -> String {
    switch mode {
    case .direct: return "바로 열기"
    case .confirm: return "열기 전 확인"
    }
}
