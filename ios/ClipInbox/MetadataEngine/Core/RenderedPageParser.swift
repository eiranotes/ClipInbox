import Foundation

protocol MetadataRendering: Sendable {
    @MainActor
    func render(url: URL, configuration: MetadataConfiguration) async throws -> RenderedPage
}

struct RenderedPageParser: Sendable {
    func parse(_ page: RenderedPage, configuration: MetadataConfiguration) -> MetadataFragment {
        guard let baseURL = URL(string: page.finalURL) else { return MetadataFragment() }
        var fragment = MetadataFragment()

        append(page.title, to: &fragment.titleCandidates, source: .semanticDOM, confidence: 0.76)
        append(page.heading, to: &fragment.titleCandidates, source: .semanticDOM, confidence: 0.84)
        append(page.creator, to: &fragment.creatorCandidates, source: .semanticDOM, confidence: 0.72)
        if let date = HTMLTools.normalizedDate(page.date) {
            fragment.publishedAtCandidates.append(.init(value: date, source: .semanticDOM, confidence: 0.70, rawValue: page.date.map(JSONValue.string)))
        }
        if let canonical = HTMLTools.resolveURL(page.canonicalURL, relativeTo: baseURL) {
            fragment.canonicalURLCandidates.append(.init(value: canonical, source: .semanticDOM, confidence: 0.97))
        }
        if let language = HTMLTools.normalizedLanguage(page.language) {
            fragment.languageCandidates.append(.init(value: language, source: .semanticDOM, confidence: 0.84))
        }

        for (rawKey, rawValues) in page.meta {
            let key = rawKey.lowercased()
            for value in rawValues where !value.isEmpty {
                switch key {
                case "description": append(value, to: &fragment.descriptionCandidates, source: .semanticDOM, confidence: 0.74)
                case "author": append(value, to: &fragment.creatorCandidates, source: .semanticDOM, confidence: 0.76)
                case "keywords":
                    let tags = HTMLTools.commaSeparated(value)
                    if !tags.isEmpty { fragment.originalTagCandidates.append(.init(value: tags, source: .semanticDOM, confidence: 0.68)) }
                case "og:title":
                    fragment.hasOpenGraph = true
                    append(value, to: &fragment.titleCandidates, source: .openGraph, confidence: 0.92)
                case "og:description":
                    fragment.hasOpenGraph = true
                    append(value, to: &fragment.descriptionCandidates, source: .openGraph, confidence: 0.90)
                case "og:image", "og:image:url", "og:image:secure_url":
                    fragment.hasOpenGraph = true
                    if let image = HTMLTools.resolveURL(value, relativeTo: baseURL) { fragment.imageCandidates.append(.init(value: image, source: .openGraph, confidence: 0.92)) }
                case "og:site_name": append(value, to: &fragment.siteNameCandidates, source: .openGraph, confidence: 0.92)
                case "og:type": addType(value, fragment: &fragment)
                case "og:url":
                    if let url = HTMLTools.resolveURL(value, relativeTo: baseURL) { fragment.canonicalURLCandidates.append(.init(value: url, source: .openGraph, confidence: 0.86)) }
                case "twitter:title": append(value, to: &fragment.titleCandidates, source: .twitterCard, confidence: 0.82)
                case "twitter:description": append(value, to: &fragment.descriptionCandidates, source: .twitterCard, confidence: 0.80)
                case "twitter:image", "twitter:image:src":
                    if let image = HTMLTools.resolveURL(value, relativeTo: baseURL) { fragment.imageCandidates.append(.init(value: image, source: .twitterCard, confidence: 0.82)) }
                case "twitter:creator": append(value.trimmingCharacters(in: CharacterSet(charactersIn: "@")), to: &fragment.creatorCandidates, source: .twitterCard, confidence: 0.78)
                case "article:author": append(value, to: &fragment.creatorCandidates, source: .openGraph, confidence: 0.84)
                case "article:published_time": appendDate(value, to: &fragment.publishedAtCandidates, source: .openGraph, confidence: 0.88)
                case "article:modified_time": appendDate(value, to: &fragment.modifiedAtCandidates, source: .openGraph, confidence: 0.86)
                case "article:tag": fragment.originalTagCandidates.append(.init(value: [value], source: .openGraph, confidence: 0.84))
                default: break
                }
            }
        }

        if let mainText = page.mainText {
            let text = HTMLTools.cleanText(mainText, maximumLength: configuration.maximumDOMTextCharacters)
            fragment.visibleTextLength = text.count
            fragment.hasSemanticBody = text.count >= 120
            if HTMLTools.isMeaningful(text, minimumLength: 40) {
                fragment.bodyTextCandidates.append(.init(value: text, source: .semanticDOM, confidence: 0.78))
                let first = firstSentenceOrParagraph(text)
                fragment.excerptCandidates.append(.init(value: first, source: .semanticDOM, confidence: 0.80))
                fragment.descriptionCandidates.append(.init(value: first, source: .semanticDOM, confidence: 0.70))
                if let reading = HTMLTools.approximateReadingMinutes(text: text, language: page.language) {
                    fragment.readingMinutesCandidates.append(.init(value: reading, source: .derived, confidence: 0.72))
                }
            }
        }
        for image in page.imageURLs.compactMap({ HTMLTools.resolveURL($0, relativeTo: baseURL) }).prefix(configuration.maximumImages) {
            fragment.imageCandidates.append(.init(value: image, source: .semanticDOM, confidence: 0.70))
        }

        let structured = StructuredDataParser().parseScripts(
            page.jsonLDScripts,
            baseURL: baseURL,
            canonicalCandidates: [page.canonicalURL].compactMap { $0 },
            maximumBytes: configuration.maximumEmbeddedStateBytes
        )
        fragment.merge(structured)
        return fragment
    }

    private func append(_ raw: String?, to values: inout [ExtractedField<String>], source: MetadataSource, confidence: Double) {
        guard let raw else { return }
        let value = HTMLTools.cleanText(raw)
        guard !value.isEmpty else { return }
        values.append(.init(value: value, source: source, confidence: confidence, rawValue: .string(raw)))
    }

    private func appendDate(_ raw: String, to values: inout [ExtractedField<String>], source: MetadataSource, confidence: Double) {
        guard let value = HTMLTools.normalizedDate(raw) else { return }
        values.append(.init(value: value, source: source, confidence: confidence, rawValue: .string(raw)))
    }

    private func addType(_ raw: String, fragment: inout MetadataFragment) {
        let lower = raw.lowercased()
        let type: String
        if lower.contains("article") { type = "article" }
        else if lower.contains("video") { type = "video" }
        else if lower.contains("audio") || lower.contains("music") { type = "audio" }
        else if lower.contains("product") { type = "product" }
        else if lower.contains("profile") { type = "profile" }
        else { type = "webPage" }
        fragment.contentTypeCandidates.append(.init(value: type, confidence: 0.84, source: .openGraph))
    }

    private func firstSentenceOrParagraph(_ text: String) -> String {
        let maximum = 600
        let prefix = String(text.prefix(maximum))
        if let boundary = prefix.firstIndex(where: { ".!?。！？\n".contains($0) }) {
            return HTMLTools.cleanText(String(prefix[...boundary]))
        }
        return HTMLTools.cleanText(prefix)
    }
}
