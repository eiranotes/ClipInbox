import SwiftUI
import UIKit

enum ClipDetailCopyKind: Equatable {
    case link
    case image

    static func resolve(for clip: Clip) -> Self? {
        switch clip.type {
        case .image, .screenshot:
            return clip.hasImageReference ? .image : nil
        case .link, .memo, .file:
            return clip.url.isEmpty ? nil : .link
        }
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
    var onOpenImage: (() -> Void)?

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
                    Image(systemName: "globe").font(.system(size: 12, weight: .bold))
                    Text(L10n.text(presentation?.subtitle ?? clip.source, locale: locale))
                }
                Spacer()
                Text(L10n.text(clip.time, locale: locale))
            }
            .font(Tokens.meta)
            .foregroundStyle(Tokens.textSecondary)

            if clip.hasImageReference {
                if let onOpenImage {
                    Button(action: onOpenImage) {
                        localImage
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ResponsivePressButtonStyle())
                    .accessibilityLabel("이미지 크게 보기")
                } else {
                    localImage
                }
            } else if let thumbnailURL = presentation?.thumbnailURL.flatMap(URL.init(string:)) {
                MetadataRemoteImage(url: thumbnailURL, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: resolvedImageHeight)
            }

            if clip.attachments.count > 1 || clip.attachments.contains(where: { $0.kind == .file }) {
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
    @State private var noteDraft = ""
    @State private var noteDirty = false

    var body: some View {
        if let clip = store.clip(id: clipID) {
            ScreenScaffold(additionalBottomPadding: Tokens.bottomNavigationClearance) {
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

                ClipDetailOverview(clip: clip) {
                    showImageViewer = true
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
                                Label("복사하기", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(SecondaryBoxButtonStyle())
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
                        Button("저장", action: saveNote)
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
                        showMove = true
                    }
                    organizeRow(label: "태그",
                                value: clip.tags.isEmpty ? "없음" : clip.tags
                                    .map { L10n.text($0, locale: locale) }
                                    .joined(separator: " · "),
                                systemImage: "tag") {
                        tagDraft = clip.tags
                        showTagEdit = true
                    }
                }

                VStack(spacing: Tokens.cardGap) {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: Tokens.rowGap) {
                            quietAction(label: "이동", systemImage: "folder") { showMove = true }
                            quietAction(label: "편집", systemImage: "pencil") { showEdit = true }
                            quietAction(label: "삭제", systemImage: "trash", isDanger: true) {
                                showDeleteConfirm = true
                            }
                        }
                    } else {
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
            }
            .sheet(isPresented: $showShare) { ShareOptionsSheet(clipID: clip.id).workflowSheet(.standard) }
            .sheet(isPresented: $showMore) { CardActionsSheet(clipID: clip.id).workflowSheet(.expanded) }
            .sheet(isPresented: $showMove) { MoveFolderSheet(clipID: clip.id).workflowSheet(.expanded) }
            .sheet(isPresented: $showEdit) { EditClipSheet(clipID: clip.id).workflowSheet(.expanded) }
            .sheet(isPresented: $showTagEdit, onDismiss: { store.updateTags(id: clipID, tags: tagDraft) }) {
                TagEditorSheet(tags: $tagDraft).workflowSheet(.standard)
            }
            .fullScreenCover(isPresented: $showImageViewer) {
                ClipImageViewer(clip: clip)
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
                    store.deleteClip(id: clip.id)
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
            guard let image = ClipImageResolver.originalImage(for: clip) else {
                store.showToast("이미지를 복사할 수 없습니다", semantic: .error)
                return
            }
            UIPasteboard.general.image = image
            store.showToast("이미지를 복사했습니다")
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
    let clip: Clip

    var body: some View {
        ZStack {
            Tokens.bgApp.ignoresSafeArea()
            ZoomableClipImage(
                image: ClipImageResolver.image(for: clip),
                reduceMotion: reduceMotion
            )
            .padding(.horizontal, Tokens.screenX)
            .accessibilityLabel("확대 가능한 클립 이미지")
            .accessibilityHint("두 번 탭하거나 두 손가락으로 확대하고 드래그해 이동합니다")

            VStack {
                HStack {
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
            }
            .padding(.horizontal, Tokens.screenX)
            .padding(.top, Tokens.screenTop)
        }
        .statusBarHidden(true)
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
            memo = clip.memo?.isEmpty == false ? clip.memo! : clip.description
            tags = clip.tags
        }
        .sheet(isPresented: $showTagEditor) {
            TagEditorSheet(tags: $tags).workflowSheet(.standard)
        }
    }
}
