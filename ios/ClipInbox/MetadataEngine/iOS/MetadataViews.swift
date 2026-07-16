#if canImport(SwiftUI)
import SwiftUI

struct MetadataRemoteImage: View {
    let url: URL
    var contentMode: ContentMode = .fill

    var body: some View {
        // ClipThumbnail과 같은 이유로: aspectRatio(.fill)는 제안보다 큰 크기를 보고해
        // 프레임 밖으로 번지므로, 제안 크기를 갖는 Color.clear 위에 올려 경계에서 잘라 낸다.
        Color.clear
            .overlay(
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: contentMode)
                    case .failure:
                        placeholder(systemImage: "photo")
                    case .empty:
                        ZStack {
                            placeholder(systemImage: "photo")
                            ProgressView().controlSize(.small)
                        }
                    @unknown default:
                        placeholder(systemImage: "photo")
                    }
                }
            )
            .background(Tokens.bgCardMuted)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.radiusThumbnail, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.radiusThumbnail, style: .continuous)
                    .strokeBorder(Tokens.borderSoft, lineWidth: Tokens.borderChipWidth)
            )
            .accessibilityLabel(L10n.text("링크 대표 이미지"))
    }

    private func placeholder(systemImage: String) -> some View {
        ZStack {
            Tokens.bgCard
            Image(systemName: systemImage)
                .foregroundStyle(Tokens.textTertiary)
        }
    }
}

/// 메타데이터 분석 전에도 썸네일 열을 예약해 제목 폭이 로딩 뒤 갑자기 줄지 않게 한다.
struct MetadataThumbnailPlaceholder: View {
    var isLoading = false

    var body: some View {
        ZStack {
            Tokens.bgCardMuted
            Image(systemName: "link")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Tokens.textTertiary)
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .offset(x: Tokens.cardGap, y: Tokens.cardGap)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.radiusThumbnail, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.radiusThumbnail, style: .continuous)
                .strokeBorder(Tokens.borderSoft, lineWidth: Tokens.borderChipWidth)
        )
        .accessibilityHidden(true)
    }
}

/// 링크 메타데이터 상세 표시. 기본은 요약 몇 줄만 접힌 상태로 보여 주고,
/// "자세히 보기"를 눌렀을 때만 추출된 섹션 전체를 펼친다.
struct MetadataDetailSectionsView: View {
    @Environment(URLMetadataCoordinator.self) private var metadata
    @Environment(AppStore.self) private var store
    @Environment(\.locale) private var locale
    let clip: Clip

    @State private var expanded: Bool = {
        #if DEBUG
        // ASO/검증 캡처 전용: 펼친 상태를 초기값으로 연다.
        if ProcessInfo.processInfo.environment["CLIP_INBOX_ASO_CAPTURE"] == "1",
           ProcessInfo.processInfo.environment["CLIP_INBOX_ASO_DETAIL_EXPANDED"] == "1" {
            return true
        }
        #endif
        return false
    }()

    /// 접힘 상태 요약 본문 최대 줄 수. 메타 한 줄을 더해도 5줄을 넘지 않는다.
    private static let collapsedSummaryLines = 4
    /// 펼침 상태에서도 항목 하나가 화면을 덮지 않도록 값 텍스트를 제한한다.
    private static let expandedValueLines = 5

    var body: some View {
        if let result = metadata.result(for: clip.id) {
            VStack(alignment: .leading, spacing: Tokens.rowGap) {
                HStack {
                    Text(L10n.text("링크 정보", locale: locale))
                        .font(Tokens.sectionTitle)
                        .foregroundStyle(Tokens.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: Tokens.rowGap)
                    Button {
                        withAnimation(.easeOut(duration: Tokens.motionBase)) {
                            expanded.toggle()
                        }
                    } label: {
                        HStack(spacing: Tokens.space1) {
                            Text(L10n.text(expanded ? "접기" : "자세히 보기", locale: locale))
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .buttonStyle(.plain)
                    .font(Tokens.bodySemibold)
                    .foregroundStyle(Tokens.textPrimary)
                    .accessibilityHint(L10n.text(expanded ? "링크 정보를 접습니다" : "링크 정보를 더 보여 줍니다", locale: locale))
                }

                if let summary = collapsedSummary(result) {
                    Text(summary)
                        .font(Tokens.body)
                        .foregroundStyle(Tokens.textPrimary)
                        .lineSpacing(Tokens.bodyLineSpacing)
                        .lineLimit(Self.collapsedSummaryLines)
                        .multilineTextAlignment(.leading)
                }

                if expanded {
                    expandedSections(result)
                }
            }
        } else if metadata.isAnalyzing(clip.id) {
            HStack(spacing: Tokens.rowGap) {
                ProgressView()
                Text(L10n.text("링크 정보를 분석하는 중입니다", locale: locale))
                    .font(Tokens.meta)
                    .foregroundStyle(Tokens.textSecondary)
            }
        } else if !clip.url.isEmpty {
            Button {
                Task { await metadata.analyze(clip: clip, store: store, forceRefresh: false) }
            } label: {
                Label(L10n.text("링크 정보 분석", locale: locale), systemImage: "sparkle.magnifyingglass")
            }
            .buttonStyle(.plain)
            .font(Tokens.bodySemibold)
            .foregroundStyle(Tokens.textPrimary)
        }
    }

    // MARK: - 접힘 상태

    private func collapsedSummary(_ result: LinkMetadataResult) -> String? {
        let candidates = [
            result.summaryDetail?.value,
            result.summaryShort?.value,
            result.description?.value
        ]
        for candidate in candidates {
            if let text = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                return text
            }
        }
        return nil
    }

    // MARK: - 펼침 상태

    private func expandedSections(_ result: LinkMetadataResult) -> some View {
        // 접힘 상태에서 이미 보여 준 요약과 같은 텍스트가 반복되지 않도록
        // "정보" 섹션의 요약 항목은 펼침 목록에서 제외한다.
        let collapsed = collapsedSummary(result)
        let sections = PresentationBuilder(language: .presentation(for: locale)).detailSections(from: result)
            .compactMap { section -> DetailPresentationSection? in
                let items = section.items.filter { item in
                    !(item.id == "summary" || (item.id == "description" && item.value == collapsed))
                }
                guard !items.isEmpty else { return nil }
                return DetailPresentationSection(id: section.id, title: section.title, items: items)
            }
        return VStack(alignment: .leading, spacing: Tokens.detailGap) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: Tokens.rowGap) {
                    Text(L10n.text(section.title, locale: locale))
                        .font(Tokens.metaBold)
                        .foregroundStyle(Tokens.textSecondary)
                        .accessibilityAddTraits(.isHeader)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(section.items) { item in
                            VStack(alignment: .leading, spacing: Tokens.space1) {
                                Text(L10n.text(item.label, locale: locale))
                                    .font(Tokens.metaBold)
                                    .foregroundStyle(Tokens.textSecondary)
                                Text(item.value)
                                    .font(Tokens.body)
                                    .foregroundStyle(Tokens.textPrimary)
                                    .lineLimit(Self.expandedValueLines)
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, Tokens.rowGap)
                            .overlay(alignment: .bottom) {
                                Tokens.borderSoft.frame(height: Tokens.borderChipWidth)
                            }
                        }
                    }
                }
            }
            Button {
                Task { await metadata.analyze(clip: clip, store: store, forceRefresh: true) }
            } label: {
                Label(L10n.text("링크 정보 다시 분석", locale: locale), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .font(Tokens.bodySemibold)
            .foregroundStyle(Tokens.textPrimary)
            .disabled(metadata.isAnalyzing(clip.id))
        }
    }
}
#endif
