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

    var body: some View {
        Group {
            switch selectedTab {
            case .inbox: InboxTab()
            case .folders: FoldersTab()
            case .add: AddClipView()
            case .search: SearchView()
            case .settings: SettingsTab()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomNavBar(selected: $selectedTab)
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
    }
}

private struct BottomNavBar: View {
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
                        Text(tab.label).font(Tokens.nav)
                    }
                    .foregroundStyle(selected == tab ? Tokens.textPrimary : Tokens.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: Tokens.actionTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
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
                .accessibilityLabel(backLabel ?? "뒤로")
            }
            Text(title)
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
                    route.destination.toolbar(.hidden, for: .navigationBar)
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
                    route.destination.toolbar(.hidden, for: .navigationBar)
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
                    route.destination.toolbar(.hidden, for: .navigationBar)
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
