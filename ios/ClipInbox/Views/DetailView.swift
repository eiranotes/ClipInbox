import SwiftUI
import UIKit

enum ClipDetailCopyKind: Equatable {
    case link
    case image

    static func resolve(for clip: Clip) -> Self? {
        if clip.type == .link, !clip.url.isEmpty { return .link }
        if !clip.imageSources.isEmpty { return .image }
        return clip.url.isEmpty ? nil : .link
    }
}

/// 상세 화면과 분류 흐름이 공유하는 클립의 기본 정보 영역.
/// 링크/복사 같은 작업과 노트/정리 편집은 포함하지 않아 정보 위계가 한 곳에서 유지된다.
struct ClipDetailOverview: View {
    @Environment(URLMetadataCoordinator.self) private var metadata
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let clip: Clip
    var imageHeight = Tokens.detailImageHeight
    var showsAttachmentSummary = true
    var onOpenImage: ((Int) -> Void)?

    var body: some View {
        let presentation = metadata.cardPresentation(for: clip, locale: locale)

        VStack(alignment: .leading, spacing: Tokens.detailGap) {
            HStack(spacing: Tokens.rowGap) {
                TokenBadge(tone: .type(clip.type))
                if let state = clip.state { TokenBadge(tone: .state(state)) }
            }
            Text(L10n.text(metadata.cardTitle(for: clip, locale: locale), locale: locale))
                .font(Tokens.sectionTitle)
                .foregroundStyle(Tokens.textPrimary)
                .lineSpacing(Tokens.titleLineSpacing)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: Tokens.rowGap) {
                HStack(spacing: 5) {
                    Image(systemName: clip.type.systemImage).font(.system(size: 12, weight: .bold))
                    Text(L10n.text(presentation?.subtitle ?? clip.source, locale: locale))
                }
                Spacer()
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(clip.timeLabel(relativeTo: context.date, locale: locale))
                }
            }
            .font(Tokens.meta)
            .foregroundStyle(Tokens.textSecondary)

            if clip.imageSources.count > 1 {
                ClipImageGallery(
                    sources: clip.imageSources,
                    height: resolvedImageHeight,
                    onOpen: onOpenImage
                )
            } else if !clip.imageSources.isEmpty {
                if let onOpenImage {
                    Button { onOpenImage(0) } label: {
                        localImage
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ResponsivePressButtonStyle())
                    .accessibilityLabel(L10n.text("이미지 크게 보기", locale: locale))
                } else {
                    localImage
                }
            } else if clip.hasImageReference {
                localImage
            } else if let thumbnailURL = presentation?.thumbnailURL.flatMap(URL.init(string:)) {
                MetadataRemoteImage(url: thumbnailURL, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: resolvedImageHeight)
            }

            if showsAttachmentSummary,
               (clip.attachments.count > 1 || clip.attachments.contains(where: { $0.kind == .file })) {
                ClipAttachmentSummary(attachments: clip.attachments)
            }

            // 링크 메타데이터가 있으면 별도의 접힌 정보 섹션이 요약을 담당한다.
            if !clip.description.isEmpty, metadata.result(for: clip.id) == nil {
                Text(L10n.text(clip.description, locale: locale))
                    .font(Tokens.body)
                    .foregroundStyle(Tokens.textPrimary)
                    .lineSpacing(Tokens.bodyLineSpacing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resolvedImageHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? imageHeight * 1.6 : imageHeight
    }

    private var localImage: some View {
        ClipThumbnail(clip: clip, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(height: resolvedImageHeight)
    }
}

struct ClipAttachmentSummary: View {
    let attachments: [SharedClipAttachment]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.rowGap) {
            Text(L10n.format("format.attachment_count", attachments.count))
                .font(Tokens.metaBold)
                .foregroundStyle(Tokens.textSecondary)
                .accessibilityAddTraits(.isHeader)

            ForEach(attachments.prefix(5)) { attachment in
                HStack(spacing: Tokens.cardGap) {
                    Image(systemName: attachment.kind == .image ? "photo" : "doc")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Tokens.textSecondary)
                        .frame(width: Tokens.iconColumn)
                    Text(attachment.originalFileName)
                        .font(Tokens.body)
                        .foregroundStyle(Tokens.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: Tokens.rowGap)
                    Text(ByteCountFormatter.string(fromByteCount: attachment.byteCount, countStyle: .file))
                        .font(Tokens.meta)
                        .foregroundStyle(Tokens.textTertiary)
                }
                .frame(minHeight: Tokens.touchTarget)
            }

            if attachments.count > 5 {
                Text(L10n.format("format.more_attachments", attachments.count - 5))
                    .font(Tokens.meta)
                    .foregroundStyle(Tokens.textSecondary)
            }
        }
        .padding(Tokens.cardPad)
        .tokenSurface(fill: Tokens.bgCardMuted, radius: Tokens.radiusInput)
    }
}

struct DetailView: View {
    @Environment(AppStore.self) private var store
    // CLIPINBOX_URL_METADATA_ENGINE_V1
    @Environment(URLMetadataCoordinator.self) private var metadata
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.navigationExitGuard) private var navigationExitGuard
    let clipID: Int

    @State private var showShare = false
    @State private var showMore = false
    @State private var showMove = false
    @State private var showEdit = false
    @State private var showTagEdit = false
    @State private var tagDraft: [String] = []
    @State private var showDeleteConfirm = false
    @State private var showExternalConfirm = false
    @State private var showImageViewer = false
    @State private var selectedImageIndex = 0
    @State private var selectedAttachmentIDs: Set<UUID> = []
    @State private var isSelectingAttachments = false
    @State private var isCopyingAttachments = false
    @State private var noteDraft = ""
    @State private var noteBaseline = ""
    @State private var noteDirty = false
    @State private var exitGuardOwnerID = UUID()

    var body: some View {
        if let clip = store.clip(id: clipID) {
            ScreenScaffold(additionalBottomPadding: Tokens.bottomNavigationClearance) {
                ScreenHeader("클립 상세", onBack: {
                    guard saveNoteIfNeeded() else { return }
                    dismiss()
                }) {
                    UtilityIconButton(label: "북마크", systemImage: clip.bookmarked ? "bookmark.fill" : "bookmark",
                                      isOn: clip.bookmarked,
                                      accessibilitySelectionState: clip.bookmarked) {
                        guard store.toggleBookmark(id: clip.id) else { return }
                        store.showToast(store.clip(id: clip.id)?.bookmarked == true
                                        ? "북마크에 추가했습니다"
                                        : "북마크에서 해제했습니다")
                    }
                    UtilityIconButton(label: "공유", systemImage: "square.and.arrow.up") {
                        guard saveNoteIfNeeded() else { return }
                        showShare = true
                    }
                    UtilityIconButton(label: "더보기", systemImage: "ellipsis") {
                        guard saveNoteIfNeeded() else { return }
                        showMore = true
                    }
                }

                ClipDetailOverview(clip: clip, showsAttachmentSummary: false) { index in
                    selectedImageIndex = index
                    showImageViewer = true
                }

                if !clip.storedAttachments.isEmpty {
                    ClipAttachmentDetailSection(
                        attachments: clip.storedAttachments,
                        selectedIDs: $selectedAttachmentIDs,
                        isSelecting: $isSelectingAttachments,
                        isCopying: isCopyingAttachments,
                        onOpenImage: { attachmentID in
                            guard let index = clip.imageSources.firstIndex(where: {
                                $0.attachmentID == attachmentID
                            }) else { return }
                            selectedImageIndex = index
                            showImageViewer = true
                        },
                        onCopyAll: { copyAttachments(clip.storedAttachments) },
                        onCopySelected: {
                            copyAttachments(ClipAttachmentPasteboard.selectedAttachments(
                                from: clip.storedAttachments,
                                selectedIDs: selectedAttachmentIDs
                            ))
                        }
                    )
                }

                MetadataDetailSectionsView(clip: clip)

                // 원본으로 이동하거나 클립 유형에 맞는 내용을 복사하는 핵심 액션.
                // 링크 썸네일은 이미지 클립으로 취급하지 않고 URL을 복사한다.
                if !clip.url.isEmpty || ClipDetailCopyKind.resolve(for: clip) != nil {
                    VStack(spacing: Tokens.rowGap) {
                        if !clip.url.isEmpty {
                            Button {
                                openLink(clip)
                            } label: {
                                Label("링크 열기", systemImage: "arrow.up.right.square")
                            }
                            .buttonStyle(PrimaryBoxButtonStyle())
                        }

                        if let copyKind = ClipDetailCopyKind.resolve(for: clip) {
                            Button {
                                copy(clip, as: copyKind)
                            } label: {
                                Label(copyActionLabel(for: clip, kind: copyKind), systemImage: "doc.on.doc")
                            }
                            .buttonStyle(SecondaryBoxButtonStyle())
                            .disabled(isCopyingAttachments)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Tokens.rowGap) {
                    HStack {
                        Text("노트")
                            .font(Tokens.sectionTitle)
                            .foregroundStyle(Tokens.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: Tokens.rowGap)
                        Button("저장") { _ = saveNote() }
                            .font(Tokens.bodySemibold)
                            .foregroundStyle(noteDirty ? Tokens.textPrimary : Tokens.textTertiary)
                            .disabled(!noteDirty)
                    }

                    TextField(
                        "",
                        text: $noteDraft,
                        prompt: Text(L10n.text("이 클립에 대한 메모를 입력하세요", locale: locale))
                            .foregroundStyle(Tokens.textTertiary),
                        axis: .vertical
                    )
                    .font(Tokens.body)
                    .lineSpacing(Tokens.bodyLineSpacing)
                    .lineLimit(3...)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(Tokens.rowGap)
                    .frame(maxWidth: .infinity,
                           minHeight: dynamicTypeSize.isAccessibilitySize
                               ? Tokens.noteEditorMinHeight * 2
                               : Tokens.noteEditorMinHeight,
                           alignment: .topLeading)
                    .background(Tokens.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.radiusInput, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Tokens.radiusInput, style: .continuous)
                            .strokeBorder(Tokens.borderSoft, lineWidth: Tokens.borderChipWidth)
                    )
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("정리")
                        .font(Tokens.sectionTitle)
                        .foregroundStyle(Tokens.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    organizeRow(label: "폴더", value: clip.folder, systemImage: "folder") {
                        guard saveNoteIfNeeded() else { return }
                        showMove = true
                    }
                    organizeRow(label: "태그",
                                value: clip.tags.isEmpty ? "없음" : clip.tags
                                    .map { L10n.text($0, locale: locale) }
                                    .joined(separator: " · "),
                                systemImage: "tag") {
                        guard saveNoteIfNeeded() else { return }
                        tagDraft = clip.tags
                        showTagEdit = true
                    }
                }

                VStack(spacing: Tokens.cardGap) {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: Tokens.rowGap) {
                            quietAction(label: "이동", systemImage: "folder") {
                                guard saveNoteIfNeeded() else { return }
                                showMove = true
                            }
                            quietAction(label: "편집", systemImage: "pencil") {
                                guard saveNoteIfNeeded() else { return }
                                showEdit = true
                            }
                            quietAction(label: "삭제", systemImage: "trash", isDanger: true) {
                                showDeleteConfirm = true
                            }
                        }
                    } else {
                        HStack(spacing: 0) {
                            quietAction(label: "이동", systemImage: "folder") {
                                guard saveNoteIfNeeded() else { return }
                                showMove = true
                            }
                            Tokens.borderSoft.frame(width: Tokens.borderChipWidth, height: Tokens.touchTarget)
                            quietAction(label: "편집", systemImage: "pencil") {
                                guard saveNoteIfNeeded() else { return }
                                showEdit = true
                            }
                            Tokens.borderSoft.frame(width: Tokens.borderChipWidth, height: Tokens.touchTarget)
                            quietAction(label: "삭제", systemImage: "trash", isDanger: true) {
                                showDeleteConfirm = true
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showShare) { ShareOptionsSheet(clipID: clip.id).workflowSheet(.standard) }
            .sheet(isPresented: $showMore, onDismiss: syncNoteFromStore) {
                CardActionsSheet(clipID: clip.id, onDelete: { dismiss() }).workflowSheet(.expanded)
            }
            .sheet(isPresented: $showMove) { MoveFolderSheet(clipID: clip.id).workflowSheet(.expanded) }
            .sheet(isPresented: $showEdit, onDismiss: syncNoteFromStore) {
                EditClipSheet(clipID: clip.id).workflowSheet(.expanded)
            }
            .sheet(isPresented: $showTagEdit, onDismiss: { store.updateTags(id: clipID, tags: tagDraft) }) {
                TagEditorSheet(tags: $tagDraft).workflowSheet(.standard)
            }
            .fullScreenCover(isPresented: $showImageViewer) {
                ClipImageViewer(sources: clip.imageSources, initialIndex: selectedImageIndex)
            }
            .confirmationDialog("브라우저에서 열까요?", isPresented: $showExternalConfirm, titleVisibility: .visible) {
                Button("브라우저에서 열기") {
                    if let url = URL(string: clip.url) {
                        openURL(url)
                        store.showToast("브라우저에서 원본 열기를 요청했습니다", semantic: .info)
                    }
                }
            } message: {
                Text(clip.source)
            }
            .alert("삭제 확인", isPresented: $showDeleteConfirm) {
                Button("삭제 확인", role: .destructive) {
                    guard saveNoteIfNeeded() else { return }
                    guard store.deleteClip(id: clip.id) else { return }
                    dismiss()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("이 클립은 휴지통으로 이동하며 5초 동안 바로 되돌릴 수 있습니다.")
            }
            .task(id: clip.url) {
                if metadata.result(for: clip.id) == nil {
                    await metadata.analyze(clip: clip, store: store, forceRefresh: false)
                }
            }
            .onAppear {
                syncNoteFromStore()
                navigationExitGuard?.register(ownerID: exitGuardOwnerID) {
                    saveNoteIfNeeded()
                }
            }
            .onChange(of: noteDraft) { _, newValue in
                noteDirty = newValue != noteBaseline
            }
            .onDisappear {
                _ = saveNoteIfNeeded()
                navigationExitGuard?.unregister(ownerID: exitGuardOwnerID)
            }
        } else {
            EmptyStateView(title: "클립을 찾을 수 없습니다", message: "삭제되었거나 이동된 클립입니다.")
                .background(Tokens.bgApp)
        }
    }

    @discardableResult
    private func saveNote() -> Bool {
        guard store.updateMemo(id: clipID, memo: noteDraft) else {
            noteDirty = true
            return false
        }
        let savedMemo = store.clip(id: clipID)?.memo ?? ""
        noteDraft = savedMemo
        noteBaseline = savedMemo
        noteDirty = false
        return true
    }

    private func saveNoteIfNeeded() -> Bool {
        !noteDirty || saveNote()
    }

    private func syncNoteFromStore() {
        let storedMemo = store.clip(id: clipID)?.memo ?? ""
        noteDraft = storedMemo
        noteBaseline = storedMemo
        noteDirty = false
    }

    private func openLink(_ clip: Clip) {
        guard let url = URL(string: clip.url) else { return }
        if store.linkOpenMode == .confirm {
            showExternalConfirm = true
        } else {
            openURL(url)
            store.showToast("브라우저에서 원본 열기를 요청했습니다", semantic: .info)
        }
    }

    private func copy(_ clip: Clip, as kind: ClipDetailCopyKind) {
        switch kind {
        case .link:
            UIPasteboard.general.string = clip.url
            store.showToast("링크를 복사했습니다")
        case .image:
            copyImageSources(clip.imageSources)
        }
    }

    private func copyActionLabel(for clip: Clip, kind: ClipDetailCopyKind) -> String {
        switch kind {
        case .link:
            return L10n.text("링크 복사", locale: locale)
        case .image:
            return clip.imageSources.count > 1
                ? L10n.format("format.copy_all_images", clip.imageSources.count)
                : L10n.text("이미지 복사", locale: locale)
        }
    }

    private func copyImageSources(_ sources: [ClipImageSource]) {
        guard !sources.isEmpty, !isCopyingAttachments else { return }
        isCopyingAttachments = true
        Task { @MainActor in
            do {
                let payloads = try await Task.detached(priority: .userInitiated) {
                    try ClipAttachmentPasteboard.prepareImageSources(sources)
                }.value
                ClipAttachmentPasteboard.write(payloads)
                store.showToast(L10n.format("format.copied_images", payloads.count))
            } catch {
                store.showToast("이미지를 복사할 수 없습니다", semantic: .error)
            }
            isCopyingAttachments = false
        }
    }

    private func copyAttachments(_ attachments: [ClipStoredAttachment]) {
        guard !attachments.isEmpty, !isCopyingAttachments else { return }
        isCopyingAttachments = true
        Task { @MainActor in
            do {
                let payloads = try await Task.detached(priority: .userInitiated) {
                    try ClipAttachmentPasteboard.prepareAttachments(attachments)
                }.value
                ClipAttachmentPasteboard.write(payloads)
                store.showToast(L10n.format("format.copied_attachments", payloads.count))
                selectedAttachmentIDs.removeAll()
                isSelectingAttachments = false
            } catch {
                store.showToast("첨부 파일을 복사할 수 없습니다", semantic: .error)
            }
            isCopyingAttachments = false
        }
    }

    private func organizeRow(label: String, value: String, systemImage: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Tokens.cardGap) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.textSecondary)
                    .frame(width: Tokens.iconColumn)
                Text(L10n.text(label, locale: locale))
                    .font(Tokens.bodySemibold)
                    .foregroundStyle(Tokens.textPrimary)
                Spacer(minLength: Tokens.rowGap)
                Text(L10n.text(value, locale: locale))
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
        .buttonStyle(ResponsivePressButtonStyle())
    }

    private func quietAction(label: String, systemImage: String, isDanger: Bool = false,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                Text(L10n.text(label, locale: locale))
            } icon: {
                Image(systemName: systemImage)
            }
                .font(Tokens.bodySemibold)
                .foregroundStyle(isDanger ? Tokens.danger : Tokens.textPrimary)
                .frame(maxWidth: .infinity, minHeight: Tokens.touchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(ResponsivePressButtonStyle())
    }
}

private struct ClipImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    let sources: [ClipImageSource]
    @State private var selectedID: String

    init(sources: [ClipImageSource], initialIndex: Int) {
        self.sources = sources
        let safeIndex = sources.indices.contains(initialIndex) ? initialIndex : 0
        _selectedID = State(initialValue: sources.indices.contains(safeIndex) ? sources[safeIndex].id : "")
    }

    private var selectedIndex: Int {
        sources.firstIndex(where: { $0.id == selectedID }) ?? 0
    }

    private var selectedSource: ClipImageSource? {
        sources.indices.contains(selectedIndex) ? sources[selectedIndex] : nil
    }

    var body: some View {
        ZStack {
            Tokens.bgApp.ignoresSafeArea()
            if let selectedSource {
                ZoomableClipImage(
                    image: ClipImageResolver.image(for: selectedSource),
                    reduceMotion: reduceMotion
                )
                .id(selectedSource.id)
                .padding(.horizontal, Tokens.screenX)
                .padding(.bottom, sources.count > 1 ? 84 : 0)
                .accessibilityLabel(L10n.format(
                    "format.image_position",
                    selectedIndex + 1,
                    sources.count,
                    selectedSource.displayName
                ))
                .accessibilityHint(L10n.text(
                    "두 번 탭하거나 두 손가락으로 확대하고 드래그해 이동합니다",
                    locale: locale
                ))
            } else {
                EmptyStateView(
                    systemImage: "photo.badge.exclamationmark",
                    title: "이미지를 불러올 수 없습니다",
                    message: "저장된 원본 파일을 찾을 수 없습니다."
                )
                .padding(.horizontal, Tokens.screenX)
            }

            VStack {
                HStack {
                    if sources.count > 1 {
                        Text("\(selectedIndex + 1)/\(sources.count)")
                            .font(Tokens.bodyBold)
                            .foregroundStyle(Tokens.textPrimary)
                            .frame(minHeight: Tokens.touchTarget)
                            .padding(.horizontal, Tokens.cardPad)
                            .background(
                                RoundedRectangle(cornerRadius: Tokens.radiusChip, style: .continuous)
                                    .fill(Tokens.bgCard.opacity(0.92))
                            )
                    }
                    Spacer()
                    UtilityIconButton(label: "닫기", systemImage: "xmark") {
                        dismiss()
                    }
                    .background(
                        Circle()
                            .fill(Tokens.bgCard.opacity(0.92))
                    )
                }
                Spacer()
                if sources.count > 1 {
                    imagePicker
                }
            }
            .padding(.horizontal, Tokens.screenX)
            .padding(.top, Tokens.screenTop)
            .padding(.bottom, Tokens.bottomSafe)
        }
        .statusBarHidden(true)
    }

    private var imagePicker: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: Tokens.rowGap) {
                ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                    let selected = source.id == selectedID
                    Button {
                        selectedID = source.id
                    } label: {
                        Image(uiImage: ClipImageResolver.thumbnail(for: source, maxPixelSize: 160)
                              ?? ClipImageResolver.image(for: source))
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(
                                cornerRadius: Tokens.radiusThumbnail,
                                style: .continuous
                            ))
                            .overlay {
                                RoundedRectangle(cornerRadius: Tokens.radiusThumbnail, style: .continuous)
                                    .strokeBorder(
                                        selected ? Tokens.accentYellow : Tokens.borderSoft,
                                        lineWidth: selected ? 3 : Tokens.borderChipWidth
                                    )
                            }
                            .frame(minWidth: Tokens.touchTarget, minHeight: Tokens.touchTarget)
                    }
                    .buttonStyle(ResponsivePressButtonStyle())
                    .accessibilityLabel(L10n.format(
                        "format.image_position",
                        index + 1,
                        sources.count,
                        source.displayName
                    ))
                    .accessibilityValue(L10n.text(
                        selected ? "선택됨" : "선택 안 됨",
                        locale: locale
                    ))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
        .frame(height: 64)
    }
}

/// UIKit의 검증된 스크롤 물리를 사용해 핀치·팬·관성·중단 가능한 줌을 함께 제공한다.
private struct ZoomableClipImage: UIViewRepresentable {
    let image: UIImage
    let reduceMotion: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(image: image, reduceMotion: reduceMotion)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.bouncesZoom = true
        scrollView.decelerationRate = .fast
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = context.coordinator.imageView
        scrollView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        context.coordinator.scrollView = scrollView
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.imageView.image = image
        context.coordinator.reduceMotion = reduceMotion
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let imageView: UIImageView
        weak var scrollView: UIScrollView?
        var reduceMotion: Bool

        init(image: UIImage, reduceMotion: Bool) {
            self.imageView = UIImageView(image: image)
            self.reduceMotion = reduceMotion
            super.init()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFit
            imageView.isUserInteractionEnabled = true
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: !reduceMotion)
                return
            }

            let targetScale = min(2.5, scrollView.maximumZoomScale)
            let point = recognizer.location(in: imageView)
            let size = CGSize(
                width: scrollView.bounds.width / targetScale,
                height: scrollView.bounds.height / targetScale
            )
            let zoomRect = CGRect(
                x: point.x - size.width / 2,
                y: point.y - size.height / 2,
                width: size.width,
                height: size.height
            )
            scrollView.zoom(to: zoomRect, animated: !reduceMotion)
        }
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
                                  value: L10n.format("format.folder_clip_count", store.folderCount(folder.label)),
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
                Label {
                    Text(L10n.format("format.move_to_folder", L10n.text(destination)))
                } icon: {
                    Image(systemName: "checkmark")
                }
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
            memo = clip.memo ?? ""
            tags = clip.tags
        }
        .sheet(isPresented: $showTagEditor) {
            TagEditorSheet(tags: $tags).workflowSheet(.standard)
        }
    }
}
