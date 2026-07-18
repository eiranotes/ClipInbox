import SwiftUI

/// Sort Later 분류 플로우: 미정리 클립을 하나씩 추천 폴더로 정리한다.
struct SortView: View {
    @Environment(AppStore.self) private var store
    @Environment(URLMetadataCoordinator.self) private var metadata
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var total = 0
    @State private var completed = 0
    @State private var classified = 0
    @State private var choice = ""
    @State private var deleteCandidate: Clip?
    @State private var localDeletionID: UUID?

    var body: some View {
        let unsorted = store.unsortedClips
        ScreenScaffold {
            ScreenHeader("분류하기", onBack: { dismiss() }) {
                Text(progressText(hasCurrentClip: !unsorted.isEmpty))
                    .font(Tokens.chip)
                    .foregroundStyle(Tokens.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .tokenSurface(fill: Tokens.bgCardMuted, radius: Tokens.radiusChip,
                                  border: Tokens.borderSoft, borderWidth: Tokens.borderChipWidth)
            }

            if let clip = unsorted.first {
                VStack(alignment: .leading, spacing: Tokens.sectionGap) {
                    ClipDetailOverview(clip: clip)
                    MetadataDetailSectionsView(clip: clip)
                }
                .id(clip.id)
            } else {
                BoardSection(title: "분류 완료") {
                    StatePanel(systemImage: "checkmark.circle",
                               title: "미정리 클립을 모두 분류했습니다",
                               message: completionMessage)
                }
                Button {
                    dismiss()
                } label: {
                    Label("인박스로 돌아가기", systemImage: "tray")
                }
                .buttonStyle(PrimaryBoxButtonStyle())
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if unsorted.first != nil || store.pendingDeletion != nil {
                VStack(spacing: 0) {
                    if let pendingDeletion = store.pendingDeletion {
                        UndoDeletionBanner(title: pendingDeletion.displayTitle) {
                            undoDeletion(pendingDeletion)
                        }
                        .padding(.vertical, Tokens.rowGap)
                        .background(Tokens.bgCardMuted)
                    }
                    if let clip = unsorted.first {
                        classificationBar(for: clip)
                    }
                }
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert(
            "삭제 확인",
            isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            ),
            presenting: deleteCandidate
        ) { clip in
            Button("삭제 확인", role: .destructive) {
                delete(clip)
            }
            Button("취소", role: .cancel) {}
        } message: { _ in
            Text("이 클립은 휴지통으로 이동하며 5초 동안 바로 되돌릴 수 있습니다.")
        }
        .onAppear {
            total = store.unsortedClips.count
            completed = 0
            classified = 0
            syncChoice()
        }
        .task(id: unsorted.first?.id) {
            guard let clip = store.unsortedClips.first,
                  !clip.url.isEmpty,
                  metadata.result(for: clip.id) == nil else { return }
            await metadata.analyze(clip: clip, store: store, forceRefresh: false)
        }
    }

    @ViewBuilder
    private func classificationBar(for clip: Clip) -> some View {
        let choices = sortChoices(for: clip)
        let selected = choices.contains(choice) ? choice : (choices.first ?? store.preferences.defaultFolder)

        VStack(alignment: .leading, spacing: Tokens.rowGap) {
            Text("폴더")
                .font(Tokens.metaBold)
                .foregroundStyle(Tokens.textSecondary)
                .accessibilityAddTraits(.isHeader)

            ClassificationFolderPicker(options: choices, selection: selected) { option in
                choice = option
            }

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: Tokens.rowGap) {
                        deleteButton(for: clip)
                        classifyButton(clip: clip, destination: selected)
                    }
                } else {
                    HStack(spacing: Tokens.rowGap) {
                        deleteButton(for: clip)
                        classifyButton(clip: clip, destination: selected)
                    }
                }
            }
        }
        .padding(.horizontal, Tokens.screenX)
        .padding(.top, Tokens.cardPad)
        .padding(.bottom, Tokens.rowGap)
        .background(
            Tokens.bgCardMuted
                .overlay(alignment: .top) {
                    Tokens.borderSoft.frame(height: Tokens.borderChipWidth)
                }
        )
    }

    private func deleteButton(for clip: Clip) -> some View {
        Button {
            deleteCandidate = clip
        } label: {
            Label("삭제", systemImage: "trash")
        }
        .buttonStyle(SecondaryBoxButtonStyle(isDanger: true))
    }

    private func classifyButton(clip: Clip, destination: String) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: Tokens.motionBase)) {
                guard store.applySort(clipID: clip.id, to: destination) else { return }
                completed += 1
                classified += 1
                syncChoice()
            }
        } label: {
            Text(L10n.format("format.sort_to_folder", L10n.text(destination)))
        }
        .buttonStyle(PrimaryBoxButtonStyle())
    }

    private func delete(_ clip: Clip) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: Tokens.motionBase)) {
            guard store.deleteClip(id: clip.id) else { return }
            completed += 1
            localDeletionID = store.pendingDeletion?.id
            deleteCandidate = nil
            syncChoice()
        }
    }

    private func undoDeletion(_ deletion: AppStore.PendingDeletion) {
        guard store.undoDelete() else { return }
        if localDeletionID == deletion.id {
            completed = max(0, completed - 1)
            localDeletionID = nil
            syncChoice()
        }
    }

    private func sortChoices(for clip: Clip) -> [String] {
        var seen = Set<String>()
        var choices: [String] = []
        let candidates = clip.folderSuggestions + store.destinationFolders.map(\.label)
        for suggestion in candidates {
            guard suggestion != "전체", !seen.contains(suggestion) else { continue }
            seen.insert(suggestion)
            choices.append(suggestion)
        }
        if choices.isEmpty { choices.append(store.preferences.defaultFolder) }
        return choices
    }

    private func syncChoice() {
        guard let clip = store.unsortedClips.first else {
            choice = ""
            return
        }
        choice = sortChoices(for: clip).first ?? store.preferences.defaultFolder
    }

    private func progressText(hasCurrentClip: Bool) -> String {
        guard total > 0 else { return "0/0" }
        let current = min(completed + (hasCurrentClip ? 1 : 0), total)
        return "\(current)/\(total)"
    }

    private var completionMessage: String {
        let deleted = max(0, completed - classified)
        if classified == 0, deleted > 0 {
            return "삭제한 클립은 휴지통에서 확인하거나 복원할 수 있습니다."
        }
        if deleted > 0 {
            return "분류한 클립은 선택한 폴더에 있고, 삭제한 클립은 휴지통에서 확인할 수 있습니다."
        }
        return "선택한 폴더에서 바로 확인할 수 있습니다."
    }
}

/// 일반 글자 크기에서는 폴더들을 한눈에 스캔하고, 접근성 크기에서는 같은 선택을 메뉴로 축약한다.
private struct ClassificationFolderPicker: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let options: [String]
    let selection: String
    let onSelect: (String) -> Void

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        if selection == option {
                            Label(L10n.text(option, locale: locale), systemImage: "checkmark")
                        } else {
                            Text(L10n.text(option, locale: locale))
                        }
                    }
                }
            } label: {
                HStack(spacing: Tokens.cardGap) {
                    Image(systemName: "folder")
                        .font(.system(size: 16, weight: .semibold))
                    Text(L10n.text(selection, locale: locale))
                        .font(Tokens.bodySemibold)
                    Spacer(minLength: Tokens.rowGap)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Tokens.textTertiary)
                }
                .foregroundStyle(Tokens.textPrimary)
                .padding(.horizontal, Tokens.cardPad)
                .frame(maxWidth: .infinity, minHeight: Tokens.actionTarget)
                .tokenSurface(fill: Tokens.bgCard, radius: Tokens.radiusInput)
            }
            .buttonStyle(ResponsivePressButtonStyle())
            .accessibilityLabel("\(L10n.text("폴더", locale: locale)): \(L10n.text(selection, locale: locale))")
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Tokens.chipGap) {
                    ForEach(options, id: \.self) { option in
                        let isSelected = selection == option
                        Button {
                            onSelect(option)
                        } label: {
                            HStack(spacing: Tokens.space1) {
                                Image(systemName: isSelected ? "checkmark" : "folder")
                                    .font(.system(size: 12, weight: .bold))
                                Text(L10n.text(option, locale: locale))
                                    .font(Tokens.chip)
                                    .lineLimit(1)
                            }
                            .foregroundStyle(isSelected ? Tokens.onAccent : Tokens.textPrimary)
                            .padding(.horizontal, Tokens.cardPad)
                            .frame(minWidth: 84, minHeight: Tokens.touchTarget)
                            .background(
                                RoundedRectangle(cornerRadius: Tokens.radiusChip, style: .continuous)
                                    .fill(isSelected ? Tokens.accentYellow : Tokens.bgCard)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Tokens.radiusChip, style: .continuous)
                                    .strokeBorder(Tokens.borderSoft, lineWidth: Tokens.borderChipWidth)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: Tokens.radiusChip, style: .continuous))
                        }
                        .buttonStyle(ResponsivePressButtonStyle())
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
            .frame(height: Tokens.touchTarget)
        }
    }
}
