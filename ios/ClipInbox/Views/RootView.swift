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

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppLockController.self) private var lock
    @State private var selectedTab: AppTab = .inbox
    @State private var keyboardVisible = false

    var body: some View {
        Group {
            if store.bootstrapState.blocksLibrary {
                LibraryBootstrapGate(state: store.bootstrapState)
            } else {
                switch selectedTab {
                case .inbox: InboxTab()
                case .folders: FoldersTab()
                case .add: AddClipView()
                case .search: SearchView()
                case .settings: SettingsTab()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !keyboardVisible && !store.bootstrapState.blocksLibrary {
                BottomNavBar(selected: $selectedTab)
                    .transition(.identity)
            }
        }
        .background(Tokens.bgApp.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let toast = store.toast {
                ToastView(message: toast)
                    .padding(.bottom, 72)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: Tokens.motionBase), value: store.toast)
        .overlay {
            if lock.isLocked {
                AppLockView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: Tokens.motionBase), value: lock.isLocked)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
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
    @Binding var selected: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    guard selected != tab else { return }
                    // 키보드는 입력 필드를 직접 탭했을 때만 올라온다. 탭 전환은 항상 내린다.
                    Keyboard.dismiss()
                    selected = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 34, height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: Tokens.radiusChip, style: .continuous)
                                    .fill(selected == tab ? Tokens.accentYellow : .clear)
                            )
                        Text(L10n.text(tab.label, locale: locale)).font(Tokens.nav)
                    }
                    .foregroundStyle(selected == tab ? Tokens.textPrimary : Tokens.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: Tokens.actionTarget)
                }
                .buttonStyle(.plain)
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
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text(backLabel ?? "뒤로", locale: locale))
            }
            Text(L10n.text(title, locale: locale))
                .font(Tokens.screenTitle)
                .foregroundStyle(Tokens.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: Tokens.rowGap)
            trailing
        }
        .frame(maxWidth: .infinity, minHeight: Tokens.headerHeight)
    }
}

// MARK: - 탭 루트 (탭별 NavigationStack)

struct InboxTab: View {
    var body: some View {
        NavigationStack {
            InboxView()
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
    var body: some View {
        NavigationStack {
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
    var body: some View {
        NavigationStack {
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
    case settingDetail(SettingKey)

    @ViewBuilder var destination: some View {
        switch self {
        case .detail(let id): DetailView(clipID: id)
        case .folderDetail(let label): FolderDetailView(label: label)
        case .settingDetail(let key): SettingDetailView(key: key)
        }
    }
}
