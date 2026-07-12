import Foundation

struct HeadMetadataParser: Sendable {
    func parse(_ document: HTMLDocument) -> MetadataFragment {
        var fragment = MetadataFragment()
        let html = document.html
        let baseURL = document.baseURL

        if let titleMatch = HTMLTools.firstMatch(#"<title\b[^>]*>(.*?)</title\s*>"#, in: html), titleMatch.count > 1 {
            appendString(
                HTMLTools.cleanText(titleMatch[1]),
                to: &fragment.titleCandidates,
                source: .semanticDOM,
                confidence: 0.55
            )
        }

        var lastOpenGraphImageIndex: Int?
        for attributes in HTMLTools.tags(named: "meta", in: html) {
            let key = (attributes["property"] ?? attributes["name"] ?? attributes["itemprop"] ?? attributes["http-equiv"] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let content = HTMLTools.cleanText(attributes["content"] ?? attributes["value"] ?? "")
            guard !key.isEmpty, !content.isEmpty else { continue }

            let source: MetadataSource
            if key.hasPrefix("og:") || key.hasPrefix("article:") || key.hasPrefix("profile:") {
                source = .openGraph
            } else if key.hasPrefix("twitter:") {
                source = .twitterCard
            } else if attributes["itemprop"] != nil {
                source = .microdata
            } else if attributes["property"] != nil {
                source = .rdfa
            } else {
                source = .semanticDOM
            }

            switch key {
            case "description", "dc.description", "dcterms.description", "citation_abstract":
                appendString(content, to: &fragment.descriptionCandidates, source: source, confidence: key == "description" ? 0.72 : 0.82)
            case "author", "dc.creator", "dcterms.creator", "citation_author":
                appendString(content, to: &fragment.creatorCandidates, source: source, confidence: 0.76)
            case "keywords", "news_keywords", "citation_keywords", "dc.subject":
                appendTags(content, to: &fragment.originalTagCandidates, source: source, confidence: 0.70)
            case "language", "content-language", "dc.language", "citation_language":
                if let language = HTMLTools.normalizedLanguage(content) {
                    fragment.languageCandidates.append(.init(value: language, source: source, confidence: 0.72, rawValue: .string(content)))
                }
            case "og:title":
                fragment.hasOpenGraph = true
                appendString(content, to: &fragment.titleCandidates, source: .openGraph, confidence: 0.91)
            case "og:description":
                fragment.hasOpenGraph = true
                appendString(content, to: &fragment.descriptionCandidates, source: .openGraph, confidence: 0.89)
            case "og:image", "og:image:url", "og:image:secure_url":
                fragment.hasOpenGraph = true
                if let url = HTMLTools.resolveURL(content, relativeTo: baseURL) {
                    fragment.imageCandidates.append(.init(value: url, source: .openGraph, confidence: 0.92, rawValue: .string(content)))
                    lastOpenGraphImageIndex = fragment.imageCandidates.count - 1
                }
            case "og:image:width":
                fragment.addAttribute("ogImageWidth", value: .string(content), source: .openGraph, confidence: 0.8)
            case "og:image:height":
                fragment.addAttribute("ogImageHeight", value: .string(content), source: .openGraph, confidence: 0.8)
            case "og:site_name":
                fragment.hasOpenGraph = true
                appendString(content, to: &fragment.siteNameCandidates, source: .openGraph, confidence: 0.92)
            case "og:type":
                fragment.hasOpenGraph = true
                addOpenGraphType(content, to: &fragment)
            case "og:url":
                fragment.hasOpenGraph = true
                if let url = HTMLTools.resolveURL(content, relativeTo: baseURL) {
                    fragment.canonicalURLCandidates.append(.init(value: url, source: .openGraph, confidence: 0.86, rawValue: .string(content)))
                }
            case "og:video", "og:video:url", "og:video:secure_url":
                fragment.hasOpenGraph = true
                fragment.contentTypeCandidates.append(.init(value: "video", confidence: 0.86, source: .openGraph))
                if let url = HTMLTools.resolveURL(content, relativeTo: baseURL) {
                    fragment.addAttribute("videoURL", value: .string(url), source: .openGraph, confidence: 0.8)
                }
            case "og:audio", "og:audio:url", "og:audio:secure_url":
                fragment.hasOpenGraph = true
                fragment.contentTypeCandidates.append(.init(value: "audio", confidence: 0.86, source: .openGraph))
                if let url = HTMLTools.resolveURL(content, relativeTo: baseURL) {
                    fragment.addAttribute("audioURL", value: .string(url), source: .openGraph, confidence: 0.8)
                }
            case "twitter:title":
                appendString(content, to: &fragment.titleCandidates, source: .twitterCard, confidence: 0.82)
            case "twitter:description":
                appendString(content, to: &fragment.descriptionCandidates, source: .twitterCard, confidence: 0.80)
            case "twitter:image", "twitter:image:src":
                if let url = HTMLTools.resolveURL(content, relativeTo: baseURL) {
                    fragment.imageCandidates.append(.init(value: url, source: .twitterCard, confidence: 0.82, rawValue: .string(content)))
                }
            case "twitter:card":
                fragment.addAttribute("twitterCard", value: .string(content), source: .twitterCard, confidence: 0.85)
                if content.lowercased().contains("player") {
                    fragment.contentTypeCandidates.append(.init(value: "video", confidence: 0.72, source: .twitterCard))
                }
            case "twitter:creator", "twitter:site":
                appendString(content.trimmingCharacters(in: CharacterSet(charactersIn: "@")), to: &fragment.creatorCandidates, source: .twitterCard, confidence: key == "twitter:creator" ? 0.78 : 0.58)
            case "article:author":
                appendString(content, to: &fragment.creatorCandidates, source: .openGraph, confidence: 0.84)
            case "article:published_time", "citation_publication_date", "citation_date", "dc.date", "dcterms.issued":
                appendDate(content, to: &fragment.publishedAtCandidates, source: source, confidence: 0.88)
            case "article:modified_time", "dcterms.modified":
                appendDate(content, to: &fragment.modifiedAtCandidates, source: source, confidence: 0.86)
            case "article:section", "section":
                fragment.addAttribute("section", value: .string(content), source: source, confidence: 0.82)
            case "article:tag":
                fragment.originalTagCandidates.append(.init(value: [content], source: .openGraph, confidence: 0.84, rawValue: .string(content)))
            case "citation_title", "dc.title", "dcterms.title":
                appendString(content, to: &fragment.titleCandidates, source: source, confidence: 0.88)
            case "citation_journal_title", "citation_conference_title":
                fragment.addAttribute("publication", value: .string(content), source: source, confidence: 0.9)
                fragment.siteNameCandidates.append(.init(value: content, source: source, confidence: 0.76))
            case "citation_doi", "dc.identifier", "dcterms.identifier":
                if content.lowercased().contains("10.") {
                    fragment.addAttribute("doi", value: .string(content), source: source, confidence: 0.94)
                    fragment.contentTypeCandidates.append(.init(value: "scholarlyArticle", confidence: 0.9, source: source))
                }
            case "citation_pdf_url":
                if let url = HTMLTools.resolveURL(content, relativeTo: baseURL) {
                    fragment.addAttribute("pdfURL", value: .string(url), source: source, confidence: 0.92)
                }
            case "citation_firstpage", "citation_lastpage", "citation_volume", "citation_issue":
                fragment.addAttribute(key.replacingOccurrences(of: "citation_", with: ""), value: .string(content), source: source, confidence: 0.82)
            case "product:price:amount", "og:price:amount":
                fragment.addAttribute("price", value: .string(content), source: source, confidence: 0.86)
                fragment.contentTypeCandidates.append(.init(value: "product", confidence: 0.86, source: source))
            case "product:price:currency", "og:price:currency":
                fragment.addAttribute("currency", value: .string(content), source: source, confidence: 0.86)
            case "music:duration", "video:duration":
                if let duration = HTMLTools.parseISODuration(content) {
                    fragment.durationCandidates.append(.init(value: duration, source: source, confidence: 0.80, rawValue: .string(content)))
                }
            case "headline", "name":
                if source == .microdata || source == .rdfa {
                    appendString(content, to: &fragment.titleCandidates, source: source, confidence: 0.78)
                }
            case "thumbnailurl", "image":
                if (source == .microdata || source == .rdfa), let url = HTMLTools.resolveURL(content, relativeTo: baseURL) {
                    fragment.imageCandidates.append(.init(value: url, source: source, confidence: 0.78, rawValue: .string(content)))
                }
            case "datepublished":
                appendDate(content, to: &fragment.publishedAtCandidates, source: source, confidence: 0.80)
            case "datemodified":
                appendDate(content, to: &fragment.modifiedAtCandidates, source: source, confidence: 0.80)
            case "duration":
                if let duration = HTMLTools.parseISODuration(content) {
                    fragment.durationCandidates.append(.init(value: duration, source: source, confidence: 0.78, rawValue: .string(content)))
                }
            default:
                break
            }
        }

        _ = lastOpenGraphImageIndex
        parseLinks(in: html, baseURL: baseURL, fragment: &fragment)
        parseHTMLLanguage(in: html, fragment: &fragment)
        parseInlineMicrodata(in: html, baseURL: baseURL, fragment: &fragment)
        return fragment
    }

    private func parseLinks(in html: String, baseURL: URL, fragment: inout MetadataFragment) {
        for attributes in HTMLTools.tags(named: "link", in: html) {
            let relValues = (attributes["rel"] ?? "").lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
            let href = HTMLTools.resolveURL(attributes["href"], relativeTo: baseURL)
            guard let href else { continue }
            if relValues.contains("canonical") {
                fragment.canonicalURLCandidates.append(.init(value: href, source: .semanticDOM, confidence: 0.97, rawValue: attributes["href"].map(JSONValue.string)))
            }
            if relValues.contains("alternate") {
                fragment.addAttribute("alternateURL", value: .string(href), source: .semanticDOM, confidence: 0.72)
                if let type = attributes["type"], type.lowercased().contains("html") {
                    fragment.explicitContentDocumentURLs.append(href)
                }
            }
            if relValues.contains("icon") || relValues.contains("shortcut") {
                fragment.addAttribute("faviconURL", value: .string(href), source: .semanticDOM, confidence: 0.72)
            }
            if relValues.contains("apple-touch-icon") {
                fragment.addAttribute("appleTouchIconURL", value: .string(href), source: .semanticDOM, confidence: 0.76)
            }
        }
    }

    private func parseHTMLLanguage(in html: String, fragment: inout MetadataFragment) {
        guard let match = HTMLTools.firstMatch(#"<html\b([^>]*)>"#, in: html), match.count > 1 else { return }
        let attributes = HTMLTools.attributes(from: match[1])
        if let language = HTMLTools.normalizedLanguage(attributes["lang"] ?? attributes["xml:lang"]) {
            fragment.languageCandidates.append(.init(value: language, source: .semanticDOM, confidence: 0.82))
        }
    }

    private func parseInlineMicrodata(in html: String, baseURL: URL, fragment: inout MetadataFragment) {
        let pattern = #"<([a-z0-9]+)\b([^>]*(?:itemprop|property)\s*=\s*['\"][^'\"]+['\"][^>]*)>(.*?)</\1\s*>"#
        for match in HTMLTools.matches(pattern, in: html).prefix(200) where match.count > 3 {
            let attributes = HTMLTools.attributes(from: match[2])
            let key = (attributes["itemprop"] ?? attributes["property"] ?? "").lowercased()
            let source: MetadataSource = attributes["itemprop"] != nil ? .microdata : .rdfa
            let value = HTMLTools.cleanText(match[3])
            guard !value.isEmpty else { continue }
            switch key {
            case "headline", "name": appendString(value, to: &fragment.titleCandidates, source: source, confidence: 0.72)
            case "description", "abstract": appendString(value, to: &fragment.descriptionCandidates, source: source, confidence: 0.72)
            case "author", "creator": appendString(value, to: &fragment.creatorCandidates, source: source, confidence: 0.70)
            case "datepublished": appendDate(value, to: &fragment.publishedAtCandidates, source: source, confidence: 0.74)
            case "datemodified": appendDate(value, to: &fragment.modifiedAtCandidates, source: source, confidence: 0.74)
            case "keywords": appendTags(value, to: &fragment.originalTagCandidates, source: source, confidence: 0.70)
            case "image", "thumbnailurl":
                if let src = attributes["src"] ?? attributes["href"], let url = HTMLTools.resolveURL(src, relativeTo: baseURL) {
                    fragment.imageCandidates.append(.init(value: url, source: source, confidence: 0.72))
                }
            default: break
            }
        }
    }

    private func addOpenGraphType(_ rawValue: String, to fragment: inout MetadataFragment) {
        let type = rawValue.lowercased()
        let mapped: String
        if type.contains("article") { mapped = "article" }
        else if type.contains("video") { mapped = "video" }
        else if type.contains("music") || type.contains("audio") { mapped = "audio" }
        else if type.contains("product") { mapped = "product" }
        else if type.contains("profile") { mapped = "profile" }
        else if type.contains("book") { mapped = "book" }
        else if type.contains("place") { mapped = "place" }
        else { mapped = "webPage" }
        fragment.contentTypeCandidates.append(.init(value: mapped, confidence: 0.82, source: .openGraph))
        fragment.addAttribute("openGraphType", value: .string(rawValue), source: .openGraph, confidence: 0.9)
    }

    private func appendString(_ value: String, to values: inout [ExtractedField<String>], source: MetadataSource, confidence: Double) {
        let clean = HTMLTools.cleanText(value)
        guard !clean.isEmpty else { return }
        values.append(.init(value: clean, source: source, confidence: confidence, rawValue: .string(value)))
    }

    private func appendDate(_ value: String, to values: inout [ExtractedField<String>], source: MetadataSource, confidence: Double) {
        guard let normalized = HTMLTools.normalizedDate(value) else { return }
        values.append(.init(value: normalized, source: source, confidence: confidence, rawValue: .string(value)))
    }

    private func appendTags(_ value: String, to values: inout [ExtractedField<[String]>], source: MetadataSource, confidence: Double) {
        let tags = HTMLTools.commaSeparated(value)
        guard !tags.isEmpty else { return }
        values.append(.init(value: tags, source: source, confidence: confidence, rawValue: .string(value)))
    }
}
