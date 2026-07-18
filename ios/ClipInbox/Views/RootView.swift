import SwiftUI
import UIKit

enum AppTab: String, CaseIterable, Identifiable {
    case inbox, folders, add, search, settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .inbox: return "인박스"
        case .folders: return "폴더"
        case .add: return "추가"
        case .search: return "검색"
        case .settings: return "설정"
        }
    }

    var systemImage: String {
        switch self {
        case .inbox: return "tray.full"
        case .folders: return "folder"
        case .add: return "plus"
        case .search: return "magnifyingglass"
        case .settings: return "gearshape"
        }
    }
}

struct TabNavigationState: Equatable {
    var inbox: [Route] = []
    var folders: [Route] = []
    var search: [Route] = []
    var settings: [Route] = []

    mutating func reset(_ tab: AppTab) {
        switch tab {
        case .inbox: inbox.removeAll()
        case .folders: folders.removeAll()
        case .search: search.removeAll()
        case .settings: settings.removeAll()
        case .add: break
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppLockController.self) private var lock
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab: AppTab = .inbox
    @State private var navigation = TabNavigationState()
    @State private var navigationExitGuard = NavigationExitGuard()
    @State private var keyboardVisible = false
    @State private var showOnboarding = false
    @AppStorage("clip-inbox-onboarding-completed-v1") private var onboardingCompleted = false

    init() {
        var initialTab = AppTab.inbox
        var initialNavigation = TabNavigationState()
        #if DEBUG
        if ProcessInfo.processInfo.environment["CLIP_INBOX_ASO_CAPTURE"] == "1",
           let rawTab = ProcessInfo.processInfo.environment["CLIP_INBOX_ASO_TAB"],
           let tab = AppTab(rawValue: rawTab) {
            initialTab = tab
        }
        if ProcessInfo.processInfo.environment["CLIP_INBOX_ASO_CAPTURE"] == "1",
           let rawID = ProcessInfo.processInfo.environment["CLIP_INBOX_ASO_DETAIL_CLIP_ID"],
           let clipID = Int(rawID) {
            initialNavigation.inbox = [.detail(clipID)]
        }
        #endif
        _selectedTab = State(initialValue: initialTab)
        _navigation = State(initialValue: initialNavigation)
    }

    var body: some View {
        Group {
            if store.bootstrapState.blocksLibrary {
                LibraryBootstrapGate(state: store.bootstrapState)
            } else {
                switch selectedTab {
                case .inbox: InboxTab(selectedTab: $selectedTab, path: $navigation.inbox)
                case .folders: FoldersTab(path: $navigation.folders)
                case .add: AddClipView()
                case .search: SearchView(path: $navigation.search)
                case .settings: SettingsTab(path: $navigation.settings)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.navigationExitGuard, navigationExitGuard)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !keyboardVisible && !store.bootstrapState.blocksLibrary {
                BottomNavBar(selected: selectedTab, onSelect: selectTab)
                    .transition(.identity)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !store.bootstrapState.blocksLibrary {
                VStack(spacing: 0) {
                    if store.recoveredLibraryNotice {
                        PersistentTrustBanner(
                            systemImage: "checkmark.shield",
                            title: "이전 보관함으로 복구했습니다",
                            message: "손상된 원본은 복구 폴더에 보존되어 있습니다."
                        ) {
                            store.dismissRecoveredLibraryNotice()
                        }
                    }
                    if let sharedQueueNotice = store.sharedQueueNotice {
                        PersistentTrustBanner(
                            systemImage: "tray.and.arrow.down",
                            title: "공유 항목 확인이 필요합니다",
                            message: sharedQueueNotice,
                            isDanger: true
                        ) {
                            store.dismissSharedQueueNotice()
                        }
                    }
                }
            }
        }
        .background(Tokens.bgApp.ignoresSafeArea())
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isFirstRun: true) {
                onboardingCompleted = true
                showOnboarding = false
            }
            .interactiveDismissDisabled()
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: Tokens.rowGap) {
                if let pendingDeletion = store.pendingDeletion {
                    UndoDeletionBanner(title: pendingDeletion.displayTitle) {
                        store.undoDelete()
                    }
                    .transition(feedbackTransition)
                }
                if let toast = store.toast {
                    ToastView(toast: toast)
                        .transition(feedbackTransition)
                }
            }
            .padding(.bottom, Tokens.bottomNavigationClearance)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: Tokens.motionBase), value: store.toast?.id)
        .animation(reduceMotion ? nil : .easeOut(duration: Tokens.motionBase), value: store.pendingDeletion?.id)
        .overlay {
            if lock.isLocked {
                AppLockView()
                    .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: Tokens.motionBase), value: lock.isLocked)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        .onAppear {
            if !onboardingCompleted { showOnboarding = true }
        }
        .onChange(of: store.toast?.id) { _, id in
            guard id != nil, let toast = store.toast else { return }
            UIAccessibility.post(notification: .announcement, argument: L10n.text(toast.message))
        }
    }

    private var feedbackTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    private func selectTab(_ tab: AppTab) {
        guard navigationExitGuard.attemptExit() else { return }
        Keyboard.dismiss()
        if selectedTab == tab {
            navigation.reset(tab)
        } else {
            selectedTab = tab
        }
    }
}

private struct PersistentTrustBanner: View {
    let systemImage: String
    let title: String
    let message: String
    var isDanger = false
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: Tokens.rowGap) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .bold))
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.text(title))
                    .font(Tokens.bodyBold)
                Text(L10n.text(message))
                    .font(Tokens.meta)
            }
            Spacer(minLength: Tokens.rowGap)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .frame(width: Tokens.touchTarget, height: Tokens.touchTarget)
            }
            .buttonStyle(ResponsivePressButtonStyle(pressedScale: 0.9))
            .accessibilityLabel("복구 알림 닫기")
        }
        .foregroundStyle(Tokens.onAccent)
        .padding(.horizontal, Tokens.screenX)
        .background(Tokens.accentYellow)
    }
}

struct UndoDeletionBanner: View {
    let title: String
    let undo: () -> Void

    var body: some View {
        HStack(spacing: Tokens.cardGap) {
            Image(systemName: "trash")
                .font(.system(size: 16, weight: .bold))
            Text(L10n.format("format.deleted_clip_title", title))
                .font(Tokens.bodyBold)
                .lineLimit(2)
            Spacer(minLength: Tokens.rowGap)
            Button("되돌리기", action: undo)
                .font(Tokens.bodyBold)
                .frame(minWidth: Tokens.touchTarget, minHeight: Tokens.touchTarget)
        }
        .foregroundStyle(Tokens.onAccent)
        .padding(.leading, Tokens.panelPad)
        .padding(.trailing, Tokens.rowGap)
        .tokenSurface(fill: Tokens.accentYellow, radius: Tokens.radiusButton,
                      border: Tokens.borderSoft, borderWidth: Tokens.borderChipWidth)
        .padding(.horizontal, Tokens.screenX)
    }
}

private struct LibraryBootstrapGate: View {
    @Environment(AppStore.self) private var store
    let state: LibraryBootstrapState
    @State private var confirmFreshLibrary = false

    private var content: (icon: String, title: String, message: String) {
        switch state {
        case .updateRequired(let version):
            return (
                "arrow.down.app",
                "앱 업데이트가 필요합니다",
                L10n.format("format.library_version_requires_update", version)
            )
        default:
            return (
                "externaldrive.badge.exclamationmark",
                "보관함을 열 수 없습니다",
                "손상된 원본은 복구 폴더에 보존했습니다. 새 보관함을 시작하면 기존 파일을 덮어쓰지 않고 빈 보관함을 만듭니다."
            )
        }
    }

    var body: some View {
        ScreenScaffold {
            ScreenHeader("Clip Inbox")
            StatePanel(
                systemImage: content.icon,
                title: content.title,
                message: content.message,
                isDanger: true
            )

            if state == .recoveryRequired {
                Button("새 보관함 시작") {
                    confirmFreshLibrary = true
                }
                .buttonStyle(PrimaryBoxButtonStyle())
            }

            Spacer(minLength: Tokens.sectionGap)
        }
        .alert("새 보관함을 시작할까요?", isPresented: $confirmFreshLibrary) {
            Button("취소", role: .cancel) {}
            Button("새 보관함 시작", role: .destructive) {
                store.startFreshLibraryAfterRecoveryFailure()
            }
        } message: {
            Text("복구하지 못한 원본은 별도 파일로 보존되며, 앱에는 빈 보관함이 열립니다.")
        }
    }
}

private struct BottomNavBar: View {
    @Environment(\.locale) private var locale
    let selected: AppTab
    let onSelect: (AppTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(selected == tab ? Tokens.onAccent : Tokens.textSecondary)
                            .frame(width: 34, height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: Tokens.radiusChip, style: .continuous)
                                    .fill(selected == tab ? Tokens.accentYellow : .clear)
                            )
                        Text(L10n.text(tab.label, locale: locale))
                            .font(Tokens.nav)
                            // 다섯 개의 고정 탭 이름은 접근성 글자 크기에서도 서로
                            // 침범하지 않도록 네이티브 탭 바처럼 표시 크기만 제한한다.
                            // 각 버튼의 VoiceOver 레이블과 44pt 타깃은 그대로 유지된다.
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .foregroundStyle(selected == tab ? Tokens.textPrimary : Tokens.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                    }
                    .frame(maxWidth: .infinity, minHeight: Tokens.actionTarget)
                }
                .buttonStyle(ResponsivePressButtonStyle(pressedScale: 0.94))
                .accessibilityLabel(L10n.text(tab.label, locale: locale))
                .accessibilityAddTraits(selected == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, Tokens.rowGap)
        .padding(.top, 6)
        .background(
            Tokens.bgCardMuted
                .overlay(alignment: .top) { Tokens.borderSoft.frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - 공통 화면 헤더

struct ScreenHeader<Trailing: View>: View {
    @Environment(\.locale) private var locale
    let title: String
    var backLabel: String?
    var onBack: (() -> Void)?
    @ViewBuilder var trailing: Trailing

    init(_ title: String, backLabel: String? = nil, onBack: (() -> Void)? = nil,
         @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.backLabel = backLabel
        self.onBack = onBack
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: Tokens.rowGap) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Tokens.textPrimary)
                        .frame(width: Tokens.touchTarget, height: Tokens.touchTarget)
                }
                .buttonStyle(ResponsivePressButtonStyle(pressedScale: 0.94))
                .accessibilityLabel(L10n.text(backLabel ?? "뒤로", locale: locale))
            }
            Text(L10n.text(title, locale: locale))
                .font(Tokens.screenTitle)
                .foregroundStyle(Tokens.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Tokens.rowGap)
            trailing
        }
        .frame(maxWidth: .infinity, minHeight: Tokens.headerHeight)
    }
}

// MARK: - 탭 루트 (탭별 NavigationStack)

struct InboxTab: View {
    @Binding var selectedTab: AppTab
    @Binding var path: [Route]

    var body: some View {
        NavigationStack(path: $path) {
            InboxView(selectedTab: $selectedTab)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Route.self) { route in
                    route.destination
                        .toolbar(.hidden, for: .navigationBar)
                        .swipeBackFromLeadingEdge()
                }
        }
    }
}

struct FoldersTab: View {
    @Binding var path: [Route]

    var body: some View {
        NavigationStack(path: $path) {
            FoldersView()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Route.self) { route in
                    route.destination
                        .toolbar(.hidden, for: .navigationBar)
                        .swipeBackFromLeadingEdge()
                }
        }
    }
}

struct SettingsTab: View {
    @Binding var path: [Route]

    var body: some View {
        NavigationStack(path: $path) {
            SettingsView()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Route.self) { route in
                    route.destination
                        .toolbar(.hidden, for: .navigationBar)
                        .swipeBackFromLeadingEdge()
                }
        }
    }
}

enum Route: Hashable {
    case detail(Int)
    case folderDetail(String)
    case trash
    case settingDetail(SettingKey)

    @ViewBuilder var destination: some View {
        switch self {
        case .detail(let id): DetailView(clipID: id)
        case .folderDetail(let label): FolderDetailView(label: label)
        case .trash: TrashView()
        case .settingDetail(let key): SettingDetailView(key: key)
        }
    }
}
