import SwiftUI

/// 인박스 클립 카드: 전체가 상세 진입 히트 타깃이고, 메뉴 버튼만 독립 컨트롤이다.
struct ClipCardView: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let clip: Clip
    var onMenu: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            NavigationLink(value: Route.detail(clip.id)) {
                navigationContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.format("format.clip_detail_accessibility", L10n.text(clip.title, locale: locale)))

            Button(action: onMenu) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.textPrimary)
                    .frame(width: Tokens.touchTarget, height: Tokens.touchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.format("format.clip_menu_accessibility", L10n.text(clip.title, locale: locale)))
        }
        .padding(.vertical, Tokens.cardPad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Tokens.borderSoft.frame(height: Tokens.borderChipWidth)
        }
    }

    private var navigationContent: some View {
        HStack(alignment: .center, spacing: Tokens.cardGap) {
            VStack(alignment: .leading, spacing: Tokens.space1) {
                Text(L10n.text(clip.title, locale: locale))
                    .font(Tokens.cardTitle)
                    .foregroundStyle(Tokens.textPrimary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                    .multilineTextAlignment(.leading)
                Text(L10n.text(clip.source, locale: locale))
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
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let clip: Clip
    var onOpen: () -> Void = {}

    var body: some View {
        NavigationLink(value: Route.detail(clip.id)) {
            HStack(alignment: .center, spacing: Tokens.cardGap) {
                VStack(alignment: .leading, spacing: Tokens.space1) {
                    Text(L10n.text(clip.title, locale: locale))
                        .font(Tokens.bodySemibold)
                        .foregroundStyle(Tokens.textPrimary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                    Text(L10n.text(clip.source, locale: locale))
                        .font(Tokens.meta)
                        .foregroundStyle(Tokens.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: Tokens.rowGap)
                if clip.hasImageReference {
                    ClipThumbnail(clip: clip, compact: true)
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
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded(onOpen))
    }
}
