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
                    lock.configure(enabled: store.preferences.appLock == "켬")
                    store.importSharedClips()
                }
                .onChange(of: store.preferences.appLock) { _, newValue in
                    lock.configure(enabled: newValue == "켬")
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { lock.lockIfNeeded() }
                    if phase == .active { store.importSharedClips() }
                }
        }
    }
}
