import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum SettingKey: String, Hashable, CaseIterable {
    case appLock = "app-lock"
    case theme
    case language
    case defaultFolder = "default-folder"
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
        case .backup: return "백업 및 내보내기"
        case .importData: return "가져오기"
        case .about: return "앱 정보"
        case .contact: return "문의하기"
        }
    }

    var summary: String {
        switch self {
        case .appLock: return "앱을 열 때 Face ID 또는 기기 암호 인증을 요구합니다."
        case .theme: return "선택값은 로컬 설정에 저장되며 현재 화면 토큰은 라이트를 유지합니다."
        case .language: return "앱 표시 언어를 선택합니다."
        case .defaultFolder: return "공유 시트에서 저장 버튼을 누르면 먼저 들어갈 폴더입니다."
        case .backup: return "클립, 태그, 폴더, 설정을 JSON 파일로 내보냅니다."
        case .importData: return "Clip Inbox에서 내보낸 JSON 백업을 검증한 뒤 현재 로컬 데이터로 복원합니다."
        case .about: return "Clip Inbox 0.3.0 SwiftUI 네이티브 빌드입니다."
        case .contact: return "문제 상황과 저장하려던 URL을 함께 남길 수 있도록 문의 이메일을 복사합니다."
        }
    }

    var systemImage: String {
        switch self {
        case .appLock: return "lock"
        case .theme: return "paintpalette"
        case .language: return "character.bubble"
        case .defaultFolder: return "folder"
        case .backup: return "square.and.arrow.up"
        case .importData: return "square.and.arrow.down"
        case .about: return "info.circle"
        case .contact: return "questionmark.circle"
        }
    }
}

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var showDeleteConfirm = false

    var body: some View {
        ScreenScaffold {
            ScreenHeader("설정")

            settingsGroup([
                (.appLock, store.preferences.appLock),
                (.theme, store.preferences.theme),
                (.language, store.preferences.language),
                (.defaultFolder, store.preferences.defaultFolder)
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
        Text(title)
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

    var body: some View {
        ScreenScaffold {
            ScreenHeader(key.title, onBack: { dismiss() })

            BoardSection(title: "설정 설명") {
                StatePanel(systemImage: key.systemImage, title: key.title, message: key.summary)
            }

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
    }

    private var options: [String] {
        switch key {
        case .appLock: return ["켬", "끔"]
        case .theme: return ["라이트", "시스템 설정"]
        case .language: return ["한국어", "English"]
        case .defaultFolder: return store.destinationFolders.map(\.label)
        default: return []
        }
    }

    private var currentValue: String {
        switch key {
        case .appLock: return store.preferences.appLock
        case .theme: return store.preferences.theme
        case .language: return store.preferences.language
        case .defaultFolder: return store.preferences.defaultFolder
        default: return ""
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch key {
        case .appLock, .theme, .language, .defaultFolder:
            BoardSection(title: "옵션") {
                VStack(spacing: Tokens.rowGap) {
                    ForEach(options, id: \.self) { option in
                        ActionRow(systemImage: key.systemImage, label: option,
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

        case .backup:
            BoardSection(title: "내보낼 항목", count: store.clips.count) {
                Text("클립 \(store.clips.count)개와 폴더 \(max(store.folders.count - 1, 0))개, 현재 설정을 하나의 JSON 파일로 저장합니다.")
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
        default: break
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
