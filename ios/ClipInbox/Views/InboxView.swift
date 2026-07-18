import SwiftUI

struct InboxView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selectedTab: AppTab
    @State private var filter: InboxFilter = .all
    @State private var showSortFlow = false
    @State private var actionClipID: Int?
    @State private var isSelecting = false
    @State private var selectedClipIDs: Set<Int> = []
    @State private var showBatchMove = false
    @State private var showBatchDeleteConfirm = false

    private var list: [Clip] { store.filteredClips(filter) }
    private var visibleClipIDs: Set<Int> { Set(list.map(\.id)) }
    private var allVisibleSelected: Bool {
        !visibleClipIDs.isEmpty && visibleClipIDs.isSubset(of: selectedClipIDs)
    }

    var body: some View {
        ScreenScaffold(additionalBottomPadding: Tokens.bottomNavigationClearance) {
            ScreenHeader(headerTitle, trailing: {
                if isSelecting {
                    Button(allVisibleSelected ? "전체 해제" : "전체 선택", action: toggleAllVisible)
                        .font(Tokens.bodySemibold)
                        .foregroundStyle(Tokens.textPrimary)
                        .frame(minHeight: Tokens.touchTarget)
                        .buttonStyle(ResponsivePressButtonStyle())
                    Button("완료", action: finishSelection)
                        .font(Tokens.bodyBold)
                        .foregroundStyle(Tokens.textPrimary)
                        .frame(minWidth: Tokens.touchTarget, minHeight: Tokens.touchTarget)
                        .buttonStyle(ResponsivePressButtonStyle())
                } else {
                    if !list.isEmpty {
                        UtilityIconButton(label: "선택", systemImage: "checkmark.circle") {
                            isSelecting = true
                        }
                    }
                    UtilityIconButton(label: "분류하기", systemImage: "arrow.up.arrow.down") {
                        showSortFlow = true
                    }
                }
            })

            VStack(spacing: Tokens.rowGap) {
                if store.activeClips.isEmpty, filter == .all, dynamicTypeSize.isAccessibilitySize {
                    FirstCaptureGuide {
                        selectedTab = .add
                    }
                }

                // 윗줄은 스마트 보기와 폴더, 아랫줄은 태그 필터를 보여 준다.
                TwoRowHorizontalSelection(
                    topRow: store.inboxScopeFilters.map { item in
                        (store.filterLabel(item), filter == item, { selectFilter(item) })
                    },
                    bottomRow: store.inboxTagFilters.map { item in
                        (store.filterLabel(item), filter == item, { selectFilter(item) })
                    },
                    topLabel: "보기"
                )

                if store.activeClips.isEmpty, filter == .all, !dynamicTypeSize.isAccessibilitySize {
                    FirstCaptureGuide {
                        selectedTab = .add
                    }
                    .padding(.top, Tokens.emptyGuideTop)
                } else if list.isEmpty {
                    EmptyStateView(title: "표시할 클립이 없습니다",
                                   message: "다른 항목을 선택하거나 새 클립을 추가해 보세요.",
                                   actionTitle: "전체 보기") {
                        selectFilter(.all)
                    }
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(list) { clip in
                            ClipCardView(
                                clip: clip,
                                selectionState: isSelecting ? selectedClipIDs.contains(clip.id) : nil,
                                onSelectionToggle: { toggleSelection(for: clip.id) },
                                onMenu: { actionClipID = clip.id }
                            )
                        }
                    }
                }
            }

        }
        .fullScreenCover(isPresented: $showSortFlow) {
            SortView()
        }
        .sheet(isPresented: $showBatchMove) {
            BatchMoveFolderSheet(clipIDs: selectedClipIDs) {
                finishSelection()
            }
            .workflowSheet(.expanded)
        }
        .sheet(item: Binding(
            get: { actionClipID.flatMap { store.clip(id: $0) } },
            set: { actionClipID = $0?.id }
        )) { clip in
            CardActionsSheet(clipID: clip.id)
                .workflowSheet(.expanded)
        }
        .alert(
            L10n.format("format.delete_selected_clips_title", selectedClipIDs.count),
            isPresented: $showBatchDeleteConfirm
        ) {
            Button("삭제", role: .destructive, action: deleteSelection)
            Button("취소", role: .cancel) {}
        } message: {
            Text("선택한 클립은 휴지통으로 이동하며 5초 동안 바로 되돌릴 수 있습니다.")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isSelecting {
                BatchSelectionBar(
                    selectionCount: selectedClipIDs.count,
                    move: { showBatchMove = true },
                    delete: { showBatchDeleteConfirm = true }
                )
                // RootView owns the persistent bottom navigation, so keep this
                // contextual bar above that independently inserted safe area.
                .padding(.bottom, Tokens.bottomNavigationClearance)
            }
        }
        .onChange(of: list.map(\.id)) { _, visibleIDs in
            selectedClipIDs.formIntersection(Set(visibleIDs))
            if visibleIDs.isEmpty, isSelecting { finishSelection() }
        }
    }

    private var headerTitle: String {
        guard isSelecting else { return "클립 인박스" }
        return selectedClipIDs.isEmpty
            ? "클립 선택"
            : L10n.format("format.selected_clip_count", selectedClipIDs.count)
    }

    private func selectFilter(_ newFilter: InboxFilter) {
        filter = newFilter
        selectedClipIDs.removeAll()
    }

    private func toggleSelection(for id: Int) {
        if selectedClipIDs.contains(id) {
            selectedClipIDs.remove(id)
        } else if visibleClipIDs.contains(id) {
            selectedClipIDs.insert(id)
        }
    }

    private func toggleAllVisible() {
        if allVisibleSelected {
            selectedClipIDs.subtract(visibleClipIDs)
        } else {
            selectedClipIDs.formUnion(visibleClipIDs)
        }
    }

    private func deleteSelection() {
        guard store.deleteClips(ids: selectedClipIDs) else { return }
        finishSelection()
    }

    private func finishSelection() {
        isSelecting = false
        selectedClipIDs.removeAll()
        showBatchMove = false
        showBatchDeleteConfirm = false
    }
}

private struct BatchSelectionBar: View {
    let selectionCount: Int
    let move: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.rowGap) {
            Text(L10n.format("format.selected_clip_count", selectionCount))
                .font(Tokens.bodyBold)
                .foregroundStyle(Tokens.textPrimary)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: Tokens.rowGap) {
                Button(action: move) {
                    Label("폴더 이동", systemImage: "folder")
                }
                .buttonStyle(SecondaryBoxButtonStyle())

                Button(action: delete) {
                    Label("삭제", systemImage: "trash")
                }
                .buttonStyle(SecondaryBoxButtonStyle(isDanger: true))
            }
        }
        .disabled(selectionCount == 0)
        .opacity(selectionCount == 0 ? 0.45 : 1)
        .padding(.horizontal, Tokens.screenX)
        .padding(.vertical, Tokens.rowGap)
        .background(
            Tokens.bgCardMuted
                .overlay(alignment: .top) {
                    Tokens.borderSoft.frame(height: Tokens.borderChipWidth)
                }
        )
    }
}

private struct BatchMoveFolderSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let clipIDs: Set<Int>
    let onMoved: () -> Void
    @State private var destination = ""

    var body: some View {
        ScreenScaffold {
            ScreenHeader("폴더 이동", onBack: { dismiss() })

            BoardSection(title: "이동할 폴더", count: clipIDs.count) {
                VStack(spacing: 0) {
                    ForEach(store.destinationFolders) { folder in
                        ActionRow(
                            systemImage: folder.systemImage,
                            label: folder.label,
                            value: L10n.format("format.folder_clip_count", store.folderCount(folder.label)),
                            isSelected: destination == folder.label
                        ) {
                            destination = folder.label
                        }
                    }
                }
            }

            Button {
                guard store.moveClips(ids: clipIDs, to: destination) else { return }
                onMoved()
                dismiss()
            } label: {
                Label {
                    Text(L10n.format("format.move_selected_clips", clipIDs.count))
                } icon: {
                    Image(systemName: "checkmark")
                }
            }
            .buttonStyle(PrimaryBoxButtonStyle())
            .disabled(destination.isEmpty || clipIDs.isEmpty)
        }
        .onAppear {
            if store.destinationFolders.contains(where: { $0.label == store.preferences.defaultFolder }) {
                destination = store.preferences.defaultFolder
            } else {
                destination = store.destinationFolders.first?.label ?? ""
            }
        }
    }
}

private struct FirstCaptureGuide: View {
    let openAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.sectionGap) {
            StatePanel(
                systemImage: "square.and.arrow.down",
                title: "첫 클립을 저장해 보세요",
                message: "Safari, Photos 또는 다른 앱의 공유 버튼에서 Clip Inbox를 선택하면 바로 인박스에 모입니다."
            )

            VStack(alignment: .leading, spacing: Tokens.cardGap) {
                guideStep(1, title: "공유해서 저장", message: "공유 시트에서 Clip Inbox 선택")
                guideStep(2, title: "바로 저장하거나 검토", message: "설정한 Quick 또는 Review 방식 사용")
                guideStep(3, title: "나중에 정리", message: "폴더, 태그, 검색으로 다시 찾기")
            }

            Button(action: openAdd) {
                Label("직접 추가", systemImage: "plus")
            }
            .buttonStyle(PrimaryBoxButtonStyle())
        }
        .accessibilityElement(children: .contain)
    }

    private func guideStep(_ number: Int, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.cardGap) {
            Text("\(number)")
                .font(Tokens.bodyBold)
                .frame(width: Tokens.destinationIcon, height: Tokens.destinationIcon)
                .tokenSurface(fill: Tokens.accentYellow, radius: Tokens.radiusChip)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.text(title)).font(Tokens.bodyBold)
                Text(L10n.text(message)).font(Tokens.meta).foregroundStyle(Tokens.textSecondary)
            }
        }
        .foregroundStyle(Tokens.textPrimary)
    }
}

// MARK: - 카드 메뉴 시트

struct CardActionsSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let clipID: Int

    @State private var showShare = false
    @State private var showMove = false
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var showExternalConfirm = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let clip = store.clip(id: clipID) {
            ScreenScaffold {
                ScreenHeader("카드 메뉴", onBack: { dismiss() })

                BoardSection(title: "선택한 클립") {
                    StatePanel(systemImage: clip.type.systemImage, title: clip.presentationTitle, message: clip.source)
                }

                BoardSection(title: "클립 작업") {
                    VStack(spacing: Tokens.rowGap) {
                        if !clip.url.isEmpty {
                            ActionRow(systemImage: "arrow.up.right.square", label: "링크 열기", value: "원본 페이지 확인") {
                                openLink(clip)
                            }
                        }
                        ActionRow(systemImage: "bookmark", label: "북마크",
                                  value: clip.bookmarked ? "이미 추가됨" : "빠른 보관") {
                            store.toggleBookmark(id: clip.id)
                            store.showToast(store.clip(id: clip.id)?.bookmarked == true ? "북마크에 추가했습니다" : "북마크에서 해제했습니다")
                        }
                        ActionRow(systemImage: "square.and.arrow.up", label: "공유", value: "링크 또는 이미지 카드") {
                            showShare = true
                        }
                        ActionRow(systemImage: "folder", label: "이동", value: "폴더 변경") {
                            showMove = true
                        }
                        ActionRow(systemImage: "pencil", label: "편집", value: "제목, 태그, 메모 수정") {
                            showEdit = true
                        }
                        ActionRow(systemImage: "trash", label: "삭제", value: "삭제 전 확인", isDanger: true) {
                            showDeleteConfirm = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showShare) { ShareOptionsSheet(clipID: clip.id).workflowSheet(.standard) }
            .sheet(isPresented: $showMove) { MoveFolderSheet(clipID: clip.id).workflowSheet(.expanded) }
            .sheet(isPresented: $showEdit) { EditClipSheet(clipID: clip.id).workflowSheet(.expanded) }
            .confirmationDialog("브라우저에서 열까요?", isPresented: $showExternalConfirm, titleVisibility: .visible) {
                Button("브라우저에서 열기") {
                    if let url = URL(string: clip.url) { openURL(url) }
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
                Text("이 클립은 휴지통으로 이동하며 5초 동안 바로 되돌릴 수 있습니다.")
            }
        }
    }

    private func openLink(_ clip: Clip) {
        guard let url = URL(string: clip.url) else { return }
        if store.linkOpenMode == .confirm {
            showExternalConfirm = true
        } else {
            openURL(url)
        }
    }
}
