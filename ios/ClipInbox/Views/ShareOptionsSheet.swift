import SwiftUI
import UIKit

/// 공유 시트: 링크 복사, 시스템 공유, 공유 카드 이미지.
struct ShareOptionsSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    let clipID: Int

    @State private var cardImage: Image?

    var body: some View {
        if let clip = store.clip(id: clipID) {
            ScreenScaffold {
                ScreenHeader("공유", onBack: { dismiss() })

                BoardSection(title: "공유할 클립") {
                    HStack(spacing: Tokens.cardGap) {
                        if clip.hasImageReference {
                            ClipThumbnail(clip: clip, compact: true)
                                .frame(width: Tokens.resultThumbnailWidth, height: Tokens.resultThumbnailHeight)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.text(clip.presentationTitle, locale: locale))
                                .font(Tokens.bodyBold)
                                .foregroundStyle(Tokens.textPrimary)
                                .lineLimit(2)
                            Text(L10n.text(clip.source, locale: locale))
                                .font(Tokens.meta)
                                .foregroundStyle(Tokens.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                }

                BoardSection(title: "공유 방식") {
                    VStack(spacing: 0) {
                        ActionRow(systemImage: "doc.on.doc",
                                  label: clip.url.isEmpty ? "클립 정보 복사" : "링크 복사",
                                  value: clip.url.isEmpty ? "제목을 클립보드에 복사" : "URL을 클립보드에 복사") {
                            UIPasteboard.general.string = clip.url.isEmpty ? clip.title : clip.url
                            store.showToast("링크를 복사했습니다")
                        }

                        ShareLink(item: shareText(clip)) {
                            shareRowLabel(systemImage: "square.and.arrow.up", label: "시스템 공유",
                                          value: "제목과 메모를 공유 시트로 전송")
                        }
                        .buttonStyle(ResponsivePressButtonStyle())

                        if let cardImage {
                            ShareLink(item: cardImage,
                                      preview: SharePreview(clip.presentationTitle, image: cardImage)) {
                                shareRowLabel(systemImage: "photo", label: "이미지 카드 공유",
                                              value: "썸네일 포함 PNG 카드 전송")
                            }
                            .buttonStyle(ResponsivePressButtonStyle())
                        } else {
                            shareRowLabel(systemImage: "photo", label: "이미지 카드 공유", value: "카드 생성 중…")
                                .opacity(0.5)
                        }
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Label("완료", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryBoxButtonStyle())
            }
            .task {
                cardImage = await renderShareCard(clip: clip)
            }
        }
    }

    private func shareText(_ clip: Clip) -> String {
        [clip.presentationTitle, clip.memo ?? clip.description, clip.url]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private func shareRowLabel(systemImage: String, label: String, value: String) -> some View {
        HStack(spacing: Tokens.cardGap) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Tokens.textPrimary)
                .frame(width: Tokens.iconColumn, height: Tokens.destinationIcon)
            VStack(alignment: .leading, spacing: Tokens.space1) {
                Text(label).font(Tokens.bodySemibold).foregroundStyle(Tokens.textPrimary)
                Text(value).font(Tokens.meta).foregroundStyle(Tokens.textSecondary)
            }
            Spacer(minLength: Tokens.rowGap)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Tokens.textTertiary)
        }
        .padding(.horizontal, Tokens.space1)
        .frame(minHeight: Tokens.actionTarget)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Tokens.borderSoft.frame(height: Tokens.borderChipWidth)
        }
    }

    @MainActor
    private func renderShareCard(clip: Clip) async -> Image? {
        let renderer = ImageRenderer(content: ShareCardView(clip: clip))
        renderer.scale = 2
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}

/// 웹 프로토타입의 1200x630 공유 카드와 같은 구성의 SwiftUI 카드.
struct ShareCardView: View {
    let clip: Clip

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 18) {
                Text(clip.type.label)
                    .font(Tokens.bodyBold)
                    .foregroundStyle(Tokens.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .tokenSurface(fill: Tokens.accentYellow, radius: Tokens.radiusChip)
                Text(clip.presentationTitle)
                    .font(Tokens.previewTitle)
                    .foregroundStyle(Tokens.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Text(clip.source)
                    .font(Tokens.bodySemibold)
                    .foregroundStyle(Tokens.textSecondary)
            }
            if clip.imageAssetName != nil || clip.sharedImageURL != nil {
                ClipThumbnail(clip: clip)
                    .frame(width: 180, height: 210)
            }
        }
        .padding(28)
        .frame(width: 600, height: 315, alignment: .topLeading)
        .tokenSurface(radius: 24, borderWidth: 4)
        .padding(28)
        .background(Tokens.bgApp)
    }
}
