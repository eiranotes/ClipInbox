import SwiftUI

struct FoldersView: View {
    @Environment(AppStore.self) private var store
    @State private var showNewFolder = false

    var body: some View {
        ScreenScaffold {
            ScreenHeader("폴더", trailing: {
                UtilityIconButton(label: "새 폴더", systemImage: "plus") {
                    showNewFolder = true
                }
            })

            VStack(spacing: 0) {
                ForEach(Array(store.folders.enumerated()), id: \.element.id) { index, folder in
                    NavigationLink(value: folder.icon == "trash"
                                   ? Route.trash
                                   : Route.folderDetail(folder.label)) {
                        DestinationRow(systemImage: folder.systemImage,
                                       title: folder.label,
                                       value: "\(store.folderCount(folder.label))")
                    }
                    .buttonStyle(.plain)
                    if index < store.folders.count - 1 {
                        RowDivider()
                    }
                }
            }

            Spacer(minLength: Tokens.bottomSafe - Tokens.sectionGap * 2)
        }
        .sheet(isPresented: $showNewFolder) {
            NewFolderSheet().workflowSheet(.standard)
        }
    }
}

// MARK: - 휴지통

struct TrashView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showEmptyConfirmation = false

    var body: some View {
        let clips = store.trashedClips
        ScreenScaffold(additionalBottomPadding: Tokens.bottomNavigationClearance) {
            ScreenHeader("휴지통", onBack: { dismiss() })

            StatePanel(
                systemImage: "clock.badge.exclamationmark",
                title: "30일 동안 보관됩니다",
                message: "삭제된 클립은 휴지통에서 복원할 수 있으며 30일이 지나면 원본 이미지와 함께 자동으로 영구 삭제됩니다.",
                isAccent: true
            )
            .padding(Tokens.panelPad)
            .tokenSurface(fill: Tokens.accentYellow, radius: Tokens.radiusPanel,
                          border: Tokens.borderSoft, borderWidth: Tokens.borderChipWidth)

            BoardSection(title: "삭제된 클립", count: clips.count) {
                if clips.isEmpty {
                    EmptyStateView(systemImage: "trash",
                                   title: "휴지통이 비어 있습니다",
                                   message: "삭제한 클립이 여기에 최대 30일 동안 보관됩니다.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(clips) { clip in
                            TrashClipRow(clip: clip)
                        }
                    }
                }
            }

            if !clips.isEmpty {
                Button {
                    showEmptyConfirmation = true
                } label: {
                    Label("휴지통 비우기", systemImage: "trash.slash")
                }
                .buttonStyle(SecondaryBoxButtonStyle(isDanger: true))
            }
        }
        .alert("휴지통을 비울까요?", isPresented: $showEmptyConfirmation) {
            Button("영구 삭제", role: .destructive) {
                store.emptyTrash()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("휴지통의 클립과 원본 이미지를 모두 삭제합니다. 이 작업은 되돌릴 수 없습니다.")
        }
    }
}

private struct TrashClipRow: View {
    @Environment(AppStore.self) private var store
    @Environment(\.locale) private var locale
    let clip: Clip

    var body: some View {
        HStack(spacing: Tokens.cardGap) {
            if clip.hasImageReference {
                ClipThumbnail(clip: clip, compact: true)
                    .frame(width: Tokens.resultThumbnailWidth,
                           height: Tokens.resultThumbnailHeight)
            }
            VStack(alignment: .leading, spacing: Tokens.space1) {
                Text(clip.title)
                    .font(Tokens.bodySemibold)
                    .foregroundStyle(Tokens.textPrimary)
                    .lineLimit(1)
                Text(L10n.format("format.trash_days_remaining",
                                 store.trashDaysRemaining(for: clip)))
                    .font(Tokens.meta)
                    .foregroundStyle(Tokens.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Tokens.rowGap)
            Button {
                store.restoreClip(id: clip.id)
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: Tokens.iconBody, weight: .semibold))
                    .foregroundStyle(Tokens.onAccent)
                    .frame(width: Tokens.touchTarget, height: Tokens.touchTarget)
                    .background(
                        RoundedRectangle(cornerRadius: Tokens.radiusChip, style: .continuous)
                            .fill(Tokens.accentYellow)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text("클립 복원", locale: locale))
        }
        .frame(minHeight: Tokens.actionTarget)
        .overlay(alignment: .bottom) {
            Tokens.borderSoft.frame(height: Tokens.borderChipWidth)
        }
    }
}

// MARK: - 새 폴더

struct NewFolderSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var defaultTag = "디자인"
    @State private var errorMessage: String?
    @FocusState private var nameFocused: Bool

    private let tagOptions = DefaultData.suggestedTags

    var body: some View {
        ScreenScaffold {
            ScreenHeader("새 폴더", onBack: close)

            BoardSection(title: "폴더 이름") {
                TextField("예: 읽을거리", text: $name)
                    .font(Tokens.body)
                    .padding(.horizontal, Tokens.cardPad)
                    .frame(minHeight: Tokens.actionTarget)
                    .tokenSurface(radius: Tokens.radiusInput)
                    .focused($nameFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: name) { errorMessage = nil }
            }

            BoardSection(title: "기본 태그") {
                TwoRowHorizontalSelection(items: tagOptions.map { tag in
                    (tag, defaultTag == tag, { defaultTag = tag })
                })
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(Tokens.metaBold)
                    .foregroundStyle(Tokens.danger)
            }

            Button {
                do {
                    _ = try store.createFolder(name: name, defaultTag: defaultTag)
                    close()
                } catch {
                    errorMessage = error.localizedDescription
                }
            } label: {
                Label("폴더 만들기", systemImage: "plus")
            }
            .buttonStyle(PrimaryBoxButtonStyle())
        }
    }

    private func close() {
        nameFocused = false
        Keyboard.dismiss()
        dismiss()
    }
}

// MARK: - 폴더 이름 편집

struct RenameFolderSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let originalLabel: String
    let onRenamed: (String) -> Void

    @State private var name: String
    @State private var errorMessage: String?
    @FocusState private var nameFocused: Bool

    init(originalLabel: String, onRenamed: @escaping (String) -> Void) {
        self.originalLabel = originalLabel
        self.onRenamed = onRenamed
        _name = State(initialValue: originalLabel)
    }

    var body: some View {
        ScreenScaffold {
            ScreenHeader("폴더 이름 편집", onBack: close)

            BoardSection(title: "폴더 이름") {
                TextField("폴더 이름", text: $name)
                    .font(Tokens.body)
                    .padding(.horizontal, Tokens.cardPad)
                    .frame(minHeight: Tokens.actionTarget)
                    .tokenSurface(radius: Tokens.radiusInput)
                    .focused($nameFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: name) { errorMessage = nil }
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
            let renamed = try store.renameFolder(from: originalLabel, to: name)
            onRenamed(renamed)
            close()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func close() {
        nameFocused = false
        Keyboard.dismiss()
        dismiss()
    }
}

// MARK: - 폴더 상세

struct FolderDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showNewFolder = false
    @State private var showRenameFolder = false
    @State private var currentLabel: String

    init(label: String) {
        _currentLabel = State(initialValue: label)
    }

    var body: some View {
        let matches = store.folderClips(currentLabel)
        ScreenScaffold {
            ScreenHeader(currentLabel, onBack: { dismiss() }, trailing: {
                HStack(spacing: 0) {
                    UtilityIconButton(label: "폴더 이름 편집", systemImage: "pencil") {
                        showRenameFolder = true
                    }
                    UtilityIconButton(label: "새 폴더", systemImage: "plus") {
                        showNewFolder = true
                    }
                }
            })

            BoardSection(title: "폴더 정보") {
                StatePanel(systemImage: "folder", title: currentLabel,
                           message: L10n.format("format.folder_contains", matches.count))
            }

            BoardSection(title: "클립", count: matches.count) {
                if matches.isEmpty {
                    EmptyStateView(title: "아직 클립이 없습니다",
                                   message: "클립을 이 폴더로 이동하면 여기에 표시됩니다.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(matches) { clip in
                            CompactResultRow(clip: clip)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showNewFolder) {
            NewFolderSheet().workflowSheet(.standard)
        }
        .sheet(isPresented: $showRenameFolder) {
            RenameFolderSheet(originalLabel: currentLabel) { renamed in
                currentLabel = renamed
            }
            .workflowSheet(.compact)
        }
    }
}
