import Foundation

struct RedditAdapter: PlatformAdapter {
    let identifier = "reddit"

    func matches(_ url: URL) -> Bool {
        let host = url.lowercasedHost
        return host == "redd.it" || host == "reddit.com" || host.hasSuffix(".reddit.com")
    }

    func extract(_ context: PlatformAdapterContext) -> MetadataFragment {
        var fragment = MetadataFragment()
        fragment.platformCandidates.append(.init(value: "Reddit", confidence: 1.0, source: .urlPattern))
        let parts = context.url.decodedPathComponents

        if context.url.lowercasedHost == "redd.it", let id = parts.first {
            fragment.contentTypeCandidates.append(.init(value: "discussion", confidence: 0.95, source: .urlPattern))
            fragment.contentSubtypeCandidates.append(.init(value: "post", confidence: 0.96, source: .urlPattern))
            fragment.addAttribute("postID", value: .string(id), source: .urlPattern, confidence: 1.0)
        } else if parts.first?.lowercased() == "r", parts.count >= 2 {
            let subreddit = parts[1]
            fragment.addAttribute("subreddit", value: .string(subreddit), source: .urlPattern, confidence: 1.0)
            if parts.count >= 4, parts[2].lowercased() == "comments" {
                fragment.contentTypeCandidates.append(.init(value: "discussion", confidence: 0.96, source: .urlPattern))
                fragment.contentSubtypeCandidates.append(.init(value: "post", confidence: 0.98, source: .urlPattern))
                fragment.addAttribute("postID", value: .string(parts[3]), source: .urlPattern, confidence: 1.0)
            } else {
                fragment.contentTypeCandidates.append(.init(value: "collection", confidence: 0.94, source: .urlPattern))
                fragment.contentSubtypeCandidates.append(.init(value: "subreddit", confidence: 0.98, source: .urlPattern))
            }
        } else if ["u", "user"].contains(parts.first?.lowercased() ?? ""), parts.count >= 2 {
            fragment.contentTypeCandidates.append(.init(value: "profile", confidence: 0.96, source: .urlPattern))
            fragment.contentSubtypeCandidates.append(.init(value: "user", confidence: 0.98, source: .urlPattern))
            fragment.addAttribute("username", value: .string(parts[1]), source: .urlPattern, confidence: 1.0)
        }

        if let html = context.document?.html {
            let lower = html.lowercased()
            if lower.contains("over_18") || lower.contains("nsfw") || lower.contains("adult content") {
                fragment.addAttribute("isNSFW", value: .bool(true), source: .semanticDOM, confidence: 0.82)
            }
            if let flair = extractFlair(html) {
                fragment.addAttribute("flair", value: .string(flair), source: .semanticDOM, confidence: 0.76)
                fragment.originalTagCandidates.append(.init(value: [flair], source: .semanticDOM, confidence: 0.70))
            }
        }
        return fragment
    }

    private func extractFlair(_ html: String) -> String? {
        let pattern = #"<[^>]+(?:class|data-testid)=['\"][^'\"]*(?:flair|post-flair)[^'\"]*['\"][^>]*>(.*?)</[^>]+>"#
        guard let match = HTMLTools.firstMatch(pattern, in: html), match.count > 1 else { return nil }
        let value = HTMLTools.cleanText(match[1])
        return value.isEmpty ? nil : value
    }
}

struct NaverBlogAdapter: PlatformAdapter {
    let identifier = "naver-blog"

    func matches(_ url: URL) -> Bool {
        ["blog.naver.com", "m.blog.naver.com", "post.naver.com"].contains(url.lowercasedHost)
    }

    func extract(_ context: PlatformAdapterContext) -> MetadataFragment {
        var fragment = MetadataFragment()
        let isPost = context.url.lowercasedHost == "post.naver.com"
        fragment.platformCandidates.append(.init(value: isPost ? "네이버 포스트" : "네이버 블로그", confidence: 1.0, source: .urlPattern))
        fragment.contentTypeCandidates.append(.init(value: "article", confidence: 0.94, source: .urlPattern))
        fragment.contentSubtypeCandidates.append(.init(value: isPost ? "naverPost" : "naverBlogPost", confidence: 0.96, source: .urlPattern))

        let parts = context.url.decodedPathComponents
        let query = context.url.queryDictionary
        if !isPost {
            let blogID = query["blogId"] ?? parts.first
            let logNo = query["logNo"] ?? (parts.count > 1 ? parts[1] : nil)
            if let blogID { fragment.addAttribute("blogID", value: .string(blogID), source: .urlPattern, confidence: 0.96) }
            if let logNo, logNo.allSatisfy(\.isNumber) {
                fragment.addAttribute("postID", value: .string(logNo), source: .urlPattern, confidence: 1.0)
            }
        }

        guard let document = context.document else { return fragment }
        for tagName in ["iframe", "frame"] {
            for attributes in HTMLTools.tags(named: tagName, in: document.html).prefix(50) {
                let hint = ((attributes["id"] ?? "") + " " + (attributes["name"] ?? "") + " " + (attributes["title"] ?? "")).lowercased()
                guard hint.contains("mainframe") || hint.contains("screenframe") || hint.contains("postview") else { continue }
                if let url = HTMLTools.resolveURL(attributes["src"], relativeTo: context.url),
                   let host = URL(string: url)?.lowercasedHost,
                   host.hasSuffix("naver.com") {
                    fragment.explicitContentDocumentURLs.append(url)
                    fragment.addAttribute("contentDocumentURL", value: .string(url), source: .semanticDOM, confidence: 0.94)
                }
            }
        }
        return fragment
    }
}

struct KoreanPublishingAdapter: PlatformAdapter {
    let identifier = "korean-publishing"

    private let platforms: [(suffix: String, name: String, subtype: String)] = [
        ("tistory.com", "티스토리", "blogPost"),
        ("brunch.co.kr", "브런치스토리", "blogPost"),
        ("velog.io", "Velog", "techArticle"),
        ("news.naver.com", "네이버 뉴스", "newsArticle"),
        ("n.news.naver.com", "네이버 뉴스", "newsArticle"),
        ("news.v.daum.net", "다음 뉴스", "newsArticle"),
        ("v.daum.net", "다음", "article"),
        ("cafe.naver.com", "네이버 카페", "forumPost")
    ]

    func matches(_ url: URL) -> Bool {
        platforms.contains { url.lowercasedHost == $0.suffix || url.lowercasedHost.hasSuffix(".\($0.suffix)") }
    }

    func extract(_ context: PlatformAdapterContext) -> MetadataFragment {
        var fragment = MetadataFragment()
        guard let platform = platforms.first(where: { context.url.lowercasedHost == $0.suffix || context.url.lowercasedHost.hasSuffix(".\($0.suffix)") }) else { return fragment }
        fragment.platformCandidates.append(.init(value: platform.name, confidence: 0.98, source: .urlPattern))
        fragment.contentTypeCandidates.append(.init(value: platform.subtype == "forumPost" ? "discussion" : "article", confidence: 0.90, source: .urlPattern))
        fragment.contentSubtypeCandidates.append(.init(value: platform.subtype, confidence: 0.94, source: .urlPattern))
        return fragment
    }
}

struct SocialPlatformAdapter: PlatformAdapter {
    let identifier = "social"

    private let hostMap: [(suffix: String, platform: String)] = [
        ("instagram.com", "Instagram"),
        ("threads.net", "Threads"),
        ("x.com", "X"),
        ("tiktok.com", "TikTok"),
        ("facebook.com", "Facebook"),
        ("linkedin.com", "LinkedIn"),
        ("pinterest.com", "Pinterest")
    ]

    func matches(_ url: URL) -> Bool {
        hostMap.contains { url.lowercasedHost == $0.suffix || url.lowercasedHost.hasSuffix(".\($0.suffix)") }
    }

    func extract(_ context: PlatformAdapterContext) -> MetadataFragment {
        var fragment = MetadataFragment()
        guard let match = hostMap.first(where: { context.url.lowercasedHost == $0.suffix || context.url.lowercasedHost.hasSuffix(".\($0.suffix)") }) else { return fragment }
        fragment.platformCandidates.append(.init(value: match.platform, confidence: 1.0, source: .urlPattern))
        let facts = classify(platform: match.platform, url: context.url)
        fragment.contentTypeCandidates.append(.init(value: facts.contentType, confidence: 0.94, source: .urlPattern))
        fragment.contentSubtypeCandidates.append(.init(value: facts.subtype, confidence: 0.96, source: .urlPattern))
        for (key, value) in facts.identifiers {
            fragment.addAttribute(key, value: .string(value), source: .urlPattern, confidence: 1.0)
        }

        if let text = context.genericFragment.descriptionCandidates.first?.value {
            let hashtags = HTMLTools.hashtags(in: text)
            if !hashtags.isEmpty {
                fragment.originalTagCandidates.append(.init(value: hashtags, source: .semanticDOM, confidence: 0.76))
            }
        }
        return fragment
    }

    private func classify(platform: String, url: URL) -> SocialFacts {
        let parts = url.decodedPathComponents
        switch platform {
        case "Instagram":
            if let first = parts.first, ["p", "reel", "tv"].contains(first.lowercased()), parts.count > 1 {
                return .init(contentType: first.lowercased() == "p" ? "socialPost" : "video", subtype: first.lowercased() == "reel" ? "reel" : "post", identifiers: ["shortcode": parts[1]])
            }
            return .init(contentType: "profile", subtype: "profile", identifiers: parts.first.map { ["username": $0] } ?? [:])
        case "Threads":
            var identifiers: [String: String] = [:]
            if let account = parts.first?.trimmingCharacters(in: CharacterSet(charactersIn: "@")), !account.isEmpty { identifiers["username"] = account }
            if let postIndex = parts.firstIndex(where: { $0.lowercased() == "post" }), parts.indices.contains(postIndex + 1) { identifiers["postID"] = parts[postIndex + 1] }
            return .init(contentType: identifiers["postID"] == nil ? "profile" : "socialPost", subtype: identifiers["postID"] == nil ? "profile" : "post", identifiers: identifiers)
        case "X":
            var identifiers: [String: String] = [:]
            if let username = parts.first { identifiers["username"] = username }
            if parts.count > 2, parts[1].lowercased() == "status" { identifiers["statusID"] = parts[2] }
            return .init(contentType: identifiers["statusID"] == nil ? "profile" : "socialPost", subtype: identifiers["statusID"] == nil ? "profile" : "status", identifiers: identifiers)
        case "TikTok":
            var identifiers: [String: String] = [:]
            if let username = parts.first?.trimmingCharacters(in: CharacterSet(charactersIn: "@")), !username.isEmpty { identifiers["username"] = username }
            if let videoIndex = parts.firstIndex(where: { $0.lowercased() == "video" }), parts.indices.contains(videoIndex + 1) { identifiers["videoID"] = parts[videoIndex + 1] }
            return .init(contentType: identifiers["videoID"] == nil ? "profile" : "video", subtype: identifiers["videoID"] == nil ? "profile" : "shortVideo", identifiers: identifiers)
        case "Pinterest":
            if parts.first?.lowercased() == "pin", parts.count > 1 {
                return .init(contentType: "image", subtype: "pin", identifiers: ["pinID": parts[1]])
            }
            return .init(contentType: "profile", subtype: "profile", identifiers: [:])
        default:
            return .init(contentType: "socialPost", subtype: "publicPage", identifiers: [:])
        }
    }

    private struct SocialFacts {
        var contentType: String
        var subtype: String
        var identifiers: [String: String]
    }
}

struct AppMarketplaceAdapter: PlatformAdapter {
    let identifier = "app-marketplace"

    func matches(_ url: URL) -> Bool {
        let host = url.lowercasedHost
        return host == "apps.apple.com" || host == "play.google.com" || host == "store.steampowered.com" || host.hasSuffix("epicgames.com")
    }

    func extract(_ context: PlatformAdapterContext) -> MetadataFragment {
        var fragment = MetadataFragment()
        let host = context.url.lowercasedHost
        let platform: String
        let targetPlatform: String
        if host == "apps.apple.com" { platform = "App Store"; targetPlatform = "Apple" }
        else if host == "play.google.com" { platform = "Google Play"; targetPlatform = "Android" }
        else if host == "store.steampowered.com" { platform = "Steam"; targetPlatform = "PC" }
        else { platform = "Epic Games Store"; targetPlatform = "PC" }
        fragment.platformCandidates.append(.init(value: platform, confidence: 1.0, source: .urlPattern))
        fragment.contentTypeCandidates.append(.init(value: "softwareApplication", confidence: 0.98, source: .urlPattern))
        fragment.contentSubtypeCandidates.append(.init(value: platform.contains("Store") || platform == "Steam" ? "appOrGame" : "application", confidence: 0.88, source: .urlPattern))
        fragment.addAttribute("platform", value: .string(targetPlatform), source: .urlPattern, confidence: 0.96)
        if host == "play.google.com", let id = context.url.queryDictionary["id"] {
            fragment.addAttribute("bundleIdentifier", value: .string(id), source: .urlPattern, confidence: 1.0)
        }
        return fragment
    }
}

struct AcademicPlatformAdapter: PlatformAdapter {
    let identifier = "academic"

    private let hosts = ["arxiv.org", "doi.org", "pubmed.ncbi.nlm.nih.gov", "dl.acm.org", "ieeexplore.ieee.org", "link.springer.com", "sciencedirect.com"]

    func matches(_ url: URL) -> Bool {
        hosts.contains { url.lowercasedHost == $0 || url.lowercasedHost.hasSuffix(".\($0)") }
    }

    func extract(_ context: PlatformAdapterContext) -> MetadataFragment {
        var fragment = MetadataFragment()
        let host = context.url.lowercasedHost
        let platform: String
        if host == "arxiv.org" { platform = "arXiv" }
        else if host == "doi.org" { platform = "DOI" }
        else if host.contains("pubmed") { platform = "PubMed" }
        else if host.contains("acm") { platform = "ACM Digital Library" }
        else if host.contains("ieee") { platform = "IEEE Xplore" }
        else if host.contains("springer") { platform = "Springer" }
        else { platform = "ScienceDirect" }
        fragment.platformCandidates.append(.init(value: platform, confidence: 0.98, source: .urlPattern))
        fragment.contentTypeCandidates.append(.init(value: "scholarlyArticle", confidence: 0.97, source: .urlPattern))
        fragment.contentSubtypeCandidates.append(.init(value: "paper", confidence: 0.94, source: .urlPattern))
        if host == "arxiv.org", let id = context.url.decodedPathComponents.last {
            fragment.addAttribute("arxivID", value: .string(id.replacingOccurrences(of: ".pdf", with: "")), source: .urlPattern, confidence: 1.0)
        }
        if host == "doi.org" {
            let doi = context.url.decodedPathComponents.joined(separator: "/")
            if !doi.isEmpty { fragment.addAttribute("doi", value: .string(doi), source: .urlPattern, confidence: 1.0) }
        }
        return fragment
    }
}

struct DeveloperResourceAdapter: PlatformAdapter {
    let identifier = "developer-resource"

    private let platforms: [(suffix: String, name: String, type: String)] = [
        ("stackoverflow.com", "Stack Overflow", "discussion"),
        ("npmjs.com", "npm", "softwarePackage"),
        ("pypi.org", "PyPI", "softwarePackage"),
        ("crates.io", "crates.io", "softwarePackage"),
        ("huggingface.co", "Hugging Face", "machineLearningResource"),
        ("hub.docker.com", "Docker Hub", "softwarePackage")
    ]

    func matches(_ url: URL) -> Bool {
        platforms.contains { url.lowercasedHost == $0.suffix || url.lowercasedHost.hasSuffix(".\($0.suffix)") }
    }

    func extract(_ context: PlatformAdapterContext) -> MetadataFragment {
        var fragment = MetadataFragment()
        guard let match = platforms.first(where: { context.url.lowercasedHost == $0.suffix || context.url.lowercasedHost.hasSuffix(".\($0.suffix)") }) else { return fragment }
        fragment.platformCandidates.append(.init(value: match.name, confidence: 0.98, source: .urlPattern))
        fragment.contentTypeCandidates.append(.init(value: match.type, confidence: 0.92, source: .urlPattern))
        fragment.contentSubtypeCandidates.append(.init(value: match.type, confidence: 0.88, source: .urlPattern))
        return fragment
    }
}

struct DocumentPlatformAdapter: PlatformAdapter {
    let identifier = "document-platform"

    private let platforms: [(suffix: String, name: String)] = [
        ("notion.site", "Notion"), ("notion.so", "Notion"), ("docs.google.com", "Google Docs"),
        ("figma.com", "Figma"), ("dropbox.com", "Dropbox"), ("1drv.ms", "OneDrive"), ("onedrive.live.com", "OneDrive")
    ]

    func matches(_ url: URL) -> Bool {
        platforms.contains { url.lowercasedHost == $0.suffix || url.lowercasedHost.hasSuffix(".\($0.suffix)") }
    }

    func extract(_ context: PlatformAdapterContext) -> MetadataFragment {
        var fragment = MetadataFragment()
        guard let match = platforms.first(where: { context.url.lowercasedHost == $0.suffix || context.url.lowercasedHost.hasSuffix(".\($0.suffix)") }) else { return fragment }
        fragment.platformCandidates.append(.init(value: match.name, confidence: 0.98, source: .urlPattern))
        fragment.contentTypeCandidates.append(.init(value: "document", confidence: 0.94, source: .urlPattern))
        fragment.contentSubtypeCandidates.append(.init(value: documentSubtype(url: context.url, platform: match.name), confidence: 0.86, source: .urlPattern))
        return fragment
    }

    private func documentSubtype(url: URL, platform: String) -> String {
        if platform == "Google Docs" {
            let parts = url.decodedPathComponents
            if parts.contains("spreadsheets") { return "spreadsheet" }
            if parts.contains("presentation") { return "presentation" }
            return "document"
        }
        if platform == "Figma" { return "design" }
        return "sharedDocument"
    }
}

struct MediaPlatformAdapter: PlatformAdapter {
    let identifier = "media-platform"
    private let platforms: [(suffix: String, name: String, type: String)] = [
        ("vimeo.com", "Vimeo", "video"), ("twitch.tv", "Twitch", "video"),
        ("soundcloud.com", "SoundCloud", "audio"), ("open.spotify.com", "Spotify", "audio"),
        ("music.apple.com", "Apple Music", "audio")
    ]

    func matches(_ url: URL) -> Bool {
        platforms.contains { url.lowercasedHost == $0.suffix || url.lowercasedHost.hasSuffix(".\($0.suffix)") }
    }

    func extract(_ context: PlatformAdapterContext) -> MetadataFragment {
        var fragment = MetadataFragment()
        guard let match = platforms.first(where: { context.url.lowercasedHost == $0.suffix || context.url.lowercasedHost.hasSuffix(".\($0.suffix)") }) else { return fragment }
        fragment.platformCandidates.append(.init(value: match.name, confidence: 0.98, source: .urlPattern))
        fragment.contentTypeCandidates.append(.init(value: match.type, confidence: 0.94, source: .urlPattern))
        return fragment
    }
}

struct ShoppingPlatformAdapter: PlatformAdapter {
    let identifier = "shopping-platform"

    private let platforms: [(suffix: String, name: String)] = [
        ("smartstore.naver.com", "네이버 스마트스토어"), ("coupang.com", "쿠팡"), ("11st.co.kr", "11번가"),
        ("gmarket.co.kr", "G마켓"), ("auction.co.kr", "옥션"), ("musinsa.com", "무신사"),
        ("ohou.se", "오늘의집"), ("amazon.com", "Amazon"), ("aliexpress.com", "AliExpress"), ("etsy.com", "Etsy")
    ]

    func matches(_ url: URL) -> Bool {
        platforms.contains { url.lowercasedHost == $0.suffix || url.lowercasedHost.hasSuffix(".\($0.suffix)") }
    }

    func extract(_ context: PlatformAdapterContext) -> MetadataFragment {
        var fragment = MetadataFragment()
        guard let match = platforms.first(where: { context.url.lowercasedHost == $0.suffix || context.url.lowercasedHost.hasSuffix(".\($0.suffix)") }) else { return fragment }
        fragment.platformCandidates.append(.init(value: match.name, confidence: 0.98, source: .urlPattern))
        fragment.contentTypeCandidates.append(.init(value: "product", confidence: 0.90, source: .urlPattern))
        fragment.contentSubtypeCandidates.append(.init(value: "productPage", confidence: 0.90, source: .urlPattern))
        fragment.siteNameCandidates.append(.init(value: match.name, source: .urlPattern, confidence: 0.88))
        return fragment
    }
}
