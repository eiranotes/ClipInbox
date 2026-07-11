import SwiftUI
import UIKit

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
    typealias SelectionItem = (label: String, active: Bool, action: () -> Void)

    private struct SelectionSlot: Identifiable {
        let id: Int
        let item: SelectionItem?
    }

    let items: [SelectionItem]

    private var gridSlots: [SelectionSlot] {
        let columnCount = Tokens.selectionColumnCount
        let rowCount = Tokens.selectionRowCount
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
        GeometryReader { geometry in
            let gaps = Tokens.chipGap * CGFloat(Tokens.selectionColumnCount - 1)
            let columnWidth = max(
                Tokens.touchTarget,
                (geometry.size.width - gaps) / CGFloat(Tokens.selectionColumnCount)
            )
            let rows = Array(
                repeating: GridItem(.fixed(Tokens.touchTarget), spacing: Tokens.chipGap),
                count: Tokens.selectionRowCount
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
        .frame(height: Tokens.touchTarget * CGFloat(Tokens.selectionRowCount)
            + Tokens.chipGap * CGFloat(Tokens.selectionRowCount - 1))
    }

    private func selectionButton(_ item: SelectionItem) -> some View {
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
        .buttonStyle(.plain)
        .accessibilityAddTraits(item.active ? .isSelected : [])
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
        .buttonStyle(.plain)
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
            Image(systemName: "chevron.right")
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
    var isDanger = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tokens.button)
            .foregroundStyle(isDanger ? Color.white : Tokens.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Tokens.actionTarget)
            .background(
                RoundedRectangle(cornerRadius: Tokens.radiusButton, style: .continuous)
                    .fill(isDanger ? Tokens.danger : Tokens.accentYellow)
            )
            .contentShape(RoundedRectangle(cornerRadius: Tokens.radiusButton, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: Tokens.motionFast), value: configuration.isPressed)
    }
}

struct SecondaryBoxButtonStyle: ButtonStyle {
    var isDanger = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tokens.button)
            .foregroundStyle(isDanger ? Tokens.danger : Tokens.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Tokens.actionTarget)
            .tokenSurface(fill: Tokens.bgCard, radius: Tokens.radiusButton,
                          border: Tokens.borderSoft, borderWidth: Tokens.borderChipWidth)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: Tokens.motionFast), value: configuration.isPressed)
    }
}

/// 상단 유틸리티 44px 아이콘 버튼.
struct UtilityIconButton: View {
    @Environment(\.locale) private var locale
    let label: String
    let systemImage: String
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Tokens.textPrimary)
                .frame(width: Tokens.touchTarget, height: Tokens.touchTarget)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.radiusChip, style: .continuous)
                        .fill(isOn ? Tokens.accentYellow : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.text(label, locale: locale))
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
                Text(L10n.text(title, locale: locale)).font(Tokens.sectionTitle).foregroundStyle(Tokens.textPrimary)
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
                    .foregroundStyle(isDanger ? Tokens.danger : Tokens.textPrimary)
                    .frame(width: Tokens.iconColumn, height: Tokens.destinationIcon)
                Text(L10n.text(label, locale: locale))
                    .font(Tokens.bodySemibold)
                    .foregroundStyle(isDanger ? Tokens.danger : Tokens.textPrimary)
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
                    .foregroundStyle(isSelected ? Tokens.textPrimary : Tokens.textTertiary)
            }
            .padding(.horizontal, Tokens.space1)
            .frame(minHeight: Tokens.actionTarget)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: Tokens.radiusChip, style: .continuous)
                    .fill(isSelected ? Tokens.accentYellow.opacity(0.16) : .clear)
            )
            .overlay(alignment: .bottom) {
                if !isSelected { Tokens.borderSoft.frame(height: Tokens.borderChipWidth) }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 상태 패널 / 빈 상태

struct StatePanel: View {
    @Environment(\.locale) private var locale
    let systemImage: String
    let title: String
    let message: String
    var isDanger = false

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.cardGap) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isDanger ? Tokens.danger : Tokens.textPrimary)
                .frame(width: Tokens.iconColumn)
            VStack(alignment: .leading, spacing: Tokens.rowGap) {
                Text(L10n.text(title, locale: locale))
                    .font(Tokens.cardTitle)
                    .foregroundStyle(Tokens.textPrimary)
                Text(L10n.text(message, locale: locale))
                    .font(Tokens.meta)
                    .foregroundStyle(Tokens.textSecondary)
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
        }
        .padding(.vertical, Tokens.sectionGap * 2)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 썸네일 / 도메인 폴백

/// 공유 이미지 파일을 행 렌더마다 디스크에서 다시 읽지 않도록 하는 메모리 캐시.
enum SharedImageCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(at url: URL) -> UIImage? {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
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
    static func image(for clip: Clip) -> UIImage {
        if let url = clip.sharedImageURL, let uiImage = SharedImageCache.image(at: url) {
            return uiImage
        }
        if let asset = clip.imageAssetName, let uiImage = UIImage(named: asset) {
            return uiImage
        }
        return UIImage(named: "clip-image-fallback") ?? UIImage()
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
    let message: String

    var body: some View {
        HStack(spacing: Tokens.rowGap) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 16, weight: .bold))
            Text(L10n.text(message, locale: locale)).font(Tokens.bodyBold)
        }
        .foregroundStyle(Tokens.textPrimary)
        .padding(.horizontal, Tokens.panelPad)
        .padding(.vertical, 12)
        .tokenSurface(fill: Tokens.accentGreen, radius: Tokens.radiusButton,
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
    var dismissKeyboardOnBackgroundTap = true
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                content
            }
            .padding(.horizontal, Tokens.screenX)
            .padding(.top, usesWorkflowSheetStyle ? Tokens.sheetTop : Tokens.screenTop)
            .padding(.bottom, usesWorkflowSheetStyle ? Tokens.sheetBottom : Tokens.bottomSafe)
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

private struct LeadingEdgeSwipeBackModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: Tokens.sheetTop, coordinateSpace: .global)
                .onEnded { value in
                    let isLeadingEdge = value.startLocation.x <= Tokens.sectionGap
                    let isHorizontal = abs(value.translation.height) < Tokens.actionTarget
                    let reachedThreshold = value.translation.width > Tokens.touchTarget * 2
                        || value.predictedEndTranslation.width > Tokens.touchTarget * 3
                    if isLeadingEdge, isHorizontal, reachedThreshold {
                        dismiss()
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
