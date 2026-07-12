import SwiftUI
import LocalAuthentication
import Observation

protocol AppLockAuthenticating: AnyObject {
    func canAuthenticate() -> Bool
    func authenticate(reason: String) async throws -> Bool
    func cancel()
}

final class LocalDeviceOwnerAuthenticator: AppLockAuthenticating {
    private var context: LAContext?

    func canAuthenticate() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        self.context = context
        defer { self.context = nil }
        return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
    }

    func cancel() {
        context?.invalidate()
        context = nil
    }
}

@Observable
final class AppLockController {
    private(set) var isEnabled = false
    var isLocked = false
    var notice: String?
    private(set) var isAuthenticating = false

    @ObservationIgnored private let authenticator: any AppLockAuthenticating

    init(authenticator: any AppLockAuthenticating = LocalDeviceOwnerAuthenticator()) {
        self.authenticator = authenticator
    }

    func canEnableLock() -> Bool {
        authenticator.canAuthenticate()
    }

    func configure(enabled: Bool, lockImmediately: Bool = false) {
        isEnabled = enabled
        if enabled, lockImmediately {
            isLocked = true
        } else if !enabled {
            authenticator.cancel()
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

        isAuthenticating = true
        defer {
            isAuthenticating = false
        }

        guard authenticator.canAuthenticate() else {
            notice = L10n.text("이 기기에서 잠금 인증을 사용할 수 없습니다. 기기 암호를 설정한 뒤 다시 시도하세요.")
            return
        }
        do {
            let success = try await authenticator.authenticate(
                reason: L10n.text("저장된 클립을 보호하기 위해 인증이 필요합니다.")
            )
            if success {
                notice = nil
                isLocked = false
            }
        } catch {
            notice = L10n.text("인증에 실패했습니다. 다시 시도하세요.")
        }
    }
}

struct PrivacyShieldView: View {
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: Tokens.rowGap) {
            Image("lock-clip")
                .resizable()
                .scaledToFit()
                .frame(width: Tokens.privacyMark, height: Tokens.privacyMark)
            Text(L10n.text("클립 인박스", locale: locale))
                .font(Tokens.screenTitle)
        }
        .foregroundStyle(Tokens.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.bgApp.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Clip Inbox 개인정보 보호 화면")
    }
}

struct AppLockView: View {
    @Environment(AppLockController.self) private var lock
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: Tokens.sectionGap) {
            Spacer()
            Image("lock-clip")
                .resizable()
                .scaledToFit()
                .frame(width: Tokens.lockIllustration, height: Tokens.lockIllustration)
                .accessibilityLabel(L10n.text("노란 종이클립 아이콘", locale: locale))

            VStack(spacing: Tokens.rowGap) {
                Text(L10n.text("Clip Inbox 잠금", locale: locale))
                    .font(Tokens.screenTitle)
                    .foregroundStyle(Tokens.textPrimary)
                Text(L10n.text("앱 잠금이 켜져 있습니다. 계속하려면 인증하세요.", locale: locale))
                    .font(Tokens.body)
                    .foregroundStyle(Tokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let notice = lock.notice {
                Text(notice)
                    .font(Tokens.meta)
                    .foregroundStyle(Tokens.danger)
                    .multilineTextAlignment(.center)
            }
            Button {
                Task { await lock.authenticate() }
            } label: {
                Label(L10n.text("잠금 해제", locale: locale), systemImage: "lock.open.fill")
            }
            .buttonStyle(PrimaryBoxButtonStyle())
            Spacer()
        }
        .padding(.horizontal, Tokens.sectionGap * 2)
        .frame(maxWidth: Tokens.contentMax)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.bgApp)
    }
}
