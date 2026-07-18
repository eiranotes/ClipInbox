import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ClipPasteboardPayload: Equatable, Sendable {
    let typeIdentifier: String
    let data: Data
}

enum ClipAttachmentPasteboardError: Error {
    case unreadable
}

/// 원본 파일을 전부 읽고 검증한 뒤 한 번에 pasteboard를 교체한다.
/// 중간 실패 시 기존 클립보드는 건드리지 않는다.
enum ClipAttachmentPasteboard {
    static func prepareImageSources(_ sources: [ClipImageSource]) throws -> [ClipPasteboardPayload] {
        try sources.map { source in
            if let fileURL = source.fileURL {
                let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
                guard !data.isEmpty else { throw ClipAttachmentPasteboardError.unreadable }
                return ClipPasteboardPayload(
                    typeIdentifier: imageTypeIdentifier(
                        preferred: source.typeIdentifier,
                        fileExtension: fileURL.pathExtension
                    ),
                    data: data
                )
            }
            guard let assetName = source.assetName,
                  let data = UIImage(named: assetName)?.pngData() else {
                throw ClipAttachmentPasteboardError.unreadable
            }
            return ClipPasteboardPayload(typeIdentifier: UTType.png.identifier, data: data)
        }
    }

    static func prepareAttachments(_ items: [ClipStoredAttachment]) throws -> [ClipPasteboardPayload] {
        try items.map { item in
            guard let url = item.url else { throw ClipAttachmentPasteboardError.unreadable }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard !data.isEmpty else { throw ClipAttachmentPasteboardError.unreadable }
            let type = item.attachment.typeIdentifier.flatMap { UTType($0) }
                ?? UTType(filenameExtension: url.pathExtension)
                ?? .data
            return ClipPasteboardPayload(typeIdentifier: type.identifier, data: data)
        }
    }

    static func selectedAttachments(
        from items: [ClipStoredAttachment],
        selectedIDs: Set<UUID>
    ) -> [ClipStoredAttachment] {
        items.filter { selectedIDs.contains($0.id) }
    }

    @MainActor
    static func write(_ payloads: [ClipPasteboardPayload]) {
        UIPasteboard.general.setItems(payloads.map { [$0.typeIdentifier: $0.data] })
    }

    private static func imageTypeIdentifier(preferred: String?, fileExtension: String) -> String {
        if let preferred,
           let type = UTType(preferred),
           type.conforms(to: .image) {
            return type.identifier
        }
        if let type = UTType(filenameExtension: fileExtension), type.conforms(to: .image) {
            return type.identifier
        }
        return UTType.image.identifier
    }
}

struct ClipImageGallery: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let sources: [ClipImageSource]
    let height: CGFloat
    var onOpen: ((Int) -> Void)?

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: Tokens.rowGap) {
                ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                    if let onOpen {
                        Button { onOpen(index) } label: {
                            galleryImage(source, index: index)
                        }
                        .buttonStyle(ResponsivePressButtonStyle())
                    } else {
                        galleryImage(source, index: index)
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .accessibilityElement(children: .contain)
    }

    private func galleryImage(_ source: ClipImageSource, index: Int) -> some View {
        let width = dynamicTypeSize.isAccessibilitySize ? 240.0 : 180.0
        return Color.clear
            .overlay {
                Image(uiImage: ClipImageResolver.thumbnail(for: source, maxPixelSize: 640)
                      ?? ClipImageResolver.image(for: source))
                    .resizable()
                    .scaledToFit()
            }
            .background(Tokens.bgCardMuted)
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.radiusThumbnail, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                Text("\(index + 1)/\(sources.count)")
                    .font(Tokens.chip)
                    .foregroundStyle(Tokens.textPrimary)
                    .padding(.horizontal, Tokens.rowGap)
                    .frame(minHeight: Tokens.touchTarget)
                    .background(Tokens.bgCard.opacity(0.92))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.radiusThumbnail, style: .continuous)
                    .strokeBorder(Tokens.borderSoft, lineWidth: Tokens.borderChipWidth)
            }
            .contentShape(Rectangle())
            .accessibilityLabel(L10n.format(
                "format.image_position",
                index + 1,
                sources.count,
                source.displayName
            ))
            .accessibilityHint(onOpen == nil ? "" : L10n.text("이미지 크게 보기", locale: locale))
    }
}

struct ClipAttachmentDetailSection: View {
    @Environment(\.locale) private var locale

    let attachments: [ClipStoredAttachment]
    @Binding var selectedIDs: Set<UUID>
    @Binding var isSelecting: Bool
    let isCopying: Bool
    let onOpenImage: (UUID) -> Void
    let onCopyAll: () -> Void
    let onCopySelected: () -> Void

    private var allSelected: Bool {
        let available = attachments.filter { $0.url != nil }
        return !available.isEmpty && available.allSatisfy { selectedIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.rowGap) {
            HStack(spacing: Tokens.rowGap) {
                Text(L10n.format("format.attachment_count", attachments.count))
                    .font(Tokens.sectionTitle)
                    .foregroundStyle(Tokens.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Tokens.rowGap)
                Button(isSelecting ? "완료" : "선택") {
                    isSelecting.toggle()
                    if !isSelecting { selectedIDs.removeAll() }
                }
                .font(Tokens.bodySemibold)
                .foregroundStyle(Tokens.textPrimary)
                .frame(minWidth: Tokens.touchTarget, minHeight: Tokens.touchTarget)
                .buttonStyle(ResponsivePressButtonStyle())
            }

            VStack(spacing: 0) {
                ForEach(Array(attachments.enumerated()), id: \.element.id) { index, item in
                    attachmentRow(item)
                    if index < attachments.count - 1 { RowDivider() }
                }
            }
            .padding(.horizontal, Tokens.cardPad)
            .tokenSurface(fill: Tokens.bgCardMuted, radius: Tokens.radiusInput)

            if isSelecting {
                HStack(spacing: Tokens.rowGap) {
                    Button(allSelected ? "전체 해제" : "전체 선택") {
                        if allSelected {
                            selectedIDs.removeAll()
                        } else {
                            selectedIDs = Set(attachments.filter { $0.url != nil }.map(\.id))
                        }
                    }
                    .buttonStyle(SecondaryBoxButtonStyle())

                    Button(action: onCopySelected) {
                        copyLabel(key: "format.copy_selected_attachments", count: selectedIDs.count)
                    }
                    .buttonStyle(PrimaryBoxButtonStyle())
                    .disabled(selectedIDs.isEmpty || isCopying)
                    .opacity(selectedIDs.isEmpty || isCopying ? 0.56 : 1)
                }
            } else {
                Button(action: onCopyAll) {
                    copyLabel(key: "format.copy_all_attachments", count: attachments.count)
                }
                .buttonStyle(SecondaryBoxButtonStyle())
                .disabled(isCopying)
            }
        }
    }

    @ViewBuilder
    private func copyLabel(key: String, count: Int) -> some View {
        if isCopying {
            HStack(spacing: Tokens.rowGap) {
                ProgressView().tint(Tokens.textPrimary)
                Text("복사 중…")
            }
        } else {
            Label(L10n.format(key, count), systemImage: "doc.on.doc")
        }
    }

    @ViewBuilder
    private func attachmentRow(_ item: ClipStoredAttachment) -> some View {
        let isSelected = selectedIDs.contains(item.id)
        if item.url != nil, isSelecting || item.attachment.kind == .image {
            Button {
                if isSelecting {
                    if isSelected { selectedIDs.remove(item.id) } else { selectedIDs.insert(item.id) }
                } else {
                    onOpenImage(item.id)
                }
            } label: {
                attachmentRowLabel(item, isSelected: isSelected)
            }
            .buttonStyle(ResponsivePressButtonStyle())
            .accessibilityValue(isSelecting
                                ? L10n.text(isSelected ? "선택됨" : "선택 안 됨", locale: locale)
                                : "")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            attachmentRowLabel(item, isSelected: false)
        }
    }

    private func attachmentRowLabel(_ item: ClipStoredAttachment, isSelected: Bool) -> some View {
        HStack(spacing: Tokens.cardGap) {
            Image(systemName: isSelecting
                  ? (isSelected ? "checkmark.circle.fill" : "circle")
                  : (item.attachment.kind == .image ? "photo" : "doc"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isSelected ? Tokens.onAccent : Tokens.textSecondary)
                .frame(width: Tokens.iconColumn, height: Tokens.touchTarget)
                .background(isSelected ? Tokens.accentYellow : .clear)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: Tokens.space1) {
                Text(item.attachment.originalFileName)
                    .font(Tokens.bodySemibold)
                    .foregroundStyle(Tokens.textPrimary)
                    .lineLimit(2)
                Text(item.url == nil
                     ? L10n.text("원본 파일 없음", locale: locale)
                     : ByteCountFormatter.string(
                        fromByteCount: item.attachment.byteCount,
                        countStyle: .file
                     ))
                .font(Tokens.meta)
                .foregroundStyle(Tokens.textSecondary)
            }
            Spacer(minLength: Tokens.rowGap)
            if !isSelecting, item.attachment.kind == .image {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.textTertiary)
            }
        }
        .frame(minHeight: Tokens.actionTarget)
        .contentShape(Rectangle())
        .accessibilityLabel(item.attachment.originalFileName)
        .accessibilityHint(!isSelecting && item.attachment.kind == .image
                           ? L10n.text("이미지 크게 보기", locale: locale)
                           : "")
    }
}
