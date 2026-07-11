import SwiftUI
import PhotosUI

/// 공유 시트를 쓰기 어려운 상황을 위한 실제 수동 캡처 폼.
struct AddClipView: View {
    @Environment(AppStore.self) private var store

    @State private var type: ManualCaptureType = .link
    @State private var title = ""
    @State private var url = ""
    @State private var text = ""
    @State private var destination = ""
    @State private var tags: [String] = []
    @State private var memo = ""
    @State private var saved = false
    @State private var saveError: String?
    @State private var isSaving = false
    @State private var showDestination = false
    @State private var showTagEditor = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photoAsset: SharedImageAsset?
    @State private var photoStatus: String?

    private var duplicate: Clip? {
        type == .link ? store.existingClip(forManualURL: url) : nil
    }

    var body: some View {
        ScreenScaffold {
            ScreenHeader("추가")

            BoardSection(title: "클립 유형") {
                TwoRowHorizontalSelection(items: ManualCaptureType.allCases.map { option in
                    (label: option.label, active: type == option, action: {
                        type = option
                        saved = false
                        saveError = nil
                    })
                })
            }

            BoardSection(title: "제목 (선택)") {
                TextField("비워 두면 내용에서 자동으로 만듭니다", text: $title)
                    .font(Tokens.body)
                    .padding(.horizontal, Tokens.cardPad)
                    .frame(minHeight: Tokens.actionTarget)
                    .tokenSurface(radius: Tokens.radiusInput)
            }

            captureFields

            if let duplicate {
                StatePanel(
                    systemImage: "doc.on.doc",
                    title: "이미 저장된 링크입니다",
                    message: L10n.format("format.duplicate_clip_location", duplicate.folder)
                )
            }

            BoardSection(title: "저장 위치") {
                Button {
                    showDestination = true
                } label: {
                    HStack(spacing: Tokens.rowGap + 4) {
                        Image(systemName: "tray")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Tokens.textPrimary)
                            .frame(width: Tokens.destinationIcon, height: Tokens.destinationIcon)
                            .tokenSurface(fill: Tokens.accentYellow, radius: Tokens.radiusButton)
                        Text(destination)
                            .font(Tokens.bodyBold)
                            .foregroundStyle(Tokens.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Tokens.textSecondary)
                    }
                    .padding(.horizontal, Tokens.cardPad)
                    .frame(minHeight: Tokens.actionTarget)
                    .tokenSurface(radius: Tokens.radiusInput)
                }
                .buttonStyle(.plain)
            }

            BoardSection(title: "태그") {
                ActionRow(systemImage: "tag", label: "선택한 태그",
                          value: tags.isEmpty ? "없음" : tags.joined(separator: " · ")) {
                    showTagEditor = true
                }
            }

            if type != .memo {
                BoardSection(title: "메모 (선택)") {
                TextEditor(text: $memo)
                    .font(Tokens.body)
                    .lineSpacing(Tokens.bodyLineSpacing)
                    .scrollContentBackground(.hidden)
                    .padding(Tokens.rowGap)
                    .frame(minHeight: 100)
                    .tokenSurface(radius: Tokens.radiusInput)
                    .overlay(alignment: .topLeading) {
                        if memo.isEmpty {
                            Text("보관 이유나 다음 할 일을 적어 두세요")
                                .font(Tokens.body)
                                .foregroundStyle(Tokens.textTertiary)
                                .padding(.top, Tokens.rowGap + 8)
                                .padding(.leading, Tokens.rowGap + 5)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }

            Button {
                saveClip()
            } label: {
                if isSaving {
                    ProgressView().tint(Tokens.textPrimary)
                } else {
                    Text(saved
                         ? L10n.format("format.saved_in_folder", L10n.text(destination))
                         : duplicate == nil
                            ? L10n.format("format.save_to_folder", L10n.text(destination))
                            : "별도로 저장")
                }
            }
            .buttonStyle(PrimaryBoxButtonStyle())
            .disabled(saved || isSaving)
            .opacity(saved || isSaving ? 0.5 : 1)

            if let saveError {
                StatePanel(systemImage: "externaldrive.badge.exclamationmark",
                           title: "저장할 수 없습니다", message: saveError, isDanger: true)
            }

            if saved {
                Button {
                    resetDraft()
                } label: {
                    Text("새로 저장하기")
                }
                .buttonStyle(SecondaryBoxButtonStyle())
            }

            Spacer(minLength: Tokens.bottomSafe - Tokens.sectionGap * 2)
        }
        .onAppear {
            if destination.isEmpty { destination = store.preferences.defaultFolder }
        }
        .sheet(isPresented: $showDestination) {
            DestinationSheet(destination: $destination).workflowSheet(.expanded)
        }
        .sheet(isPresented: $showTagEditor) {
            TagEditorSheet(tags: $tags).workflowSheet(.standard)
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
    }

    @ViewBuilder
    private var captureFields: some View {
        switch type {
        case .link:
            BoardSection(title: "URL") {
                TextField("https://example.com", text: $url)
                    .font(Tokens.body)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .padding(.horizontal, Tokens.cardPad)
                    .frame(minHeight: Tokens.actionTarget)
                    .tokenSurface(radius: Tokens.radiusInput)
            }
        case .text, .memo:
            BoardSection(title: type == .memo ? "메모 내용" : "텍스트") {
                contentEditor(placeholder: type == .memo
                              ? "기억해 둘 내용을 입력하세요"
                              : "저장할 텍스트를 입력하세요")
            }
        case .photo:
            BoardSection(title: "사진") {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(photoAsset == nil ? "사진 선택" : "다른 사진 선택", systemImage: "photo")
                        .frame(maxWidth: .infinity, minHeight: Tokens.actionTarget)
                }
                .buttonStyle(SecondaryBoxButtonStyle())
                if let photoStatus {
                    Text(photoStatus)
                        .font(Tokens.meta)
                        .foregroundStyle(photoAsset == nil ? Tokens.danger : Tokens.textSecondary)
                }
                Text("원본 형식을 유지하며 최대 50MB · 1억 픽셀까지 저장합니다.")
                    .font(Tokens.meta)
                    .foregroundStyle(Tokens.textSecondary)
            }
        }
    }

    private func contentEditor(placeholder: String) -> some View {
        TextEditor(text: $text)
            .font(Tokens.body)
            .lineSpacing(Tokens.bodyLineSpacing)
            .scrollContentBackground(.hidden)
            .padding(Tokens.rowGap)
            .frame(minHeight: 120)
            .tokenSurface(radius: Tokens.radiusInput)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(Tokens.body)
                        .foregroundStyle(Tokens.textTertiary)
                        .padding(.top, Tokens.rowGap + 8)
                        .padding(.leading, Tokens.rowGap + 5)
                        .allowsHitTesting(false)
                }
            }
    }

    private func saveClip() {
        guard !saved, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try store.createManualClip(
                type: type,
                title: title,
                url: url,
                text: text,
                destination: destination,
                tags: tags,
                memo: memo,
                imageAsset: photoAsset
            )
            saveError = nil
            saved = true
        } catch {
            saveError = error.localizedDescription
        }
    }

    @MainActor
    private func loadPhoto(_ item: PhotosPickerItem) async {
        photoAsset = nil
        photoStatus = "사진을 확인하는 중…"
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw SharedImageAssetError.unsupported
            }
            let asset = try SharedImageAsset(validatingData: data, typeIdentifier: item.supportedContentTypes.first?.identifier)
            photoAsset = asset
            photoStatus = ByteCountFormatter.string(fromByteCount: asset.byteCount, countStyle: .file)
        } catch {
            photoStatus = error.localizedDescription
        }
    }

    private func resetDraft() {
        saved = false
        type = .link
        title = ""
        url = ""
        text = ""
        destination = store.preferences.defaultFolder
        tags = []
        memo = ""
        saveError = nil
        photoItem = nil
        photoAsset = nil
        photoStatus = nil
    }
}

// MARK: - 저장 위치 선택

struct DestinationSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var destination: String

    var body: some View {
        ScreenScaffold {
            ScreenHeader("저장 위치", onBack: { dismiss() })

            BoardSection(title: "폴더 선택") {
                VStack(spacing: 0) {
                    ForEach(store.destinationFolders) { folder in
                        ActionRow(systemImage: folder.systemImage, label: folder.label,
                                  value: L10n.format("format.folder_clip_count", store.folderCount(folder.label)),
                                  isSelected: destination == folder.label) {
                            destination = folder.label
                        }
                    }
                }
            }

            Button {
                dismiss()
            } label: {
                Label("선택 완료", systemImage: "checkmark")
            }
            .buttonStyle(PrimaryBoxButtonStyle())
        }
    }
}

// MARK: - 태그 편집

struct TagEditorSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var tags: [String]
    @State private var newTag = ""

    private var tagOptions: [String] {
        var seen = Set<String>()
        return (tags + store.availableTags).filter { seen.insert($0).inserted }
    }

    var body: some View {
        ScreenScaffold(dismissKeyboardOnBackgroundTap: false) {
            ScreenHeader("태그 편집", onBack: { dismiss() })

            BoardSection(title: "태그 선택", count: tags.count) {
                TwoRowHorizontalSelection(items: tagOptions.map { tag in
                    (tag, tags.contains(tag), {
                            if tags.contains(tag) {
                                tags.removeAll { $0 == tag }
                            } else if tags.count < 12 {
                                tags.append(tag)
                            }
                    })
                })
            }

            BoardSection(title: "직접 입력") {
                HStack(spacing: Tokens.rowGap) {
                    TextField("새 태그", text: $newTag)
                        .font(Tokens.body)
                        .padding(.horizontal, Tokens.cardPad)
                        .frame(minHeight: Tokens.chipTarget + 4)
                        .tokenSurface(radius: Tokens.radiusInput)
                        .onSubmit(addNewTag)
                    Button(action: addNewTag) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Tokens.textPrimary)
                            .frame(width: Tokens.touchTarget, height: Tokens.touchTarget)
                            .tokenSurface(fill: Tokens.accentYellow, radius: Tokens.radiusButton)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("태그 추가")
                }
            }

            Button {
                dismiss()
            } label: {
                Label("태그 적용", systemImage: "checkmark")
            }
            .buttonStyle(PrimaryBoxButtonStyle())
        }
    }

    private func addNewTag() {
        let tag = AppStore.cleanText(newTag, maxLength: 50)
        guard !tag.isEmpty, tags.count < 12 else { return }
        let canonical = store.availableTags.first {
            $0.caseInsensitiveCompare(tag) == .orderedSame
        } ?? (try? store.addTag(tag))
        guard let canonical, !tags.contains(canonical) else { return }
        tags.append(canonical)
        newTag = ""
    }
}
