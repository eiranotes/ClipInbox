import Foundation

struct SemanticDOMParser: Sendable {
    func parse(_ document: HTMLDocument) -> MetadataFragment {
        var fragment = MetadataFragment()
        let html = document.html
        let sanitized = HTMLTools.sanitizeBody(html)
        let selected = selectMainContainer(from: sanitized) ?? sanitized
        let mainText = HTMLTools.cleanText(selected, maximumLength: document.configuration.maximumDOMTextCharacters)
        fragment.visibleTextLength = mainText.count
        fragment.hasSemanticBody = mainText.count >= 120

        if containsArticleElement(html) {
            fragment.contentTypeCandidates.append(.init(value: "article", confidence: 0.76, source: .semanticDOM))
        }

        if let heading = extractHeading(from: selected) ?? extractHeading(from: sanitized) {
            fragment.titleCandidates.append(.init(value: heading, source: .semanticDOM, confidence: 0.80))
        }

        if let paragraph = HTMLTools.firstMeaningfulParagraph(in: selected) ?? HTMLTools.firstMeaningfulParagraph(in: sanitized) {
            fragment.excerptCandidates.append(.init(value: paragraph, source: .semanticDOM, confidence: 0.78))
            fragment.descriptionCandidates.append(.init(value: paragraph, source: .semanticDOM, confidence: 0.68))
        }

        if HTMLTools.isMeaningful(mainText, minimumLength: 120) {
            fragment.bodyTextCandidates.append(.init(value: mainText, source: .semanticDOM, confidence: 0.74))
        }

        if let author = extractAuthor(from: selected) ?? extractAuthor(from: sanitized) {
            fragment.creatorCandidates.append(.init(value: author, source: .semanticDOM, confidence: 0.68))
        }

        let dates = extractDates(from: selected)
        if let published = dates.published {
            fragment.publishedAtCandidates.append(.init(value: published, source: .semanticDOM, confidence: 0.72))
        }
        if let modified = dates.modified {
            fragment.modifiedAtCandidates.append(.init(value: modified, source: .semanticDOM, confidence: 0.68))
        }

        let tags = extractTags(from: selected, bodyText: mainText)
        if !tags.isEmpty {
            fragment.originalTagCandidates.append(.init(value: tags, source: .semanticDOM, confidence: 0.66))
        }

        for image in extractImages(from: selected, baseURL: document.baseURL).prefix(document.configuration.maximumImages) {
            fragment.imageCandidates.append(.init(value: image, source: .semanticDOM, confidence: 0.62))
        }

        let language = inferLanguage(html: html, text: mainText)
        if let language {
            fragment.languageCandidates.append(.init(value: language, source: .derived, confidence: 0.62))
        }

        if let minutes = HTMLTools.approximateReadingMinutes(text: mainText, language: language) {
            fragment.readingMinutesCandidates.append(.init(value: minutes, source: .derived, confidence: 0.78, rawValue: .number(Double(mainText.count))))
            fragment.addAttribute("bodyCharacterCount", value: .number(Double(mainText.count)), source: .derived, confidence: 0.9)
        }

        detectJavaScriptShell(html: html, mainText: mainText, fragment: &fragment)
        detectStatusText(mainText, fragment: &fragment)
        return fragment
    }

    private func containsArticleElement(_ html: String) -> Bool {
        HTMLTools.firstMatch(#"<article\b"#, in: html) != nil
    }

    private func selectMainContainer(from html: String) -> String? {
        if let article = bestElement(named: "article", in: html) { return article }
        if let main = bestElement(named: "main", in: html) { return main }
        if let roleMain = bestRoleMain(in: html) { return roleMain }
        return densestBlock(in: html)
    }

    private func bestElement(named name: String, in html: String) -> String? {
        let candidates = HTMLTools.pairedTags(named: name, in: html)
        return candidates
            .map { $0.innerHTML }
            .max { scoreBlock($0) < scoreBlock($1) }
            .flatMap { scoreBlock($0) >= 80 ? $0 : nil }
    }

    private func bestRoleMain(in html: String) -> String? {
        let pattern = #"<([a-z0-9]+)\b([^>]*\brole\s*=\s*['\"]main['\"][^>]*)>(.*?)</\1\s*>"#
        let candidates = HTMLTools.matches(pattern, in: html).compactMap { $0.count > 3 ? $0[3] : nil }
        return candidates.max { scoreBlock($0) < scoreBlock($1) }
    }

    private func densestBlock(in html: String) -> String? {
        let pattern = #"<(?:section|div)\b([^>]*)>(.*?)</(?:section|div)\s*>"#
        var best: (score: Int, html: String)?
        for match in HTMLTools.matches(pattern, in: html).prefix(800) where match.count > 2 {
            let attributes = HTMLTools.attributes(from: match[1])
            let hints = ((attributes["class"] ?? "") + " " + (attributes["id"] ?? "")).lowercased()
            if isNoiseHint(hints) { continue }
            let score = scoreBlock(match[2])
            if score > (best?.score ?? 0) { best = (score, match[2]) }
        }
        return (best?.score ?? 0) >= 160 ? best?.html : nil
    }

    private func scoreBlock(_ html: String) -> Int {
        let text = HTMLTools.cleanText(html)
        guard !text.isEmpty else { return 0 }
        let paragraphCount = HTMLTools.matches(#"<p\b"#, in: html).count
        let headingCount = HTMLTools.matches(#"<h[1-6]\b"#, in: html).count
        let linkText = HTMLTools.pairedTags(named: "a", in: html).map { HTMLTools.cleanText($0.innerHTML).count }.reduce(0, +)
        let linkPenalty = min(text.count, linkText) / 2
        return text.count + paragraphCount * 80 + headingCount * 24 - linkPenalty
    }

    private func extractHeading(from html: String) -> String? {
        for level in 1...3 {
            for heading in HTMLTools.pairedTags(named: "h\(level)", in: html) {
                let value = HTMLTools.cleanText(heading.innerHTML)
                if value.count >= 3, value.count <= 300, !isBoilerplate(value) { return value }
            }
        }
        return nil
    }

    private func extractAuthor(from html: String) -> String? {
        let patterns = [
            #"<([a-z0-9]+)\b([^>]*(?:class|id)\s*=\s*['\"][^'\"]*(?:author|byline|writer|contributor|profile-name|user-name|username)[^'\"]*['\"][^>]*)>(.*?)</\1\s*>"#,
            #"(?:By|Written by|작성자|글쓴이|기자)\s*[:：]?\s*</?[^>]*>?\s*([\p{L}\p{N} ._\-]{2,80})"#
        ]
        for (index, pattern) in patterns.enumerated() {
            for match in HTMLTools.matches(pattern, in: html).prefix(20) {
                let raw = index == 0 && match.count > 3 ? match[3] : (match.count > 1 ? match[1] : "")
                var value = HTMLTools.cleanText(raw)
                value = value.replacingOccurrences(of: #"^(?:By|Written by|작성자|글쓴이|기자)\s*[:：]?\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
                if value.count >= 2, value.count <= 100, !isBoilerplate(value) { return value }
            }
        }
        return nil
    }

    private func extractDates(from html: String) -> (published: String?, modified: String?) {
        var published: String?
        var modified: String?
        for time in HTMLTools.pairedTags(named: "time", in: html).prefix(20) {
            let raw = time.attributes["datetime"] ?? time.attributes["content"] ?? HTMLTools.cleanText(time.innerHTML)
            guard let normalized = HTMLTools.normalizedDate(raw) else { continue }
            let hints = ((time.attributes["class"] ?? "") + " " + (time.attributes["itemprop"] ?? "")).lowercased()
            if hints.contains("modif") || hints.contains("update") {
                modified = modified ?? normalized
            } else {
                published = published ?? normalized
            }
        }
        if published == nil {
            let pattern = #"<([a-z0-9]+)\b([^>]*(?:class|id)\s*=\s*['\"][^'\"]*(?:publish|date|time|created)[^'\"]*['\"][^>]*)>(.*?)</\1\s*>"#
            for match in HTMLTools.matches(pattern, in: html).prefix(20) where match.count > 3 {
                let attributes = HTMLTools.attributes(from: match[2])
                let raw = attributes["datetime"] ?? attributes["content"] ?? HTMLTools.cleanText(match[3])
                if let date = HTMLTools.normalizedDate(raw) { published = date; break }
            }
        }
        return (published, modified)
    }

    private func extractTags(from html: String, bodyText: String) -> [String] {
        var values: [String] = []
        for anchor in HTMLTools.pairedTags(named: "a", in: html).prefix(500) {
            let rel = anchor.attributes["rel"]?.lowercased() ?? ""
            let hints = ((anchor.attributes["class"] ?? "") + " " + (anchor.attributes["href"] ?? "")).lowercased()
            if rel.split(whereSeparator: { $0.isWhitespace }).contains("tag") || hints.contains("tag") || hints.contains("hashtag") {
                let value = HTMLTools.cleanText(anchor.innerHTML).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                if value.count >= 2, value.count <= 60 { values.append(value) }
            }
        }
        values += HTMLTools.hashtags(in: String(bodyText.prefix(4_000)))
        var seen = Set<String>()
        return values.filter {
            let key = $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return seen.insert(key).inserted
        }.prefix(20).map { $0 }
    }

    private func extractImages(from html: String, baseURL: URL) -> [String] {
        var scored: [(String, Int)] = []
        for attributes in HTMLTools.tags(named: "img", in: html).prefix(300) {
            let hints = ((attributes["class"] ?? "") + " " + (attributes["id"] ?? "") + " " + (attributes["alt"] ?? "")).lowercased()
            if hints.contains("logo") || hints.contains("avatar") || hints.contains("icon") || hints.contains("emoji") || hints.contains("sprite") { continue }
            let raw = attributes["src"] ?? attributes["data-src"] ?? attributes["data-original"] ?? firstSrcsetURL(attributes["srcset"])
            guard let url = HTMLTools.resolveURL(raw, relativeTo: baseURL) else { continue }
            let width = Int(attributes["width"] ?? "") ?? 0
            let height = Int(attributes["height"] ?? "") ?? 0
            if width > 0, height > 0, width < 120, height < 120 { continue }
            var score = min(width, 1_600) + min(height, 1_200)
            if hints.contains("hero") || hints.contains("cover") || hints.contains("featured") || hints.contains("article") { score += 1_000 }
            if url.lowercased().contains("tracking") || url.lowercased().contains("pixel") { continue }
            scored.append((url, score))
        }
        var seen = Set<String>()
        return scored.sorted { $0.1 > $1.1 }.compactMap { seen.insert($0.0).inserted ? $0.0 : nil }
    }

    private func firstSrcsetURL(_ value: String?) -> String? {
        value?.split(separator: ",").last?.split(whereSeparator: { $0.isWhitespace }).first.map(String.init)
    }

    private func inferLanguage(html: String, text: String) -> String? {
        if let match = HTMLTools.firstMatch(#"<html\b([^>]*)>"#, in: html), match.count > 1 {
            let attributes = HTMLTools.attributes(from: match[1])
            if let value = HTMLTools.normalizedLanguage(attributes["lang"] ?? attributes["xml:lang"]) { return value }
        }
        guard !text.isEmpty else { return nil }
        var hangul = 0, japanese = 0, han = 0, latin = 0
        for scalar in text.unicodeScalars.prefix(4_000) {
            switch scalar.value {
            case 0xAC00...0xD7AF: hangul += 1
            case 0x3040...0x30FF: japanese += 1
            case 0x3400...0x9FFF: han += 1
            case 0x0041...0x007A: latin += 1
            default: break
            }
        }
        if hangul > max(20, japanese + latin / 3) { return "ko" }
        if japanese > 20 { return "ja" }
        if han > max(30, latin) { return "zh" }
        if latin > 40 { return "en" }
        return nil
    }

    private func detectJavaScriptShell(html: String, mainText: String, fragment: inout MetadataFragment) {
        let lowerHTML = html.lowercased()
        let markers = [
            "enable javascript", "javascript is required", "please turn javascript on",
            "자바스크립트를 활성화", "javascript를 활성화", "id=\"__next\"", "id=\"app\"", "id=\"root\""
        ]
        if mainText.count < 180, markers.contains(where: lowerHTML.contains) {
            fragment.requiresJavaScript = true
        }
    }

    private func detectStatusText(_ text: String, fragment: inout MetadataFragment) {
        let lower = String(text.prefix(3_000)).lowercased()
        let login = ["로그인이 필요", "로그인하여 계속", "sign in to continue", "log in to continue", "login required"]
        let blocked = ["access denied", "request blocked", "unusual traffic", "captcha", "봇이 아님을", "접근이 차단"]
        let removed = ["page not found", "content is unavailable", "게시물이 삭제", "페이지를 찾을 수 없", "존재하지 않는 페이지"]
        if login.contains(where: lower.contains) {
            fragment.statusHints.append(.init(status: .loginRequired, confidence: 0.78, reason: "login text"))
        }
        if blocked.contains(where: lower.contains) {
            fragment.statusHints.append(.init(status: .blocked, confidence: 0.82, reason: "blocking text"))
        }
        if removed.contains(where: lower.contains) {
            fragment.statusHints.append(.init(status: .removed, confidence: 0.80, reason: "removed text"))
        }
    }

    private func isNoiseHint(_ value: String) -> Bool {
        ["nav", "menu", "footer", "header", "sidebar", "comment", "recommend", "related", "cookie", "login", "share", "advert", "promo"]
            .contains(where: value.contains)
    }

    private func isBoilerplate(_ value: String) -> Bool {
        let lower = value.lowercased()
        return ["menu", "home", "로그인", "회원가입", "cookie", "privacy", "subscribe"].contains(where: lower.contains)
    }
}
