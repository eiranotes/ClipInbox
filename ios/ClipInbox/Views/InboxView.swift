import SwiftUI

struct InboxView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selectedTab: AppTab
    @State private var filter: InboxFilter = .all
    @State private var showSortFlow = false
    @State private var actionClipID: Int?

    private var list: [Clip] { store.filteredClips(filter) }

    var body: some View {
        ScreenScaffold(additionalBottomPadding: Tokens.bottomNavigationClearance) {
            ScreenHeader("클립 인박스", trailing: {
                UtilityIconButton(label: "분류하기", systemImage: "arrow.up.arrow.down") {
                    showSortFlow = true
                }
            })

            VStack(spacing: Tokens.rowGap) {
                if store.activeClips.isEmpty, filter == .all, dynamicTypeSize.isAccessibilitySize {
                    FirstCaptureGuide {
                        selectedTab = .add
                    }
                }

                // 윗줄은 폴더, 아랫줄은 태그 필터를 보여 준다.
                TwoRowHorizontalSelection(
                    topRow: store.inboxFolderFilters.map { item in
                        (store.filterLabel(item), filter == item, { filter = item })
                    },
                    bottomRow: store.inboxTagFilters.map { item in
                        (store.filterLabel(item), filter == item, { filter = item })
                    }
                )

                if store.activeClips.isEmpty, filter == .all, !dynamicTypeSize.isAccessibilitySize {
                    FirstCaptureGuide {
                        selectedTab = .add
                    }
                    .padding(.top, Tokens.emptyGuideTop)
                } else if list.isEmpty {
                    EmptyStateView(title: "표시할 클립이 없습니다",
                                   message: "다른 항목을 선택하거나 새 클립을 추가해 보세요.")
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(list) { clip in
                            ClipCardView(clip: clip) {
                                actionClipID = clip.id
                            }
                        }
                    }
                }
            }

        }
        .fullScreenCover(isPresented: $showSortFlow) {
            SortView()
        }
        .sheet(item: Binding(
            get: { actionClipID.flatMap { store.clip(id: $0) } },
            set: { actionClipID = $0?.id }
        )) { clip in
            CardActionsSheet(clipID: clip.id)
                .workflowSheet(.expanded)
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
