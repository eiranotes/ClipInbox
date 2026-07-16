import Foundation

/// 카드·상세 표시 문자열의 언어. 엔진은 UI 프레임워크를 모르는 채로
/// 표시 언어만 주입받아 유형·상태·기간 같은 파생 문자열을 현지화한다.
public enum PresentationLanguage: String, Sendable {
    case korean = "ko"
    case english = "en"
    case japanese = "ja"
}

public struct PresentationBuilder: Sendable {
    private let language: PresentationLanguage

    public init(language: PresentationLanguage = .korean) {
        self.language = language
    }

    public func mainCard(from result: LinkMetadataResult) -> MainCardPresentation {
        let title = githubRepositoryTitle(result)
            ?? result.title?.value
            ?? URL(string: result.bestOpenURL).map(HTMLTools.domainDisplayName)
            ?? result.bestOpenURL
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
        append(&overview, id: "summary", label: t("요약", "Summary", "要約"), value: result.summaryDetail?.value)
        append(&overview, id: "creator", label: creatorLabel(result), value: result.creator?.value)
        append(&overview, id: "site", label: t("사이트", "Site", "サイト"), value: result.siteName?.value ?? result.platform)
        append(&overview, id: "published", label: t("발행", "Published", "公開"), value: displayDate(result.publishedAt?.value))
        append(&overview, id: "modified", label: t("수정", "Updated", "更新"), value: displayDate(result.modifiedAt?.value))
        addSection(&sections, id: "overview", title: t("정보", "Overview", "情報"), items: overview)

        var key: [DetailPresentationItem] = []
        append(&key, id: "type", label: t("유형", "Type", "種類"), value: localizedType(result.contentType, subtype: result.contentSubtype))
        if let duration = result.durationSeconds?.value { append(&key, id: "duration", label: t("길이", "Duration", "長さ"), value: formatDuration(duration)) }
        if let reading = result.readingMinutes?.value { append(&key, id: "reading", label: t("읽기", "Reading", "読了"), value: formatReading(reading)) }
        for attributeKey in orderedAttributeKeys where result.attributes[attributeKey] != nil {
            if let field = result.attributes[attributeKey], let value = display(field.value) {
                append(&key, id: attributeKey, label: label(attributeKey), value: value)
            }
        }
        addSection(&sections, id: "key", title: t("핵심 정보", "Key Details", "主要情報"), items: key)

        var content: [DetailPresentationItem] = []
        append(&content, id: "description", label: t("원문 설명", "Original Description", "原文の説明"), value: result.description?.value)
        addSection(&sections, id: "content", title: t("원문", "Original", "原文"), items: content)

        let originalTags = flattenTags(result.originalTags)
        let derivedTags = flattenTags(result.derivedTopics)
        var tags: [DetailPresentationItem] = []
        append(&tags, id: "originalTags", label: t("원본 태그", "Original Tags", "元のタグ"), value: originalTags.isEmpty ? nil : originalTags.joined(separator: " · "))
        append(&tags, id: "derivedTopics", label: t("앱 분류", "App Topics", "アプリ分類"), value: derivedTags.isEmpty ? nil : derivedTags.joined(separator: " · "))
        addSection(&sections, id: "tags", title: t("태그", "Tags", "タグ"), items: tags)

        let known = Set(orderedAttributeKeys)
        let extras = result.attributes.keys.filter { !known.contains($0) }.sorted().compactMap { key -> DetailPresentationItem? in
            guard let value = display(result.attributes[key]?.value) else { return nil }
            return .init(id: key, label: label(key), value: value)
        }
        addSection(&sections, id: "additional", title: t("추가 정보", "More Details", "追加情報"), items: extras)

        var source: [DetailPresentationItem] = []
        append(&source, id: "url", label: "URL", value: result.bestOpenURL)
        append(&source, id: "status", label: t("수집 상태", "Collection Status", "収集状態"), value: localizedStatus(result.status))
        if let status = result.http?.statusCode { append(&source, id: "http", label: "HTTP", value: String(status)) }
        if let mime = result.http?.contentType { append(&source, id: "mime", label: t("형식", "Format", "形式"), value: mime) }
        addSection(&sections, id: "source", title: t("링크와 수집", "Link & Collection", "リンクと収集"), items: source)
        return sections
    }

    private let orderedAttributeKeys = [
        "price", "currency", "brand", "availability", "repositoryFullName", "repository", "owner",
        "primaryLanguage", "mainLanguage", "license", "defaultBranch", "isArchived", "topics",
        "issueNumber", "pullRequestNumber", "state", "doi", "publication", "version", "developer",
        "category", "pageCount", "fileName", "fileSizeBytes", "language", "section"
    ]

    /// 언어별 문자열 선택자.
    private func t(_ korean: String, _ english: String, _ japanese: String) -> String {
        switch language {
        case .korean: return korean
        case .english: return english
        case .japanese: return japanese
        }
    }

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
            return formatMinutes(reading)
        }
        for key in ["primaryLanguage", "mainLanguage", "publication", "category", "price"] {
            if let value = display(result.attributes[key]?.value) { return value }
        }
        if let duration = result.durationSeconds?.value { return formatDuration(duration) }
        if let reading = result.readingMinutes?.value { return formatMinutes(reading) }
        return nil
    }

    /// GitHub 저장소 페이지는 문서 설명이 붙은 HTML 제목 대신 스캔하기 쉬운 owner/repository만 쓴다.
    private func githubRepositoryTitle(_ result: LinkMetadataResult) -> String? {
        guard result.platform.caseInsensitiveCompare("GitHub") == .orderedSame,
              result.contentSubtype?.caseInsensitiveCompare("repository") == .orderedSame else {
            return nil
        }
        if let fullName = display(result.attributes["repositoryFullName"]?.value) {
            return fullName.replacingOccurrences(of: " / ", with: "/")
        }
        guard let owner = display(result.attributes["owner"]?.value),
              let repository = display(result.attributes["repository"]?.value) else {
            return nil
        }
        return "\(owner)/\(repository)"
    }

    private func localizedType(_ type: String, subtype: String?) -> String {
        let key = type.lowercased()
        let subtypeKey = subtype?.lowercased()

        if key == "softwaresourcecode" {
            return subtypeKey == "repository"
                ? t("GitHub 저장소", "GitHub Repository", "GitHubリポジトリ")
                : t("소스 코드", "Source Code", "ソースコード")
        }
        if key == "softwarerelease" { return t("소프트웨어 릴리스", "Software Release", "ソフトウェアリリース") }
        if key == "code" {
            switch subtypeKey {
            case "gist": return "GitHub Gist"
            case "commit": return t("GitHub 커밋", "GitHub Commit", "GitHubコミット")
            case "file": return t("소스 파일", "Source File", "ソースファイル")
            case "directory": return t("소스 디렉터리", "Source Directory", "ソースディレクトリ")
            default: return t("코드", "Code", "コード")
            }
        }
        if key == "discussion" {
            switch subtypeKey {
            case "issue": return t("GitHub 이슈", "GitHub Issue", "GitHubイシュー")
            case "pullrequest": return "Pull Request"
            case "redditpost": return t("Reddit 게시물", "Reddit Post", "Reddit投稿")
            default: break
            }
        }
        if key == "collection" {
            switch subtypeKey {
            case "playlist": return t("재생목록", "Playlist", "再生リスト")
            case "subreddit": return "Subreddit"
            default: return t("컬렉션", "Collection", "コレクション")
            }
        }

        let table: [String: (String, String, String)] = [
            "webpage": ("웹페이지", "Webpage", "ウェブページ"),
            "article": ("글", "Article", "記事"),
            "newsarticle": ("뉴스", "News", "ニュース"),
            "blogposting": ("블로그 글", "Blog Post", "ブログ記事"),
            "techarticle": ("기술 문서", "Tech Article", "技術記事"),
            "report": ("보고서", "Report", "レポート"),
            "book": ("책", "Book", "書籍"),
            "video": ("영상", "Video", "動画"),
            "audio": ("오디오", "Audio", "オーディオ"),
            "product": ("상품", "Product", "商品"),
            "softwareapplication": ("앱", "App", "アプリ"),
            "mobileapplication": ("모바일 앱", "Mobile App", "モバイルアプリ"),
            "webapplication": ("웹 앱", "Web App", "ウェブアプリ"),
            "application": ("앱", "App", "アプリ"),
            "scholarlyarticle": ("논문", "Paper", "論文"),
            "repository": ("GitHub 저장소", "GitHub Repository", "GitHubリポジトリ"),
            "issue": ("GitHub 이슈", "GitHub Issue", "GitHubイシュー"),
            "pullrequest": ("Pull Request", "Pull Request", "Pull Request"),
            "socialpost": ("SNS 게시물", "Social Post", "SNS投稿"),
            "socialmediaposting": ("SNS 게시물", "Social Post", "SNS投稿"),
            "discussionforumposting": ("포럼 게시물", "Forum Post", "フォーラム投稿"),
            "discussion": ("토론", "Discussion", "ディスカッション"),
            "document": ("문서", "Document", "ドキュメント"),
            "image": ("이미지", "Image", "画像"),
            "file": ("파일", "File", "ファイル"),
            "place": ("장소", "Place", "スポット"),
            "localbusiness": ("장소·업체", "Place / Business", "スポット・店舗"),
            "event": ("이벤트", "Event", "イベント"),
            "recipe": ("레시피", "Recipe", "レシピ"),
            "profile": ("프로필", "Profile", "プロフィール"),
            "profilepage": ("프로필", "Profile", "プロフィール"),
            "person": ("인물", "Person", "人物"),
            "organization": ("조직", "Organization", "組織"),
            "collection": ("컬렉션", "Collection", "コレクション"),
            "code": ("코드", "Code", "コード"),
            "softwaresourcecode": ("소스 코드", "Source Code", "ソースコード"),
            "softwarerelease": ("소프트웨어 릴리스", "Software Release", "ソフトウェアリリース")
        ]
        if let entry = table[key] { return t(entry.0, entry.1, entry.2) }
        return type
    }

    private func creatorLabel(_ result: LinkMetadataResult) -> String {
        ["video", "audio", "videoobject", "audioobject"].contains(result.contentType.lowercased())
            ? t("채널·작성자", "Channel / Author", "チャンネル・作成者")
            : t("작성자", "Author", "作成者")
    }

    private func localizedStatus(_ status: MetadataStatus) -> String {
        switch status {
        case .pending: return t("분석 중", "Analyzing", "分析中")
        case .complete: return t("완료", "Complete", "完了")
        case .partial: return t("일부 정보", "Partial", "一部のみ")
        case .blocked: return t("접근 차단", "Blocked", "アクセス制限")
        case .loginRequired: return t("로그인 필요", "Login Required", "ログインが必要")
        case .removed: return t("삭제됨", "Removed", "削除済み")
        case .unsupported: return t("지원되지 않음", "Unsupported", "未対応")
        case .failed: return t("분석 실패", "Failed", "分析失敗")
        }
    }

    private func label(_ key: String) -> String {
        let table: [String: (String, String, String)] = [
            "price": ("가격", "Price", "価格"),
            "currency": ("통화", "Currency", "通貨"),
            "brand": ("브랜드", "Brand", "ブランド"),
            "availability": ("재고", "Availability", "在庫"),
            "primaryLanguage": ("주 언어", "Primary Language", "主要言語"),
            "mainLanguage": ("주 언어", "Primary Language", "主要言語"),
            "license": ("라이선스", "License", "ライセンス"),
            "repositoryFullName": ("저장소", "Repository", "リポジトリ"),
            "repository": ("저장소", "Repository", "リポジトリ"),
            "owner": ("소유자", "Owner", "オーナー"),
            "defaultBranch": ("기본 브랜치", "Default Branch", "デフォルトブランチ"),
            "isArchived": ("보관됨", "Archived", "アーカイブ済み"),
            "issueNumber": ("이슈 번호", "Issue Number", "イシュー番号"),
            "pullRequestNumber": ("PR 번호", "PR Number", "PR番号"),
            "state": ("상태", "State", "状態"),
            "doi": ("DOI", "DOI", "DOI"),
            "publication": ("학술지·매체", "Publication", "掲載媒体"),
            "version": ("버전", "Version", "バージョン"),
            "developer": ("개발사", "Developer", "開発元"),
            "category": ("카테고리", "Category", "カテゴリ"),
            "pageCount": ("페이지", "Pages", "ページ数"),
            "fileName": ("파일명", "File Name", "ファイル名"),
            "fileSizeBytes": ("파일 크기", "File Size", "ファイルサイズ"),
            "language": ("언어", "Language", "言語"),
            "section": ("섹션", "Section", "セクション"),
            "readmeExcerpt": ("README", "README", "README"),
            "readmeHeadings": ("README 목차", "README Headings", "README目次"),
            "topics": ("토픽", "Topics", "トピック"),
            "abstract": ("초록", "Abstract", "要旨"),
            "videoID": ("영상 ID", "Video ID", "動画ID"),
            "channelID": ("채널 ID", "Channel ID", "チャンネルID"),
            "playlistID": ("재생목록 ID", "Playlist ID", "再生リストID"),
            "subreddit": ("Subreddit", "Subreddit", "Subreddit")
        ]
        if let entry = table[key] { return t(entry.0, entry.1, entry.2) }
        return key.replacingOccurrences(of: #"([a-z0-9])([A-Z])"#, with: "$1 $2", options: .regularExpression).capitalized
    }

    private func display(_ value: JSONValue?) -> String? {
        guard let value else { return nil }
        switch value {
        case .string(let string): return string.isEmpty ? nil : string
        case .number(let number):
            if number.rounded() == number { return String(Int64(number)) }
            return String(number)
        case .bool(let bool): return bool ? t("예", "Yes", "はい") : t("아니요", "No", "いいえ")
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
            formatter.locale = Locale(identifier: t("ko_KR", "en_US", "ja_JP"))
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
        switch language {
        case .korean:
            if hours > 0 { return minutes > 0 ? "\(hours)시간 \(minutes)분" : "\(hours)시간" }
            if minutes > 0 { return "\(minutes)분" }
            return "\(remaining)초"
        case .english:
            if hours > 0 { return minutes > 0 ? "\(hours) hr \(minutes) min" : "\(hours) hr" }
            if minutes > 0 { return "\(minutes) min" }
            return "\(remaining) sec"
        case .japanese:
            if hours > 0 { return minutes > 0 ? "\(hours)時間\(minutes)分" : "\(hours)時間" }
            if minutes > 0 { return "\(minutes)分" }
            return "\(remaining)秒"
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        t("\(minutes)분", "\(minutes) min", "\(minutes)分")
    }

    private func formatReading(_ minutes: Int) -> String {
        t("약 \(minutes)분", "~\(minutes) min", "約\(minutes)分")
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
