import SwiftUI

struct DetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let clipID: Int

    @State private var showShare = false
    @State private var showMore = false
    @State private var showMove = false
    @State private var showEdit = false
    @State private var showTagEdit = false
    @State private var tagDraft: [String] = []
    @State private var showDeleteConfirm = false
    @State private var showExternalConfirm = false
    @State private var noteDraft = ""
    @State private var noteDirty = false

    var body: some View {
        if let clip = store.clip(id: clipID) {
            ScreenScaffold {
                ScreenHeader("클립 상세", onBack: { dismiss() }) {
                    UtilityIconButton(label: "북마크", systemImage: clip.bookmarked ? "bookmark.fill" : "bookmark",
                                      isOn: clip.bookmarked) {
                        store.toggleBookmark(id: clip.id)
                        store.showToast(store.clip(id: clip.id)?.bookmarked == true ? "북마크에 추가했습니다" : "북마크에서 해제했습니다")
                    }
                    UtilityIconButton(label: "공유", systemImage: "square.and.arrow.up") {
                        showShare = true
                    }
                    UtilityIconButton(label: "더보기", systemImage: "ellipsis") {
                        showMore = true
                    }
                }

                VStack(alignment: .leading, spacing: Tokens.detailGap) {
                    HStack(spacing: Tokens.rowGap) {
                        TokenBadge(tone: .type(clip.type))
                        if let state = clip.state { TokenBadge(tone: .state(state)) }
                    }
                    Text(clip.title)
                        .font(Tokens.sectionTitle)
                        .foregroundStyle(Tokens.textPrimary)
                        .lineSpacing(Tokens.titleLineSpacing)
                    HStack(spacing: Tokens.rowGap) {
                        HStack(spacing: 5) {
                            Image(systemName: "globe").font(.system(size: 12, weight: .bold))
                            Text(clip.source)
                        }
                        Spacer()
                        Text(clip.time)
                    }
                    .font(Tokens.meta)
                    .foregroundStyle(Tokens.textSecondary)

                    if clip.hasImageReference {
                        ClipThumbnail(clip: clip)
                            .frame(maxWidth: .infinity)
                            .frame(height: Tokens.detailImageHeight)
                    }

                    if !clip.description.isEmpty {
                        Text(clip.description)
                            .font(Tokens.body)
                            .foregroundStyle(Tokens.textPrimary)
                            .lineSpacing(Tokens.bodyLineSpacing)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: Tokens.rowGap) {
                    HStack {
                        Text("노트")
                            .font(Tokens.sectionTitle)
                            .foregroundStyle(Tokens.textPrimary)
                        Spacer(minLength: Tokens.rowGap)
                        Button("저장", action: saveNote)
                            .font(Tokens.bodySemibold)
                            .foregroundStyle(noteDirty ? Tokens.textPrimary : Tokens.textTertiary)
                            .disabled(!noteDirty)
                    }

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $noteDraft)
                            .font(Tokens.body)
                            .lineSpacing(Tokens.bodyLineSpacing)
                            .scrollContentBackground(.hidden)
                            .padding(Tokens.rowGap)
                            .frame(minHeight: Tokens.noteEditorMinHeight)
                            .background(Tokens.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.radiusInput, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Tokens.radiusInput, style: .continuous)
                                    .strokeBorder(Tokens.borderSoft, lineWidth: Tokens.borderChipWidth)
                            )
                        if noteDraft.isEmpty {
                            Text("이 클립에 대한 메모를 입력하세요")
                                .font(Tokens.body)
                                .foregroundStyle(Tokens.textTertiary)
                                .padding(.horizontal, Tokens.panelPad)
                                .padding(.vertical, Tokens.cardPad + Tokens.space1)
                                .allowsHitTesting(false)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("정리")
                        .font(Tokens.sectionTitle)
                        .foregroundStyle(Tokens.textPrimary)
                    organizeRow(label: "폴더", value: clip.folder, systemImage: "folder") {
                        showMove = true
                    }
                    organizeRow(label: "태그",
                                value: clip.tags.isEmpty ? "없음" : clip.tags.joined(separator: " · "),
                                systemImage: "tag") {
                        tagDraft = clip.tags
                        showTagEdit = true
                    }
                }

                VStack(spacing: Tokens.cardGap) {
                    Button {
                        showExternalConfirm = true
                    } label: {
                        Label(clip.url.isEmpty ? "열 수 있는 링크 없음" : "링크 열기",
                              systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(PrimaryBoxButtonStyle())
                    .disabled(clip.url.isEmpty)
                    .opacity(clip.url.isEmpty ? 0.5 : 1)

                    HStack(spacing: 0) {
                        quietAction(label: "이동", systemImage: "folder") { showMove = true }
                        Tokens.borderSoft.frame(width: Tokens.borderChipWidth, height: Tokens.touchTarget)
                        quietAction(label: "편집", systemImage: "pencil") { showEdit = true }
                        Tokens.borderSoft.frame(width: Tokens.borderChipWidth, height: Tokens.touchTarget)
                        quietAction(label: "삭제", systemImage: "trash", isDanger: true) {
                            showDeleteConfirm = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showShare) { ShareOptionsSheet(clipID: clip.id).workflowSheet() }
            .sheet(isPresented: $showMore) { CardActionsSheet(clipID: clip.id).workflowSheet() }
            .sheet(isPresented: $showMove) { MoveFolderSheet(clipID: clip.id).workflowSheet() }
            .sheet(isPresented: $showEdit) { EditClipSheet(clipID: clip.id).workflowSheet() }
            .sheet(isPresented: $showTagEdit, onDismiss: { store.updateTags(id: clipID, tags: tagDraft) }) {
                TagEditorSheet(tags: $tagDraft).workflowSheet()
            }
            .confirmationDialog("브라우저에서 열까요?", isPresented: $showExternalConfirm, titleVisibility: .visible) {
                Button("브라우저에서 열기") {
                    if let url = URL(string: clip.url) {
                        openURL(url)
                        store.showToast("브라우저에서 원본 열기를 요청했습니다")
                    }
                }
            } message: {
                Text(clip.source)
            }
            .alert("삭제 확인", isPresented: $showDeleteConfirm) {
                Button("삭제 확인", role: .destructive) {
                    store.deleteClip(id: clip.id)
                    dismiss()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("이 클립은 인박스와 폴더에서 즉시 제거됩니다.")
            }
            .onAppear {
                noteDraft = clip.memo ?? ""
                noteDirty = false
            }
            .onChange(of: noteDraft) { _, newValue in
                noteDirty = newValue != (store.clip(id: clip.id)?.memo ?? "")
            }
            .onDisappear {
                if noteDirty { store.updateMemo(id: clip.id, memo: noteDraft) }
            }
        } else {
            EmptyStateView(title: "클립을 찾을 수 없습니다", message: "삭제되었거나 이동된 클립입니다.")
                .background(Tokens.bgApp)
        }
    }

    private func saveNote() {
        store.updateMemo(id: clipID, memo: noteDraft)
        noteDirty = false
    }

    private func organizeRow(label: String, value: String, systemImage: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Tokens.cardGap) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.textSecondary)
                    .frame(width: Tokens.iconColumn)
                Text(label)
                    .font(Tokens.bodySemibold)
                    .foregroundStyle(Tokens.textPrimary)
                Spacer(minLength: Tokens.rowGap)
                Text(value)
                    .font(Tokens.meta)
                    .foregroundStyle(Tokens.textSecondary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.textTertiary)
            }
            .frame(minHeight: Tokens.actionTarget)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Tokens.borderSoft.frame(height: Tokens.borderChipWidth)
            }
        }
        .buttonStyle(.plain)
    }

    private func quietAction(label: String, systemImage: String, isDanger: Bool = false,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(Tokens.bodySemibold)
                .foregroundStyle(isDanger ? Tokens.danger : Tokens.textPrimary)
                .frame(maxWidth: .infinity, minHeight: Tokens.touchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 폴더 이동 시트

struct MoveFolderSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let clipID: Int
    @State private var destination = ""

    var body: some View {
        ScreenScaffold {
            ScreenHeader("폴더 이동", onBack: { dismiss() })

            BoardSection(title: "이동할 폴더") {
                VStack(spacing: 0) {
                    ForEach(store.destinationFolders) { folder in
                        ActionRow(systemImage: folder.systemImage, label: folder.label,
                                  value: "\(store.folderCount(folder.label))개 클립",
                                  isSelected: destination == folder.label) {
                            destination = folder.label
                        }
                    }
                }
            }

            Button {
                store.moveClip(id: clipID, to: destination)
                dismiss()
            } label: {
                Label("\(destination.withRoParticle) 이동", systemImage: "checkmark")
            }
            .buttonStyle(PrimaryBoxButtonStyle())
        }
        .onAppear {
            destination = store.clip(id: clipID)?.folder ?? store.preferences.defaultFolder
        }
    }
}

// MARK: - 클립 편집 시트

struct EditClipSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let clipID: Int

    @State private var title = ""
    @State private var memo = ""
    @State private var tags: [String] = []
    @State private var showTagEditor = false
    @State private var errorMessage: String?

    var body: some View {
        ScreenScaffold {
            ScreenHeader("클립 편집", onBack: { dismiss() })

            BoardSection(title: "제목") {
                TextField("클립 제목", text: $title)
                    .font(Tokens.body)
                    .padding(.horizontal, Tokens.cardPad)
                    .frame(minHeight: Tokens.actionTarget)
                    .tokenSurface(radius: Tokens.radiusInput)
            }

            BoardSection(title: "태그") {
                ActionRow(systemImage: "tag", label: "선택한 태그",
                          value: tags.isEmpty ? "없음" : tags.joined(separator: " · ")) {
                    showTagEditor = true
                }
            }

            BoardSection(title: "메모") {
                TextEditor(text: $memo)
                    .font(Tokens.body)
                    .lineSpacing(Tokens.bodyLineSpacing)
                    .scrollContentBackground(.hidden)
                    .padding(Tokens.rowGap)
                    .frame(minHeight: 110)
                    .tokenSurface(radius: Tokens.radiusInput)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(Tokens.metaBold)
                    .foregroundStyle(Tokens.danger)
            }

            Button {
                do {
                    try store.updateClip(id: clipID, title: title, memo: memo, tags: tags)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
            } label: {
                Label("변경 저장", systemImage: "checkmark")
            }
            .buttonStyle(PrimaryBoxButtonStyle())
        }
        .onAppear {
            guard let clip = store.clip(id: clipID) else { return }
            title = clip.title
            memo = clip.memo?.isEmpty == false ? clip.memo! : clip.description
            tags = clip.tags
        }
        .sheet(isPresented: $showTagEditor) {
            TagEditorSheet(tags: $tags).workflowSheet()
        }
    }
}
