import SwiftUI
import UIKit

// DESIGN.md 토큰 계약의 Swift 대응. 값 변경은 DESIGN.md와 함께 맞춘다.

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

enum Tokens {
    // Color
    static let bgApp = Color.adaptive(light: 0xF3EFE7, dark: 0x171714)
    static let bgBoard = Color.adaptive(light: 0xEEE8DD, dark: 0x211F1B)
    static let bgCard = Color.adaptive(light: 0xFFFFFF, dark: 0x2B2924)
    static let bgCardMuted = Color.adaptive(light: 0xFAF8F2, dark: 0x24221E)
    static let textPrimary = Color.adaptive(light: 0x171714, dark: 0xF4F1E9)
    static let textSecondary = Color.adaptive(light: 0x5F6368, dark: 0xB5B1A8)
    static let textTertiary = Color.adaptive(light: 0x9AA0A6, dark: 0x817D75)
    static let onAccent = Color(hex: 0x171714)
    static let borderStrong = Color.adaptive(light: 0x292824, dark: 0xECE8DF)
    static let borderSoft = Color.adaptive(light: 0xD8D1C4, dark: 0x44413B)
    static let accentYellow = Color.adaptive(light: 0xFFD900, dark: 0xF4D21F)
    static let accentBlue = Color.adaptive(light: 0xBBD7FF, dark: 0x8FB8EE)
    static let accentGreen = Color.adaptive(light: 0x9BE7B0, dark: 0x68C982)
    static let danger = Color.adaptive(light: 0xFF4B4B, dark: 0xFF6B6B)

    // Typography (letter spacing 0, bundled Pretendard v1.3.9)
    static let screenTitle = Font.custom("Pretendard-Bold", size: 26)
    static let sectionTitle = Font.custom("Pretendard-Bold", size: 18)
    static let cardTitle = Font.custom("Pretendard-SemiBold", size: 17)
    static let previewTitle = Font.custom("Pretendard-Bold", size: 28)
    static let body = Font.custom("Pretendard-Regular", size: 15)
    static let bodySemibold = Font.custom("Pretendard-SemiBold", size: 15)
    static let bodyBold = Font.custom("Pretendard-Bold", size: 15)
    static let meta = Font.custom("Pretendard-Regular", size: 13)
    static let metaSemibold = Font.custom("Pretendard-SemiBold", size: 13)
    static let metaBold = Font.custom("Pretendard-Bold", size: 13)
    static let chip = Font.custom("Pretendard-SemiBold", size: 12)
    static let button = Font.custom("Pretendard-SemiBold", size: 16)
    static let nav = Font.custom("Pretendard-SemiBold", size: 11)

    // Line spacing (DESIGN.md line-height 계약: body 1.55, meta 1.4를 lineSpacing 가산치로 구현)
    static let titleLineSpacing: CGFloat = 3
    static let bodyLineSpacing: CGFloat = 6
    static let metaLineSpacing: CGFloat = 4

    // Spacing (base 4px)
    static let space1: CGFloat = 4
    static let chipGap: CGFloat = 8
    static let rowGap: CGFloat = 8
    static let cardGap: CGFloat = 12
    static let cardPad: CGFloat = 12
    static let detailGap: CGFloat = 16
    static let screenX: CGFloat = 16
    static let panelPad: CGFloat = 16
    static let sectionGap: CGFloat = 24
    static let emptyGuideTop: CGFloat = 16
    static let formSectionGap: CGFloat = 16
    static let screenTop: CGFloat = 12
    static let bottomSafe: CGFloat = 24
    static let bottomNavigationClearance: CGFloat = 72
    static let sheetTop: CGFloat = 20
    static let sheetBottom: CGFloat = 20
    static let settingChoiceTop: CGFloat = 72
    static let settingActionTop: CGFloat = 132

    // Control sizes
    static let chipTarget: CGFloat = 40
    static let touchTarget: CGFloat = 44
    static let iconBody: CGFloat = 16
    static let actionTarget: CGFloat = 52
    static let headerHeight: CGFloat = 44
    static let selectionIndicator: CGFloat = 2
    static let selectionColumnCount = 5
    static let selectionRowCount = 2
    static let manualCaptureSelectionRowCount = 1
    static let selectionTextMinimumScale: CGFloat = 0.72
    static let iconColumn: CGFloat = 28
    static let destinationIcon: CGFloat = 34
    static let clipThumbnailWidth: CGFloat = 80
    static let clipThumbnailHeight: CGFloat = 64
    static let clipRowContentHeight: CGFloat = 68
    static let resultThumbnailWidth: CGFloat = 64
    static let resultThumbnailHeight: CGFloat = 48
    static let resultRowContentHeight: CGFloat = 48
    // 상세는 스크롤 없이 링크 열기까지 한 화면에 들어와야 하므로 미디어와 노트를 압축한다.
    static let detailImageHeight: CGFloat = 140
    static let noteEditorMinHeight: CGFloat = 72
    static let onboardingImageHeight: CGFloat = 300
    static let lockIllustration: CGFloat = 228
    static let privacyMark: CGFloat = 88
    static let sheetDetentCompact: CGFloat = 0.58
    static let sheetDetentStandard: CGFloat = 0.76
    static let contentMax: CGFloat = 720
    static let gridBreakpoint: CGFloat = 760

    // Radius
    static let radiusCard: CGFloat = 10
    static let radiusPanel: CGFloat = 12
    static let radiusButton: CGFloat = 10
    static let radiusChip: CGFloat = 8
    static let radiusInput: CGFloat = 8
    static let radiusThumbnail: CGFloat = 8

    // Border widths
    static let borderCardWidth: CGFloat = 1
    static let borderChipWidth: CGFloat = 1

    // Motion
    static let motionFast: Double = 0.14
    static let motionBase: Double = 0.18
    static let searchDebounceDelay: Duration = .milliseconds(120)
}

extension View {
    /// 입력과 선택 컨트롤에 쓰는 얇은 표면. 콘텐츠 목록의 외곽 카드에는 사용하지 않는다.
    func tokenSurface(fill: Color = Tokens.bgCard, radius: CGFloat = Tokens.radiusCard,
                      border: Color = Tokens.borderSoft, borderWidth: CGFloat = Tokens.borderCardWidth) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(border, lineWidth: borderWidth)
                )
        )
    }

    /// 레거시 호출 호환용. 네이티브 UI에서는 텍스트 래스터까지 복제하는 하드 섀도를 사용하지 않는다.
    func hardShadow() -> some View {
        self
    }
}
