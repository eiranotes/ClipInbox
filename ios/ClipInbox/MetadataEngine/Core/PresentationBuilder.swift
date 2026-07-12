import Foundation

public struct PresentationBuilder: Sendable {
    public init() {}

    public func mainCard(from result: LinkMetadataResult) -> MainCardPresentation {
        let title = result.title?.value ?? URL(string: result.bestOpenURL).map(HTMLTools.domainDisplayName) ?? result.bestOpenURL
        let typeLabel = localizedType(result.contentType, subtype: result.contentSubtype)
        var components: [String] = []
        if let creator = result.creator?.value { components.append(creator) }
        else if let site = result.siteName?.value { components.append(site) }
        else if !result.platform.isEmpty { components.append(result.platform) }
        components.append(typeLabel)
        if let key = keyValue(result) { components.append(key) }
        return MainCardPresentation(
            title: title,
            subtitle: unique(components).joined(separator: " · "),
            thumbnailURL: result.thumbnail?.value,
            contentTypeLabel: typeLabel,
            status: result.status
        )
    }

    public func detailSections(from result: LinkMetadataResult) -> [DetailPresentationSection] {
        var sections: [DetailPresentationSection] = []

        var overview: [DetailPresentationItem] = []
        append(&overview, id: "summary", label: "요약", value: result.summaryDetail?.value)
        append(&overview, id: "creator", label: creatorLabel(result), value: result.creator?.value)
        append(&overview, id: "site", label: "사이트", value: result.siteName?.value ?? result.platform)
        append(&overview, id: "published", label: "발행", value: displayDate(result.publishedAt?.value))
        append(&overview, id: "modified", label: "수정", value: displayDate(result.modifiedAt?.value))
        addSection(&sections, id: "overview", title: "정보", items: overview)

        var key: [DetailPresentationItem] = []
        append(&key, id: "type", label: "유형", value: localizedType(result.contentType, subtype: result.contentSubtype))
        if let duration = result.durationSeconds?.value { append(&key, id: "duration", label: "길이", value: formatDuration(duration)) }
        if let reading = result.readingMinutes?.value { append(&key, id: "reading", label: "읽기", value: "약 \(reading)분") }
        for attributeKey in orderedAttributeKeys where result.attributes[attributeKey] != nil {
            if let field = result.attributes[attributeKey], let value = display(field.value) {
                append(&key, id: attributeKey, label: label(attributeKey), value: value)
            }
        }
        addSection(&sections, id: "key", title: "핵심 정보", items: key)

        var content: [DetailPresentationItem] = []
        append(&content, id: "description", label: "원문 설명", value: result.description?.value)
        addSection(&sections, id: "content", title: "원문", items: content)

        let originalTags = flattenTags(result.originalTags)
        let derivedTags = flattenTags(result.derivedTopics)
        var tags: [DetailPresentationItem] = []
        append(&tags, id: "originalTags", label: "원본 태그", value: originalTags.isEmpty ? nil : originalTags.joined(separator: " · "))
        append(&tags, id: "derivedTopics", label: "앱 분류", value: derivedTags.isEmpty ? nil : derivedTags.joined(separator: " · "))
        addSection(&sections, id: "tags", title: "태그", items: tags)

        let known = Set(orderedAttributeKeys)
        let extras = result.attributes.keys.filter { !known.contains($0) }.sorted().compactMap { key -> DetailPresentationItem? in
            guard let value = display(result.attributes[key]?.value) else { return nil }
            return .init(id: key, label: label(key), value: value)
        }
        addSection(&sections, id: "additional", title: "추가 정보", items: extras)

        var source: [DetailPresentationItem] = []
        append(&source, id: "url", label: "URL", value: result.bestOpenURL)
        append(&source, id: "status", label: "수집 상태", value: localizedStatus(result.status))
        if let status = result.http?.statusCode { append(&source, id: "http", label: "HTTP", value: String(status)) }
        if let mime = result.http?.contentType { append(&source, id: "mime", label: "형식", value: mime) }
        addSection(&sections, id: "source", title: "링크와 수집", items: source)
        return sections
    }

    private let orderedAttributeKeys = [
        "price", "currency", "brand", "availability", "repositoryFullName", "repository", "owner",
        "primaryLanguage", "mainLanguage", "license", "defaultBranch", "isArchived", "topics",
        "issueNumber", "pullRequestNumber", "state", "doi", "publication", "version", "developer",
        "category", "pageCount", "fileName", "fileSizeBytes", "language", "section"
    ]

    private func keyValue(_ result: LinkMetadataResult) -> String? {
        let type = result.contentType.lowercased()
        let subtype = result.contentSubtype?.lowercased()

        if ["video", "audio", "videoobject", "audioobject"].contains(type), let duration = result.durationSeconds?.value {
            return formatDuration(duration)
        }
        if (type == "softwaresourcecode" && subtype == "repository") || type == "repository" {
            for key in ["primaryLanguage", "mainLanguage"] {
                if let value = display(result.attributes[key]?.value) { return value }
            }
        }
        if type == "product", let price = display(result.attributes["price"]?.value) { return price }
        if ["article", "newsarticle", "blogposting", "techarticle", "scholarlyarticle"].contains(type),
           let reading = result.readingMinutes?.value {
            return "\(reading)분"
        }
        for key in ["primaryLanguage", "mainLanguage", "publication", "category", "price"] {
            if let value = display(result.attributes[key]?.value) { return value }
        }
        if let duration = result.durationSeconds?.value { return formatDuration(duration) }
        if let reading = result.readingMinutes?.value { return "\(reading)분" }
        return nil
    }

    private func localizedType(_ type: String, subtype: String?) -> String {
        let key = type.lowercased()
        let subtypeKey = subtype?.lowercased()

        if key == "softwaresourcecode" {
            return subtypeKey == "repository" ? "GitHub 저장소" : "소스 코드"
        }
        if key == "softwarerelease" { return "소프트웨어 릴리스" }
        if key == "code" {
            switch subtypeKey {
            case "gist": return "GitHub Gist"
            case "commit": return "GitHub 커밋"
            case "file": return "소스 파일"
            case "directory": return "소스 디렉터리"
            default: return "코드"
            }
        }
        if key == "discussion" {
            switch subtypeKey {
            case "issue": return "GitHub 이슈"
            case "pullrequest": return "Pull Request"
            case "redditpost": return "Reddit 게시물"
            default: break
            }
        }
        if key == "collection" {
            switch subtypeKey {
            case "playlist": return "재생목록"
            case "subreddit": return "Subreddit"
            default: return "컬렉션"
            }
        }

        return [
            "webpage": "웹페이지", "article": "글", "newsarticle": "뉴스", "blogposting": "블로그 글",
            "techarticle": "기술 문서", "report": "보고서", "book": "책", "video": "영상",
            "audio": "오디오", "product": "상품", "softwareapplication": "앱",
            "mobileapplication": "모바일 앱", "webapplication": "웹 앱", "application": "앱",
            "scholarlyarticle": "논문", "repository": "GitHub 저장소", "issue": "GitHub 이슈",
            "pullrequest": "Pull Request", "socialpost": "SNS 게시물",
            "socialmediaposting": "SNS 게시물", "discussionforumposting": "포럼 게시물",
            "discussion": "토론", "document": "문서", "image": "이미지", "file": "파일",
            "place": "장소", "localbusiness": "장소·업체", "event": "이벤트", "recipe": "레시피",
            "profile": "프로필", "profilepage": "프로필", "person": "인물", "organization": "조직",
            "collection": "컬렉션", "code": "코드", "softwaresourcecode": "소스 코드",
            "softwarerelease": "소프트웨어 릴리스"
        ][key] ?? type
    }

    private func creatorLabel(_ result: LinkMetadataResult) -> String {
        ["video", "audio", "videoobject", "audioobject"].contains(result.contentType.lowercased()) ? "채널·작성자" : "작성자"
    }

    private func localizedStatus(_ status: MetadataStatus) -> String {
        switch status {
        case .pending: return "분석 중"
        case .complete: return "완료"
        case .partial: return "일부 정보"
        case .blocked: return "접근 차단"
        case .loginRequired: return "로그인 필요"
        case .removed: return "삭제됨"
        case .unsupported: return "지원되지 않음"
        case .failed: return "분석 실패"
        }
    }

    private func label(_ key: String) -> String {
        [
            "price": "가격", "currency": "통화", "brand": "브랜드", "availability": "재고",
            "primaryLanguage": "주 언어", "mainLanguage": "주 언어", "license": "라이선스",
            "repositoryFullName": "저장소", "repository": "저장소", "owner": "소유자",
            "defaultBranch": "기본 브랜치", "isArchived": "보관됨", "issueNumber": "이슈 번호",
            "pullRequestNumber": "PR 번호", "state": "상태", "doi": "DOI", "publication": "학술지·매체",
            "version": "버전", "developer": "개발사", "category": "카테고리", "pageCount": "페이지",
            "fileName": "파일명", "fileSizeBytes": "파일 크기", "language": "언어", "section": "섹션",
            "readmeExcerpt": "README", "readmeHeadings": "README 목차", "topics": "토픽", "abstract": "초록",
            "videoID": "영상 ID", "channelID": "채널 ID", "playlistID": "재생목록 ID", "subreddit": "Subreddit"
        ][key] ?? key.replacingOccurrences(of: #"([a-z0-9])([A-Z])"#, with: "$1 $2", options: .regularExpression).capitalized
    }

    private func display(_ value: JSONValue?) -> String? {
        guard let value else { return nil }
        switch value {
        case .string(let string): return string.isEmpty ? nil : string
        case .number(let number):
            if number.rounded() == number { return String(Int64(number)) }
            return String(number)
        case .bool(let bool): return bool ? "예" : "아니요"
        case .array(let values):
            let strings = values.compactMap(display)
            return strings.isEmpty ? nil : strings.joined(separator: " · ")
        case .object(let values):
            let strings = values.sorted(by: { $0.key < $1.key }).compactMap { key, value in display(value).map { "\(key): \($0)" } }
            return strings.isEmpty ? nil : strings.joined(separator: " · ")
        case .null: return nil
        }
    }

    private func displayDate(_ value: String?) -> String? {
        guard let value else { return nil }
        if let date = ISO8601DateFormatter.clipInbox.date(from: value) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
        return value
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remaining = seconds % 60
        if hours > 0 { return minutes > 0 ? "\(hours)시간 \(minutes)분" : "\(hours)시간" }
        if minutes > 0 { return "\(minutes)분" }
        return "\(remaining)초"
    }

    private func flattenTags(_ fields: [ExtractedField<[String]>]) -> [String] {
        var seen = Set<String>()
        return fields.flatMap(\.value).filter { seen.insert($0.lowercased()).inserted }
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0.lowercased()).inserted }
    }

    private func append(_ array: inout [DetailPresentationItem], id: String, label: String, value: String?) {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return }
        array.append(.init(id: id, label: label, value: value))
    }

    private func addSection(_ sections: inout [DetailPresentationSection], id: String, title: String, items: [DetailPresentationItem]) {
        guard !items.isEmpty else { return }
        sections.append(.init(id: id, title: title, items: items))
    }
}
