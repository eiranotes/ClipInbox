import Foundation
import SwiftUI

/// 인박스 클립 카드: 전체가 상세 진입 히트 타깃이고, 메뉴 버튼만 독립 컨트롤이다.
struct ClipCardView: View {
    // CLIPINBOX_URL_METADATA_ENGINE_V1
    @Environment(URLMetadataCoordinator.self) private var metadata
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let clip: Clip
    var selectionState: Bool?
    var onSelectionToggle: () -> Void
    var onMenu: () -> Void

    init(
        clip: Clip,
        selectionState: Bool? = nil,
        onSelectionToggle: @escaping () -> Void = {},
        onMenu: @escaping () -> Void
    ) {
        self.clip = clip
        self.selectionState = selectionState
        self.onSelectionToggle = onSelectionToggle
        self.onMenu = onMenu
    }

    var body: some View {
        Group {
            if let selectionState {
                Button(action: onSelectionToggle) {
                    HStack(alignment: .center, spacing: 0) {
                        selectionIndicator(isSelected: selectionState)
                        navigationContent
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(ResponsivePressButtonStyle())
                .accessibilityLabel(L10n.text(metadata.cardTitle(for: clip, locale: locale), locale: locale))
                .accessibilityValue(selectionState ? L10n.text("선택됨", locale: locale) : L10n.text("선택 안 됨", locale: locale))
                .accessibilityHint(selectionState
                    ? L10n.text("선택 해제하려면 이중 탭", locale: locale)
                    : L10n.text("선택하려면 이중 탭", locale: locale))
                .accessibilityAddTraits(selectionState ? .isSelected : [])
            } else {
                HStack(alignment: .center, spacing: 0) {
                    NavigationLink(value: Route.detail(clip.id)) {
                        navigationContent
                    }
                    .buttonStyle(ResponsivePressButtonStyle())
                    .accessibilityLabel(L10n.format("format.clip_detail_accessibility", L10n.text(metadata.cardTitle(for: clip, locale: locale), locale: locale)))

                    Button(action: onMenu) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Tokens.textPrimary)
                            .frame(width: Tokens.touchTarget, height: Tokens.touchTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ResponsivePressButtonStyle(pressedScale: 0.9))
                    .accessibilityLabel(L10n.format("format.clip_menu_accessibility", L10n.text(metadata.cardTitle(for: clip, locale: locale), locale: locale)))
                }
            }
        }
        .padding(.vertical, Tokens.cardPad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Tokens.borderSoft.frame(height: Tokens.borderChipWidth)
        }
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSelected ? Tokens.accentYellow : Tokens.bgCard)
            Circle()
                .strokeBorder(
                    isSelected ? Tokens.accentYellow : Tokens.borderSoft,
                    lineWidth: Tokens.borderCardWidth
                )
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Tokens.onAccent)
            }
        }
        .frame(width: 22, height: 22)
        .frame(width: Tokens.touchTarget, height: Tokens.touchTarget)
        .accessibilityHidden(true)
    }

    private var navigationContent: some View {
        HStack(alignment: .center, spacing: Tokens.cardGap) {
            VStack(alignment: .leading, spacing: Tokens.space1) {
                Text(L10n.text(metadata.cardTitle(for: clip, locale: locale), locale: locale))
                    .font(Tokens.cardTitle)
                    .foregroundStyle(Tokens.textPrimary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                    .multilineTextAlignment(.leading)
                Text(L10n.text(metadata.cardSummary(for: clip, locale: locale) ?? clip.source, locale: locale))
                    .font(Tokens.meta)
                    .foregroundStyle(Tokens.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            if clip.hasImageReference {
                ClipThumbnail(clip: clip, compact: true)
                    .frame(width: Tokens.clipThumbnailWidth, height: Tokens.clipThumbnailHeight)
                    .fixedSize()
            } else if let thumbnailURL = metadata.cardPresentation(for: clip, locale: locale)?.thumbnailURL.flatMap(URL.init(string:)) {
                MetadataRemoteImage(url: thumbnailURL)
                    .frame(width: Tokens.clipThumbnailWidth, height: Tokens.clipThumbnailHeight)
                    .fixedSize()
            } else if clip.type == .link, metadata.result(for: clip.id) == nil {
                MetadataThumbnailPlaceholder(isLoading: metadata.isAnalyzing(clip.id))
                    .frame(width: Tokens.clipThumbnailWidth, height: Tokens.clipThumbnailHeight)
                    .fixedSize()
            }
        }
        .padding(.leading, Tokens.space1)
        .padding(.trailing, Tokens.space1)
        .frame(minHeight: Tokens.clipRowContentHeight)
        .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : Tokens.clipRowContentHeight)
        .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// 검색 결과·폴더 상세에서 쓰는 컴팩트 행.
struct CompactResultRow: View {
    @Environment(URLMetadataCoordinator.self) private var metadata
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let clip: Clip
    var onOpen: () -> Void = {}

    var body: some View {
        NavigationLink(value: Route.detail(clip.id)) {
            HStack(alignment: .center, spacing: Tokens.cardGap) {
                VStack(alignment: .leading, spacing: Tokens.space1) {
                    Text(L10n.text(metadata.cardTitle(for: clip, locale: locale), locale: locale))
                        .font(Tokens.bodySemibold)
                        .foregroundStyle(Tokens.textPrimary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                    Text(L10n.text(metadata.cardSummary(for: clip, locale: locale) ?? clip.source, locale: locale))
                        .font(Tokens.meta)
                        .foregroundStyle(Tokens.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: Tokens.rowGap)
                if clip.hasImageReference {
                    ClipThumbnail(clip: clip, compact: true)
                        .frame(width: Tokens.resultThumbnailWidth, height: Tokens.resultThumbnailHeight)
                } else if let thumbnailURL = metadata.cardPresentation(for: clip, locale: locale)?.thumbnailURL.flatMap(URL.init(string:)) {
                    MetadataRemoteImage(url: thumbnailURL)
                        .frame(width: Tokens.resultThumbnailWidth, height: Tokens.resultThumbnailHeight)
                } else if clip.type == .link, metadata.result(for: clip.id) == nil {
                    MetadataThumbnailPlaceholder(isLoading: metadata.isAnalyzing(clip.id))
                        .frame(width: Tokens.resultThumbnailWidth, height: Tokens.resultThumbnailHeight)
                }
            }
            .frame(minHeight: Tokens.resultRowContentHeight)
            .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : Tokens.resultRowContentHeight)
            .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
            .padding(.vertical, Tokens.cardPad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Tokens.borderSoft.frame(height: Tokens.borderChipWidth)
            }
        }
        .buttonStyle(ResponsivePressButtonStyle())
        .simultaneousGesture(TapGesture().onEnded(onOpen))
    }
}
