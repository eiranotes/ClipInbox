import SwiftUI

@main
struct ClipInboxApp: App {
    @State private var store = AppStore()
    @State private var lock = AppLockController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(lock)
                .environment(\.locale, Locale(identifier: store.preferences.appLanguage.localeIdentifier))
                .font(Tokens.body)
                .preferredColorScheme(preferredColorScheme)
                .onAppear {
                    lock.configure(enabled: store.preferences.appLock == "켬", lockImmediately: true)
                    store.importSharedClips()
                }
                .onChange(of: store.preferences.appLock) { _, newValue in
                    // 설정 저장 중 인증 UI를 겹쳐 띄우지 않는다. 새 잠금은 다음
                    // 백그라운드 진입 또는 앱 실행부터 적용한다.
                    lock.configure(enabled: newValue == "켬")
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { lock.lockIfNeeded() }
                    if phase == .active { store.importSharedClips() }
                }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch store.preferences.theme {
        case "라이트": return .light
        case "다크": return .dark
        default: return nil
        }
    }
}
