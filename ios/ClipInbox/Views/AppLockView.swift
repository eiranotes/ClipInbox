import SwiftUI
import LocalAuthentication
import Observation

@Observable
final class AppLockController {
    private(set) var isEnabled = false
    var isLocked = false
    var notice: String?
    private(set) var isAuthenticating = false

    @ObservationIgnored private var authenticationContext: LAContext?

    func configure(enabled: Bool, lockImmediately: Bool = false) {
        isEnabled = enabled
        if enabled, lockImmediately {
            isLocked = true
        } else if !enabled {
            authenticationContext?.invalidate()
            authenticationContext = nil
            isAuthenticating = false
            isLocked = false
            notice = nil
        }
    }

    func lockIfNeeded() {
        if isEnabled { isLocked = true }
    }

    @MainActor
    func authenticate() async {
        guard isEnabled, isLocked, !isAuthenticating else { return }

        let context = LAContext()
        authenticationContext = context
        isAuthenticating = true
        defer {
            authenticationContext = nil
            isAuthenticating = false
        }

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // 시뮬레이터 등 인증 수단이 없는 환경에서는 잠금을 해제하되 사유를 남긴다.
            notice = "이 기기에서 잠금 인증을 사용할 수 없어 잠금을 건너뜁니다."
            isLocked = false
            return
        }
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                           localizedReason: "저장된 클립을 보호하기 위해 인증이 필요합니다.")
            if success {
                notice = nil
                isLocked = false
            }
        } catch {
            notice = "인증에 실패했습니다. 다시 시도하세요."
        }
    }
}

struct AppLockView: View {
    @Environment(AppLockController.self) private var lock

    var body: some View {
        VStack(spacing: Tokens.sectionGap) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Tokens.textPrimary)
                .frame(width: 88, height: 88)
                .tokenSurface(fill: Tokens.accentYellow, radius: Tokens.radiusPanel)
                .hardShadow()
            Text("Clip Inbox 잠금")
                .font(Tokens.screenTitle)
                .foregroundStyle(Tokens.textPrimary)
            Text("앱 잠금이 켜져 있습니다. 계속하려면 인증하세요.")
                .font(Tokens.body)
                .foregroundStyle(Tokens.textSecondary)
                .multilineTextAlignment(.center)
            if let notice = lock.notice {
                Text(notice)
                    .font(Tokens.meta)
                    .foregroundStyle(Tokens.danger)
                    .multilineTextAlignment(.center)
            }
            Button {
                Task { await lock.authenticate() }
            } label: {
                Label("잠금 해제", systemImage: "faceid")
            }
            .buttonStyle(PrimaryBoxButtonStyle())
            Spacer()
        }
        .padding(.horizontal, Tokens.sectionGap * 2)
        .frame(maxWidth: Tokens.contentMax)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.bgApp)
        .task {
            // 앱이 완전히 포그라운드 활성화되기 전에 인증 UI를 띄우면
            // "UI activation timed out"으로 실패하므로 잠시 기다린다.
            try? await Task.sleep(for: .seconds(0.6))
            await lock.authenticate()
        }
    }
}
