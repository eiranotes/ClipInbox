import SwiftUI

struct OnboardingView: View {
    private struct Page: Identifiable {
        let id: Int
        let image: String
        let title: String
        let message: String
        let accessibilityLabel: String
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isFirstRun: Bool
    var onComplete: (() -> Void)?

    @State private var selectedPage = 0

    private let pages = [
        Page(
            id: 0,
            image: "onboarding-share",
            title: "공유 버튼을 눌러요",
            message: "Safari, 사진 또는 다른 앱에서 보관할 내용을 연 뒤 공유 버튼을 누르세요.",
            accessibilityLabel: "휴대전화 화면의 공유 버튼을 누르는 안내 그림"
        ),
        Page(
            id: 1,
            image: "onboarding-destination",
            title: "Clip Inbox를 선택해요",
            message: "공유 시트에서 Clip Inbox를 선택하면 링크, 글, 사진이 바로 전달됩니다.",
            accessibilityLabel: "공유 시트에서 Clip Inbox를 선택하는 안내 그림"
        ),
        Page(
            id: 2,
            image: "onboarding-saved",
            title: "인박스에 안전하게 모여요",
            message: "저장한 클립은 폴더와 태그로 나중에 정리하고 검색으로 다시 찾을 수 있어요.",
            accessibilityLabel: "여러 클립이 인박스에 저장된 안내 그림"
        )
    ]

    var body: some View {
        VStack(spacing: Tokens.formSectionGap) {
            ScreenHeader("Clip Inbox", onBack: isFirstRun ? nil : { dismiss() }, trailing: {
                if isFirstRun {
                    Button("건너뛰기", action: finish)
                        .font(Tokens.bodySemibold)
                        .foregroundStyle(Tokens.textSecondary)
                        .frame(minWidth: Tokens.touchTarget, minHeight: Tokens.touchTarget)
                }
            })

            TabView(selection: $selectedPage) {
                ForEach(pages) { page in
                    VStack(spacing: Tokens.detailGap) {
                        Image(page.image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: Tokens.onboardingImageHeight)
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.radiusPanel,
                                                       style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: Tokens.radiusPanel,
                                                 style: .continuous)
                                    .strokeBorder(Tokens.borderSoft,
                                                  lineWidth: Tokens.borderChipWidth)
                            }
                            .accessibilityLabel(L10n.text(page.accessibilityLabel, locale: locale))

                        VStack(spacing: Tokens.rowGap) {
                            Text(L10n.text(page.title, locale: locale))
                                .font(Tokens.previewTitle)
                                .foregroundStyle(Tokens.textPrimary)
                                .multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isHeader)
                            Text(L10n.text(page.message, locale: locale))
                                .font(Tokens.body)
                                .foregroundStyle(Tokens.textSecondary)
                                .lineSpacing(Tokens.bodyLineSpacing)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, Tokens.cardPad)
                    }
                    .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: Tokens.rowGap) {
                ForEach(pages) { page in
                    Rectangle()
                        .fill(page.id == selectedPage ? Tokens.accentYellow : Tokens.borderSoft)
                        .frame(width: Tokens.destinationIcon, height: Tokens.selectionIndicator)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: Tokens.touchTarget)

            Button(action: advance) {
                Text(L10n.text(selectedPage == pages.count - 1 ? "시작하기" : "다음",
                               locale: locale))
            }
            .buttonStyle(PrimaryBoxButtonStyle())
        }
        .padding(.horizontal, Tokens.screenX)
        .padding(.top, Tokens.screenTop)
        .padding(.bottom, isFirstRun ? Tokens.bottomSafe : Tokens.bottomNavigationClearance)
        .background(Tokens.bgApp.ignoresSafeArea())
    }

    private func advance() {
        guard selectedPage < pages.count - 1 else {
            finish()
            return
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: Tokens.motionBase)) {
            selectedPage += 1
        }
    }

    private func finish() {
        if isFirstRun {
            onComplete?()
        } else {
            dismiss()
        }
    }
}
