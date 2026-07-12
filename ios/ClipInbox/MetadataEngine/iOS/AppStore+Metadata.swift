import Foundation

extension AppStore {
    /// 기존 version-2 Clip JSON 스키마를 유지하면서, 사용자가 직접 편집하지 않은 자리표시자만 보수적으로 갱신한다.
    @MainActor
    func applyExtractedMetadata(_ result: LinkMetadataResult, to clipID: Int) {
        guard let index = clips.firstIndex(where: { $0.id == clipID }), clips[index].type == .link else { return }
        var clip = clips[index]
        var changed = false

        if Self.isMetadataPlaceholderTitle(clip.title, url: clip.url), let title = result.title?.value, !title.isEmpty {
            clip.title = String(title.prefix(200))
            changed = true
        }

        if Self.isMetadataPlaceholderSource(clip.source, url: clip.url) {
            let presentation = PresentationBuilder().mainCard(from: result)
            if !presentation.subtitle.isEmpty {
                clip.source = String(presentation.subtitle.prefix(120))
                changed = true
            }
        }

        if clip.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let summary = result.summaryDetail?.value ?? result.description?.value,
           !summary.isEmpty {
            clip.description = String(summary.prefix(500))
            changed = true
        }

        guard changed else { return }
        clips[index] = clip
        _ = persist()
    }

    static func isMetadataPlaceholderTitle(_ title: String, url: String) -> Bool {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = URL(string: url)?.host?.lowercased()
        return value.isEmpty
            || ["공유한 링크", "제목 없는 클립", "untitled"].contains(value.lowercased())
            || value.lowercased() == host
            || value.lowercased() == host?.replacingOccurrences(of: "www.", with: "")
    }

    static func isMetadataPlaceholderSource(_ source: String, url: String) -> Bool {
        let value = source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let host = URL(string: url)?.host?.lowercased()
        return value.isEmpty
            || ["공유 시트", "출처 없음", "직접 추가"].contains(value)
            || value == host
            || value == host?.replacingOccurrences(of: "www.", with: "")
    }
}
