import SwiftUI
import UIKit
import ImageIO

// MARK: - 배지

enum BadgeTone {
    case type(ClipType)
    case state(ClipState)

    var dotColor: Color {
        switch self {
        case .type: return Tokens.accentBlue
        case .state(.unsorted), .state(.new): return Tokens.accentYellow
        case .state(.saved): return Tokens.accentGreen
        }
    }

    var label: String {
        switch self {
        case .type(let type): return type.label
        case .state(let state): return state.label
        }
    }
}

struct TokenBadge: View {
    @Environment(\.locale) private var locale
    let tone: BadgeTone

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(tone.dotColor).frame(width: 7, height: 7)
            Text(L10n.text(tone.label, locale: locale))
        }
        .font(Tokens.chip)
        .foregroundStyle(Tokens.textPrimary)
        .padding(.vertical, 2)
    }
}

// MARK: - 선택 컨트롤

/// 한 줄에 동일 너비 다섯 칸, 두 줄을 보여 주는 공통 텍스트 선택기.
/// 열 개가 넘는 항목은 같은 5x2 리듬을 유지한 채 가로로 이어진다.
struct TwoRowHorizontalSelection: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    typealias SelectionItem = (label: String, active: Bool, action: () -> Void)

    private struct SelectionSlot: Identifiable {
        let id: Int
        let item: SelectionItem?
    }

    let items: [SelectionItem]
    let rowCount: Int
    /// 윗줄과 아랫줄이 서로 다른 의미를 가질 때(예: 인박스의 폴더/태그 필터)
    /// 각 줄을 독립적으로 유지한 채 같은 5열 리듬으로 배치한다.
    private let pairedRows: (
        top: [SelectionItem],
        bottom: [SelectionItem],
        topLabel: String,
        bottomLabel: String
    )?

    init(items: [SelectionItem], rowCount: Int = Tokens.selectionRowCount) {
        self.items = items
        self.rowCount = rowCount
        self.pairedRows = nil
    }

    init(
        topRow: [SelectionItem],
        bottomRow: [SelectionItem],
        topLabel: String = "폴더",
        bottomLabel: String = "태그"
    ) {
        self.items = topRow + bottomRow
        self.rowCount = 2
        self.pairedRows = (topRow, bottomRow, topLabel, bottomLabel)
    }

    private var gridSlots: [SelectionSlot] {
        let columnCount = Tokens.selectionColumnCount
        let pageSize = columnCount * rowCount
        var slots: [SelectionSlot] = []

        for pageStart in stride(from: 0, to: items.count, by: pageSize) {
            let pageEnd = min(pageStart + pageSize, items.count)
            let page = Array(items[pageStart..<pageEnd])

            // LazyHGrid는 열 단위로 채우므로 입력을 행 우선 순서에서 열 우선 순서로 바꾼다.
            for column in 0..<columnCount {
                for row in 0..<rowCount {
                    let pageIndex = row * columnCount + column
                    let item = page.indices.contains(pageIndex) ? page[pageIndex] : nil
                    slots.append(SelectionSlot(id: slots.count, item: item))
                }
            }
        }
        return slots
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilitySelection
            } else {
                standardSelection
            }
        }
    }

    private var standardSelection: some View {
        GeometryReader { geometry in
            let rowLabelWidth: CGFloat = pairedRows == nil ? 0 : 32
            let rowLabelGap: CGFloat = pairedRows == nil ? 0 : Tokens.rowGap
            let selectionWidth = max(0, geometry.size.width - rowLabelWidth - rowLabelGap)
            let gaps = Tokens.chipGap * CGFloat(Tokens.selectionColumnCount - 1)
            let columnWidth = max(
                Tokens.touchTarget,
                (selectionWidth - gaps) / CGFloat(Tokens.selectionColumnCount)
            )
            if let pairedRows {
                VStack(spacing: Tokens.chipGap) {
                    labeledSelectionRow(
                        pairedRows.top, label: pairedRows.topLabel,
                        columnWidth: columnWidth, minimumWidth: selectionWidth,
                        labelWidth: rowLabelWidth
                    )
                    labeledSelectionRow(
                        pairedRows.bottom, label: pairedRows.bottomLabel,
                        columnWidth: columnWidth, minimumWidth: selectionWidth,
                        labelWidth: rowLabelWidth
                    )
                }
            } else {
                let rows = Array(
                    repeating: GridItem(.fixed(Tokens.touchTarget), spacing: Tokens.chipGap),
                    count: rowCount
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: rows, spacing: Tokens.chipGap) {
                        ForEach(gridSlots) { slot in
                            if let item = slot.item {
                                selectionButton(item)
                                    .frame(width: columnWidth, height: Tokens.touchTarget)
                            } else {
                                Color.clear
                                    .frame(width: columnWidth, height: Tokens.touchTarget)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .frame(minWidth: geometry.size.width, alignment: .leading)
                }
            }
        }
        .frame(height: Tokens.touchTarget * CGFloat(rowCount)
            + Tokens.chipGap * CGFloat(rowCount - 1))
    }

    private func labeledSelectionRow(
        _ rowItems: [SelectionItem],
        label: String,
        columnWidth: CGFloat,
        minimumWidth: CGFloat,
        labelWidth: CGFloat
    ) -> some View {
        HStack(spacing: Tokens.rowGap) {
            Text(L10n.text(label, locale: locale))
                .font(Tokens.nav)
                .foregroundStyle(Tokens.textSecondary)
                .frame(width: labelWidth, alignment: .leading)
                .accessibilityHidden(true)
            independentSelectionRow(
                rowItems,
                columnWidth: columnWidth,
                minimumWidth: minimumWidth,
                accessibilityContext: label
            )
        }
    }

    /// 의미가 다른 두 줄은 각각 별도 ScrollView를 가져 스크롤 위치를 공유하지 않는다.
    private func independentSelectionRow(
        _ rowItems: [SelectionItem],
        columnWidth: CGFloat,
        minimumWidth: CGFloat,
        accessibilityContext: String? = nil
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: Tokens.chipGap) {
                ForEach(Array(rowItems.enumerated()), id: \.offset) { _, item in
                    selectionButton(item, accessibilityContext: accessibilityContext)
                        .frame(width: columnWidth, height: Tokens.touchTarget)
                }
            }
            .frame(minWidth: minimumWidth, alignment: .leading)
        }
        .frame(height: Tokens.touchTarget)
    }

    private var accessibilitySelection: some View {
        Group {
            if let pairedRows {
                VStack(spacing: 0) {
                    accessibilitySelectionMenu(label: pairedRows.topLabel, items: pairedRows.top)
                    accessibilitySelectionMenu(label: pairedRows.bottomLabel, items: pairedRows.bottom)
                }
            } else {
                accessibilitySelectionRows(items, context: nil)
            }
        }
    }

    private func accessibilitySelectionMenu(
        label: String,
        items: [SelectionItem]
    ) -> some View {
        let activeLabel = items.first(where: { $0.active })?.label ?? items.first?.label ?? "없음"
        return Menu {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Button(action: item.action) {
                    if item.active {
                        Label(L10n.text(item.label, locale: locale), systemImage: "checkmark")
                    } else {
                        Text(L10n.text(item.label, locale: locale))
                    }
                }
            }
        } label: {
            HStack(spacing: Tokens.cardGap) {
                Text(L10n.text(label, locale: locale))
                    .font(Tokens.bodyBold)
                    .foregroundStyle(Tokens.textPrimary)
                Spacer(minLength: Tokens.rowGap)
                Text(L10n.text(activeLabel, locale: locale))
                    .font(Tokens.bodySemibold)
                    .foregroundStyle(Tokens.textSecondary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Tokens.textTertiary)
            }
            .frame(maxWidth: .infinity, minHeight: Tokens.actionTarget)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Tokens.borderSoft.frame(height: Tokens.borderChipWidth)
            }
        }
        .buttonStyle(ResponsivePressButtonStyle())
        .accessibilityLabel("\(L10n.text(label, locale: locale)): \(L10n.text(activeLabel, locale: locale))")
    }

    private func accessibilitySelectionRows(
        _ rowItems: [SelectionItem],
        context: String?
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rowItems.enumerated()), id: \.offset) { _, item in
                Button(action: item.action) {
                    HStack(spacing: Tokens.cardGap) {
                        Text(L10n.text(item.label, locale: locale))
                            .font(Tokens.bodySemibold)
                            .foregroundStyle(Tokens.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: Tokens.rowGap)
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .opacity(item.active ? 1 : 0)
                    }
                    .padding(.vertical, Tokens.rowGap)
                    .frame(maxWidth: .infinity, minHeight: Tokens.actionTarget, alignment: .leading)
                    .contentShape(Rectangle())
                    .overlay(alignment: .bottom) {
                        Tokens.borderSoft.frame(height: Tokens.borderChipWidth)
                    }
                }
                .buttonStyle(ResponsivePressButtonStyle())
                .accessibilityAddTraits(item.active ? .isSelected : [])
                .accessibilityLabel(accessibilityLabel(for: item, context: context))
            }
        }
    }

    private func selectionButton(
        _ item: SelectionItem,
        accessibilityContext: String? = nil
    ) -> some View {
        Button(action: item.action) {
            Text(L10n.text(item.label, locale: locale))
                .font(Tokens.chip)
                .foregroundStyle(item.active ? Tokens.textPrimary : Tokens.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(Tokens.selectionTextMinimumScale)
                .allowsTightening(true)
                .padding(.horizontal, Tokens.space1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(item.active ? Tokens.accentYellow : Tokens.borderSoft)
                        .frame(height: item.active ? Tokens.selectionIndicator : Tokens.borderChipWidth)
                }
        }
        .buttonStyle(ResponsivePressButtonStyle())
        .accessibilityAddTraits(item.active ? .isSelected : [])
        .accessibilityLabel(accessibilityLabel(for: item, context: accessibilityContext))
    }

    private func accessibilityLabel(for item: SelectionItem, context: String?) -> String {
        let itemLabel = L10n.text(item.label, locale: locale)
        guard let context else { return itemLabel }
        return "\(L10n.text(context, locale: locale)): \(itemLabel)"
    }
}

/// 태그와 단일 선택값을 위한 평면 행. 선택은 박스 채움 대신 체크 표시로만 구분한다.
struct PlainSelectionRow: View {
    @Environment(\.locale) private var locale
    let label: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.cardGap) {
                Text(L10n.text(label, locale: locale))
                    .font(Tokens.bodySemibold)
                    .foregroundStyle(Tokens.textPrimary)
                Spacer(minLength: Tokens.rowGap)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Tokens.textPrimary)
                    .opacity(isSelected ? 1 : 0)
            }
            .frame(minHeight: Tokens.actionTarget)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Tokens.borderSoft.frame(height: Tokens.borderChipWidth)
            }
        }
        .buttonStyle(ResponsivePressButtonStyle())
    }
}

/// 폴더·설정 목적지 목록이 함께 쓰는 행 사이 구분선. 아이콘 열 시작(cardPad)에 맞춰 들여쓴다.
struct RowDivider: View {
    var body: some View {
        Tokens.borderSoft
            .frame(height: Tokens.borderChipWidth)
            .padding(.leading, Tokens.cardPad)
    }
}

/// 폴더와 설정처럼 목적지로 이동하는 목록 행의 공통 아이콘 기준선.
struct DestinationRow: View {
    @Environment(\.locale) private var locale
    let systemImage: String
    let title: String
    var value = ""
    var trailingSystemImage = "chevron.right"

    var body: some View {
        HStack(spacing: Tokens.cardGap) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Tokens.textPrimary)
                .frame(width: Tokens.iconColumn, height: Tokens.destinationIcon)
            Text(L10n.text(title, locale: locale))
                .font(Tokens.bodySemibold)
                .foregroundStyle(Tokens.textPrimary)
            Spacer(minLength: Tokens.rowGap)
            if !value.isEmpty {
                Text(L10n.text(value, locale: locale))
                    .font(Tokens.meta)
                    .foregroundStyle(Tokens.textSecondary)
                    .lineLimit(1)
            }
            Image(systemName: trailingSystemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Tokens.textTertiary)
        }
        .padding(.horizontal, Tokens.cardPad)
        .frame(minHeight: Tokens.actionTarget)
        .contentShape(Rectangle())
    }
}

// MARK: - 버튼

struct PrimaryBoxButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var isDanger = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tokens.button)
            .foregroundStyle(isDanger ? Color.white : Tokens.onAccent)
            .frame(maxWidth: .infinity, minHeight: Tokens.actionTarget)
            .background(
                RoundedRectangle(cornerRadius: Tokens.radiusButton, style: .continuous)
                    .fill(isDanger ? Tokens.danger : Tokens.accentYellow)
            )
            .contentShape(RoundedRectangle(cornerRadius: Tokens.radiusButton, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: Tokens.motionFast), value: configuration.isPressed)
    }
}

struct SecondaryBoxButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var isDanger = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tokens.button)
            .foregroundStyle(isDanger ? Tokens.danger : Tokens.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Tokens.actionTarget)
            .tokenSurface(fill: Tokens.bgCard, radius: Tokens.radiusButton,
                          border: Tokens.borderSoft, borderWidth: Tokens.borderChipWidth)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: Tokens.motionFast), value: configuration.isPressed)
    }
}

/// 평면 행·아이콘·탭에도 즉시 보이는 눌림 상태를 주되 레이아웃은 바꾸지 않는다.
struct ResponsivePressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var pressedScale: CGFloat = 0.98
    var pressedOpacity: CGFloat = 0.72

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? pressedScale : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: Tokens.motionFast), value: configuration.isPressed)
    }
}

/// 상단 유틸리티 44px 아이콘 버튼.
struct UtilityIconButton: View {
    @Environment(\.locale) private var locale
    let label: String
    let systemImage: String
    var isOn = false
    var accessibilitySelectionState: Bool? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(isOn ? Tokens.onAccent : Tokens.textPrimary)
                .frame(width: Tokens.touchTarget, height: Tokens.touchTarget)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.radiusChip, style: .continuous)
                        .fill(isOn ? Tokens.accentYellow : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(ResponsivePressButtonStyle(pressedScale: 0.92))
        .accessibilityLabel(L10n.text(label, locale: locale))
        .accessibilityValue(accessibilitySelectionState.map {
            L10n.text($0 ? "선택됨" : "선택 안 됨", locale: locale)
        } ?? "")
        .accessibilityAddTraits(accessibilitySelectionState == true ? .isSelected : [])
    }
}

// MARK: - 보드 섹션

struct BoardSection<Content: View>: View {
    @Environment(\.locale) private var locale
    let title: String
    var count: Int?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.rowGap + 2) {
            HStack(spacing: Tokens.rowGap) {
                Text(L10n.text(title, locale: locale))
                    .font(Tokens.sectionTitle)
                    .foregroundStyle(Tokens.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let count {
                    Text("\(count)").font(Tokens.chip).foregroundStyle(Tokens.textSecondary)
                }
                Spacer(minLength: 0)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 액션/선택 행

struct ActionRow: View {
    @Environment(\.locale) private var locale
    let systemImage: String
    let label: String
    var value: String = ""
    var isSelected = false
    var isDanger = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.cardGap) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isDanger ? Tokens.danger : isSelected ? Tokens.onAccent : Tokens.textPrimary)
                    .frame(width: Tokens.iconColumn, height: Tokens.destinationIcon)
                Text(L10n.text(label, locale: locale))
                    .font(Tokens.bodySemibold)
                    .foregroundStyle(isDanger ? Tokens.danger : isSelected ? Tokens.onAccent : Tokens.textPrimary)
                    .layoutPriority(1)
                Spacer(minLength: Tokens.rowGap)
                if !value.isEmpty {
                    Text(L10n.text(value, locale: locale))
                        .font(Tokens.meta)
                        .foregroundStyle(Tokens.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Image(systemName: isSelected ? "checkmark" : "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isSelected ? Tokens.onAccent : Tokens.textTertiary)
            }
            .padding(.horizontal, Tokens.space1)
            .frame(minHeight: Tokens.actionTarget)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: Tokens.radiusChip, style: .continuous)
                    .fill(isSelected ? Tokens.accentYellow : .clear)
            )
            .overlay(alignment: .bottom) {
                if !isSelected { Tokens.borderSoft.frame(height: Tokens.borderChipWidth) }
            }
        }
        .buttonStyle(ResponsivePressButtonStyle())
    }
}

// MARK: - 상태 패널 / 빈 상태

struct StatePanel: View {
    @Environment(\.locale) private var locale
    let systemImage: String
    let title: String
    let message: String
    var isDanger = false
    var isAccent = false

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.cardGap) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isDanger ? Tokens.danger : isAccent ? Tokens.onAccent : Tokens.textPrimary)
                .frame(width: Tokens.iconColumn)
            VStack(alignment: .leading, spacing: Tokens.rowGap) {
                Text(L10n.text(title, locale: locale))
                    .font(Tokens.cardTitle)
                    .foregroundStyle(isAccent ? Tokens.onAccent : Tokens.textPrimary)
                Text(L10n.text(message, locale: locale))
                    .font(Tokens.meta)
                    .foregroundStyle(isAccent ? Tokens.onAccent : Tokens.textSecondary)
                    .lineSpacing(Tokens.metaLineSpacing)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

struct EmptyStateView: View {
    @Environment(\.locale) private var locale
    var systemImage = "tray"
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Tokens.rowGap) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Tokens.textTertiary)
            Text(L10n.text(title, locale: locale)).font(Tokens.cardTitle).foregroundStyle(Tokens.textPrimary)
            Text(L10n.text(message, locale: locale))
                .font(Tokens.meta)
                .foregroundStyle(Tokens.textSecondary)
                .lineSpacing(Tokens.metaLineSpacing)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(L10n.text(actionTitle, locale: locale), action: action)
                    .font(Tokens.bodySemibold)
                    .foregroundStyle(Tokens.textPrimary)
                    .frame(minWidth: Tokens.touchTarget, minHeight: Tokens.touchTarget)
                    .buttonStyle(ResponsivePressButtonStyle())
            }
        }
        .padding(.vertical, Tokens.sectionGap * 2)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 썸네일 / 도메인 폴백

/// 공유 이미지 파일을 행 렌더마다 디스크에서 다시 읽지 않도록 하는 메모리 캐시.
enum SharedImageCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 96 * 1_024 * 1_024
        return cache
    }()
    private static let thumbnailCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 32 * 1_024 * 1_024
        return cache
    }()

    static func image(at url: URL) -> UIImage? {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: key, cost: image.memoryCost)
        return image
    }

    static func thumbnail(at url: URL, maxPixelSize: CGFloat) -> UIImage? {
        let key = "\(url.path)#\(Int(maxPixelSize.rounded()))" as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize.rounded(.up)),
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        let image = UIImage(cgImage: cgImage)
        thumbnailCache.setObject(image, forKey: key, cost: image.memoryCost)
        return image
    }

    static func removeAll() {
        cache.removeAllObjects()
        thumbnailCache.removeAllObjects()
    }
}

private extension UIImage {
    var memoryCost: Int {
        guard let cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}

struct ClipThumbnail: View {
    let clip: Clip
    var compact = false
    var contentMode: ContentMode = .fill

    var body: some View {
        // aspectRatio(.fill)는 제안보다 큰 크기를 보고해 프레임 밖으로 번지므로,
        // 제안 크기를 그대로 갖는 Color.clear 위에 올려 경계에서 잘라 낸다.
        Color.clear
            .overlay(
                Image(uiImage: ClipImageResolver.image(for: clip))
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            )
            .background(Tokens.bgCardMuted)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.radiusThumbnail, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.radiusThumbnail, style: .continuous)
                    .strokeBorder(Tokens.borderSoft, lineWidth: Tokens.borderChipWidth)
            )
    }

}

enum ClipImageResolver {
    static func originalImage(for source: ClipImageSource) -> UIImage? {
        if let url = source.fileURL, let uiImage = SharedImageCache.image(at: url) {
            return uiImage
        }
        if let assetName = source.assetName, let uiImage = UIImage(named: assetName) {
            return uiImage
        }
        return nil
    }

    static func thumbnail(for source: ClipImageSource, maxPixelSize: CGFloat) -> UIImage? {
        if let url = source.fileURL,
           let image = SharedImageCache.thumbnail(at: url, maxPixelSize: maxPixelSize) {
            return image
        }
        if let assetName = source.assetName { return UIImage(named: assetName) }
        return nil
    }

    static func originalImage(for clip: Clip) -> UIImage? {
        clip.imageSources.first.flatMap(originalImage(for:))
    }

    static func image(for clip: Clip) -> UIImage {
        originalImage(for: clip) ?? UIImage(named: "clip-image-fallback") ?? UIImage()
    }

    static func image(for source: ClipImageSource) -> UIImage {
        originalImage(for: source) ?? UIImage(named: "clip-image-fallback") ?? UIImage()
    }
}

struct FallbackDomain: View {
    let source: String
    var compact = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.system(size: compact ? 16 : 22, weight: .bold))
            if !compact {
                Text(source)
                    .font(Tokens.meta)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(Tokens.textSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.bgCardMuted)
    }
}

// MARK: - 토스트

struct ToastView: View {
    @Environment(\.locale) private var locale
    let toast: AppToast

    var body: some View {
        HStack(spacing: Tokens.rowGap) {
            Image(systemName: toast.semantic.systemImage)
                .font(.system(size: 16, weight: .bold))
                .accessibilityHidden(true)
            Text(L10n.text(toast.message, locale: locale)).font(Tokens.bodyBold)
        }
        .foregroundStyle(Tokens.onAccent)
        .padding(.horizontal, Tokens.panelPad)
        .padding(.vertical, 12)
        .tokenSurface(fill: Tokens.accentYellow, radius: Tokens.radiusButton,
                      border: Tokens.borderSoft, borderWidth: Tokens.borderChipWidth)
    }
}

// MARK: - 화면 공통 스캐폴드

private struct WorkflowSheetStyleKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var usesWorkflowSheetStyle: Bool {
        get { self[WorkflowSheetStyleKey.self] }
        set { self[WorkflowSheetStyleKey.self] = newValue }
    }
}

struct ScreenScaffold<Content: View>: View {
    @Environment(\.usesWorkflowSheetStyle) private var usesWorkflowSheetStyle
    var spacing: CGFloat = Tokens.sectionGap
    var additionalBottomPadding: CGFloat = 0
    var dismissKeyboardOnBackgroundTap = true
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                content
            }
            .padding(.horizontal, Tokens.screenX)
            .padding(.top, usesWorkflowSheetStyle ? Tokens.sheetTop : Tokens.screenTop)
            .padding(.bottom, (usesWorkflowSheetStyle ? Tokens.sheetBottom : Tokens.bottomSafe)
                + additionalBottomPadding)
            .frame(maxWidth: Tokens.contentMax)
            .frame(maxWidth: .infinity)
        }
        .background(Tokens.bgApp)
        .scrollDismissesKeyboard(.interactively)
        .background {
            if dismissKeyboardOnBackgroundTap {
                KeyboardDismissInstaller()
                    .frame(width: 0, height: 0)
            }
        }
    }
}

enum WorkflowSheetSize {
    case compact
    case standard
    case expanded
}

extension View {
    func workflowSheet(_ size: WorkflowSheetSize = .standard) -> some View {
        let detents: Set<PresentationDetent> = switch size {
        case .compact: [.fraction(Tokens.sheetDetentCompact), .large]
        case .standard: [.fraction(Tokens.sheetDetentStandard), .large]
        case .expanded: [.large]
        }
        return environment(\.usesWorkflowSheetStyle, true)
            .presentationDetents(detents)
            .presentationDragIndicator(.visible)
            .presentationBackground(Tokens.bgApp)
    }

    func swipeBackFromLeadingEdge() -> some View {
        modifier(LeadingEdgeSwipeBackModifier())
    }
}

/// 화면을 떠나기 전에 로컬 편집 상태를 저장해야 하는 destination이 뒤로가기
/// 제스처와 하단 탭 전환에 같은 검증을 제공한다.
final class NavigationExitGuard {
    private var ownerID: UUID?
    private var handler: (() -> Bool)?

    func register(ownerID: UUID, handler: @escaping () -> Bool) {
        self.ownerID = ownerID
        self.handler = handler
    }

    func unregister(ownerID: UUID) {
        guard self.ownerID == ownerID else { return }
        self.ownerID = nil
        handler = nil
    }

    func attemptExit() -> Bool {
        handler?() ?? true
    }
}

private struct NavigationExitGuardKey: EnvironmentKey {
    static let defaultValue: NavigationExitGuard? = nil
}

extension EnvironmentValues {
    var navigationExitGuard: NavigationExitGuard? {
        get { self[NavigationExitGuardKey.self] }
        set { self[NavigationExitGuardKey.self] = newValue }
    }
}

private struct LeadingEdgeSwipeBackModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.navigationExitGuard) private var navigationExitGuard
    @State private var dragOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: reduceMotion ? 0 : dragOffset)
            .simultaneousGesture(
            DragGesture(minimumDistance: Tokens.sheetTop, coordinateSpace: .global)
                .onChanged { value in
                    guard !reduceMotion else { return }
                    let isLeadingEdge = value.startLocation.x <= Tokens.sectionGap
                    let isHorizontal = abs(value.translation.height) < abs(value.translation.width)
                    guard isLeadingEdge, isHorizontal else { return }
                    dragOffset = max(0, value.translation.width)
                }
                .onEnded { value in
                    let isLeadingEdge = value.startLocation.x <= Tokens.sectionGap
                    let isHorizontal = abs(value.translation.height) < Tokens.actionTarget
                    let reachedThreshold = value.translation.width > Tokens.touchTarget * 2
                        || value.predictedEndTranslation.width > Tokens.touchTarget * 3
                    if isLeadingEdge, isHorizontal, reachedThreshold {
                        if navigationExitGuard?.attemptExit() != false {
                            dismiss()
                        } else if !reduceMotion {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                                dragOffset = 0
                            }
                        }
                    } else if !reduceMotion {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }
}

private struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.install(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var hostView: UIView?
        private lazy var recognizer: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(didTapOutsideInput))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            return recognizer
        }()

        func install(from view: UIView) {
            guard hostView == nil, let controllerView = parentViewController(of: view)?.view else { return }
            hostView = controllerView
            controllerView.addGestureRecognizer(recognizer)
        }

        func uninstall() {
            hostView?.removeGestureRecognizer(recognizer)
            hostView = nil
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var candidate = touch.view
            while let view = candidate {
                if view is UITextField || view is UITextView {
                    return false
                }
                candidate = view.superview
            }
            return true
        }

        @objc private func didTapOutsideInput() {
            Keyboard.dismiss()
        }

        private func parentViewController(of view: UIView) -> UIViewController? {
            var responder: UIResponder? = view
            while let next = responder?.next {
                if let controller = next as? UIViewController { return controller }
                responder = next
            }
            return nil
        }
    }
}

@MainActor
enum Keyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

}
