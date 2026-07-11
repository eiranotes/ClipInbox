import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum SettingKey: String, Hashable, CaseIterable {
    case appLock = "app-lock"
    case theme
    case language
    case defaultFolder = "default-folder"
    case tags
    case shareMode = "share-mode"
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
        case .tags: return "태그 관리"
        case .shareMode: return "공유 저장 방식"
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
        case .tags: return "tag"
        case .shareMode: return "square.and.arrow.down"
        case .backup: return "square.and.arrow.up"
        case .importData: return "square.and.arrow.down"
        case .about: return "info.circle"
        case .contact: return "questionmark.circle"
        }
    }
}

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.locale) private var locale
    @State private var showDeleteConfirm = false

    var body: some View {
        ScreenScaffold {
            ScreenHeader("설정")

            settingsGroup([
                (.appLock, store.preferences.appLock),
                (.theme, store.preferences.theme),
                (.language, store.preferences.language),
                (.defaultFolder, store.preferences.defaultFolder),
                (.tags, "\(store.availableTags.count)"),
                (.shareMode, shareModeLabel(store.preferences.sharedSaveMode))
            ])

            sectionHeading("데이터")
            settingsGroup([
                (.backup, "JSON"),
                (.importData, "JSON")
            ])

            sectionHeading("기타")
            settingsGroup([
                (.about, "0.3.0"),
                (.contact, "")
            ])

            Button {
                showDeleteConfirm = true
            } label: {
                Text("모든 데이터 삭제")
            }
            .buttonStyle(SecondaryBoxButtonStyle(isDanger: true))

            Spacer(minLength: Tokens.bottomSafe - Tokens.sectionGap * 2)
        }
        .alert("모든 데이터 삭제", isPresented: $showDeleteConfirm) {
            Button("삭제 확인", role: .destructive) {
                store.deleteAllData()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("로컬에 저장된 클립, 폴더, 설정을 기본값으로 되돌립니다.")
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
                .buttonStyle(.plain)
                if index < rows.count - 1 {
                    RowDivider()
                }
            }
        }
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
        .onAppear { pending = currentValue }
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
    }

    private var options: [String] {
        switch key {
        case .appLock: return ["켬", "끔"]
        case .theme: return ["라이트", "다크", "시스템 설정"]
        case .language: return AppLanguage.allCases.map(\.rawValue)
        case .defaultFolder: return store.destinationFolders.map(\.label)
        case .shareMode: return SharedSaveMode.allCases.map(\.rawValue)
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
        default: return ""
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch key {
        case .appLock, .theme, .language, .defaultFolder, .shareMode:
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
                savePreference()
                dismiss()
            } label: {
                Label("설정 저장", systemImage: "checkmark")
            }
            .buttonStyle(PrimaryBoxButtonStyle())

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
                            .foregroundStyle(Tokens.textPrimary)
                            .frame(width: Tokens.actionTarget, height: Tokens.actionTarget)
                            .tokenSurface(fill: Tokens.accentYellow, radius: Tokens.radiusButton)
                    }
                    .buttonStyle(.plain)
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
                            .buttonStyle(.plain)
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

        case .importData:
            BoardSection(title: "백업 파일") {
                Text("Clip Inbox 백업 JSON만 지원합니다. 가져오면 현재 로컬 데이터를 대체합니다.")
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
                    Text("Clip Inbox · 0.3.0")
                    Text("저장 위치 · 이 기기의 앱 데이터 폴더")
                }
                .font(Tokens.body)
                .foregroundStyle(Tokens.textPrimary)
            }

        case .contact:
            Button {
                UIPasteboard.general.string = "support@clipinbox.local"
                store.showToast("문의 이메일을 복사했습니다")
            } label: {
                Label("문의 이메일 복사", systemImage: "questionmark.circle")
            }
            .buttonStyle(PrimaryBoxButtonStyle())
        }
    }

    private func savePreference() {
        switch key {
        case .appLock: store.updatePreference(key: .appLock, value: pending)
        case .theme: store.updatePreference(key: .theme, value: pending)
        case .language: store.updatePreference(key: .language, value: pending)
        case .defaultFolder: store.updatePreference(key: .defaultFolder, value: pending)
        case .shareMode: store.updatePreference(key: .shareMode, value: pending)
        default: break
        }
    }

    private var detailTopInset: CGFloat {
        switch key {
        case .defaultFolder, .tags: return 0
        case .appLock, .theme, .language, .shareMode: return Tokens.settingChoiceTop
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

    private func optionLabel(_ option: String) -> String {
        guard key == .shareMode else { return option }
        return shareModeLabel(SharedSaveMode(rawValue: option) ?? .quick)
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
