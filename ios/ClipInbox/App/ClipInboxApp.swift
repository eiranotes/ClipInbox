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
                .font(Tokens.body)
                .preferredColorScheme(.light)
                .onAppear {
                    lock.configure(enabled: store.preferences.appLock == "켬", lockImmediately: true)
                    store.importSharedClips()
                    Task { @MainActor in
                        // 실행 트랜지션이 끝난 뒤 예열해야 첫 프레임을 막지 않는다.
                        try? await Task.sleep(for: .milliseconds(300))
                        Keyboard.prewarm()
                    }
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
}
