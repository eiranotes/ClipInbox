import Foundation

struct FieldResolver: Sendable {
    func resolve(
        normalization: URLNormalizationResult,
        inspection: HTTPInspection?,
        fragment: MetadataFragment,
        attempts: [ExtractionAttempt],
        configuration: MetadataConfiguration
    ) -> LinkMetadataResult {
        let resolvedURL = inspection?.finalURL ?? normalization.normalizedURL.absoluteString
        let baseURL = URL(string: resolvedURL) ?? normalization.normalizedURL
        let canonical = bestCanonical(fragment.canonicalURLCandidates, baseURL: baseURL)

        let platform = bestNamed(fragment.platformCandidates)?.value ?? HTMLTools.domainDisplayName(baseURL)
        let contentType = bestNamed(fragment.contentTypeCandidates)?.value ?? (inspection?.isHTML == false ? "file" : "webPage")
        let subtype = bestNamed(fragment.contentSubtypeCandidates)?.value

        var title = bestString(fragment.titleCandidates, kind: .title)
        if title == nil, let slug = HTMLTools.slugTitle(from: baseURL) {
            title = .init(value: slug, source: .urlPattern, confidence: 0.42)
        }
        if title == nil {
            title = .init(value: HTMLTools.domainDisplayName(baseURL), source: .derived, confidence: 0.30)
        }

        let description = bestString(fragment.descriptionCandidates, kind: .description)
        let siteName = bestString(fragment.siteNameCandidates, kind: .siteName)
        let creator = bestString(fragment.creatorCandidates, kind: .creator)
        let published = bestString(fragment.publishedAtCandidates, kind: .date)
        let modified = bestString(fragment.modifiedAtCandidates, kind: .date)
        let duration = bestInt(fragment.durationCandidates)
        let reading = bestInt(fragment.readingMinutesCandidates)

        let images = deduplicatedImages(fragment.imageCandidates, maximum: configuration.maximumImages)
        let originalTags = normalizedTagFields(fragment.originalTagCandidates, maximum: configuration.maximumOriginalTags)
        let derivedTopics = normalizedTagFields(fragment.derivedTopicCandidates, maximum: configuration.maximumOriginalTags)
        let attributes = resolveAttributes(fragment.attributes)
        let volatile = resolveAttributes(fragment.volatileAttributes)

        let status = resolveStatus(inspection: inspection, fragment: fragment, title: title, description: description, attributes: attributes)
        return LinkMetadataResult(
            originalURL: normalization.originalURL,
            resolvedURL: resolvedURL,
            canonicalURL: canonical,
            normalizedURL: normalization.normalizedURL.absoluteString,
            originalFragment: normalization.originalFragment,
            platform: platform,
            contentType: contentType,
            contentSubtype: subtype,
            title: title,
            description: description,
            siteName: siteName,
            creator: creator,
            publishedAt: published,
            modifiedAt: modified,
            thumbnail: images.first,
            images: images,
            originalTags: originalTags,
            derivedTopics: derivedTopics,
            durationSeconds: duration,
            readingMinutes: reading,
            attributes: attributes,
            volatileAttributes: volatile,
            status: status,
            http: inspection,
            extractionAttempts: attempts,
            analyzedAt: ISO8601DateFormatter.clipInbox.string(from: Date()),
            engineVersion: 1
        )
    }

    private enum StringKind { case title, description, creator, date, siteName }

    private func bestString(_ candidates: [ExtractedField<String>], kind: StringKind) -> ExtractedField<String>? {
        let cleaned = candidates.compactMap { field -> ExtractedField<String>? in
            let value = HTMLTools.cleanText(field.value)
            guard !value.isEmpty else { return nil }
            if kind == .title, isWeakTitle(value) { return nil }
            if kind == .description, !HTMLTools.isMeaningful(value, minimumLength: 16) { return nil }
            var copy = field
            copy.value = value
            return copy
        }
        return cleaned.max { lhs, rhs in
            score(lhs, kind: kind) < score(rhs, kind: kind)
        }
    }

    private func score(_ field: ExtractedField<String>, kind: StringKind) -> Double {
        let rank: Double
        switch kind {
        case .title:
            rank = [.jsonLD: 100, .openGraph: 90, .semanticDOM: 80, .twitterCard: 70, .embeddedState: 68, .microdata: 66, .rdfa: 64, .httpHeader: 45, .urlPattern: 20, .derived: 10][field.source] ?? 0
        case .description:
            rank = [.jsonLD: 100, .openGraph: 90, .semanticDOM: 80, .httpHeader: 76, .twitterCard: 70, .embeddedState: 68, .microdata: 66, .rdfa: 64, .urlPattern: 20, .derived: 10][field.source] ?? 0
        case .creator:
            rank = [.jsonLD: 100, .openGraph: 90, .semanticDOM: 80, .httpHeader: 76, .twitterCard: 70, .embeddedState: 68, .urlPattern: 25, .derived: 10, .microdata: 72, .rdfa: 70][field.source] ?? 0
        case .date:
            rank = [.jsonLD: 100, .openGraph: 90, .semanticDOM: 80, .httpHeader: 74, .embeddedState: 68, .microdata: 72, .rdfa: 70, .twitterCard: 50, .urlPattern: 20, .derived: 10][field.source] ?? 0
        case .siteName:
            rank = [.jsonLD: 90, .openGraph: 100, .semanticDOM: 70, .httpHeader: 65, .embeddedState: 60, .twitterCard: 55, .microdata: 65, .rdfa: 65, .urlPattern: 25, .derived: 10][field.source] ?? 0
        }
        return rank + field.confidence * 9 + min(Double(field.value.count), 300) / 1_000
    }

    private func bestInt(_ values: [ExtractedField<Int>]) -> ExtractedField<Int>? {
        values.filter { $0.value >= 0 }.max { lhs, rhs in
            sourceRank(lhs.source) + lhs.confidence * 10 < sourceRank(rhs.source) + rhs.confidence * 10
        }
    }

    private func bestNamed(_ values: [NamedCandidate]) -> NamedCandidate? {
        // Platform URL patterns are deterministic identifiers, so they outrank a generic
        // semantic guess such as treating a repository README as an Article.
        let namedRank: [MetadataSource: Double] = [
            .urlPattern: 100, .jsonLD: 95, .openGraph: 90, .microdata: 84, .rdfa: 82,
            .semanticDOM: 78, .httpHeader: 74, .twitterCard: 72, .embeddedState: 70, .derived: 30
        ]
        return values.filter { !$0.value.isEmpty }.max { lhs, rhs in
            lhs.confidence + (namedRank[lhs.source] ?? 0) / 100
                < rhs.confidence + (namedRank[rhs.source] ?? 0) / 100
        }
    }

    private func bestCanonical(_ values: [ExtractedField<String>], baseURL: URL) -> String? {
        values.compactMap { field -> (String, Double)? in
            guard let url = URL(string: field.value), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
            let sameSite = registrableHost(url.host) == registrableHost(baseURL.host)
            let score = field.confidence + (sameSite ? 0.25 : 0)
            return (url.absoluteString, score)
        }.max(by: { $0.1 < $1.1 })?.0
    }

    private func deduplicatedImages(_ values: [ExtractedField<String>], maximum: Int) -> [ExtractedField<String>] {
        let sorted = values.filter { field in
            guard let scheme = URL(string: field.value)?.scheme?.lowercased() else { return false }
            return scheme == "http" || scheme == "https"
        }
            .sorted { imageScore($0) > imageScore($1) }
        var seen = Set<String>()
        var output: [ExtractedField<String>] = []
        for value in sorted {
            let key = value.value.lowercased()
            guard seen.insert(key).inserted else { continue }
            output.append(value)
            if output.count == maximum { break }
        }
        return output
    }

    private func normalizedTagFields(_ fields: [ExtractedField<[String]>], maximum: Int) -> [ExtractedField<[String]>] {
        var seen = Set<String>()
        var output: [ExtractedField<[String]>] = []
        var count = 0
        for field in fields.sorted(by: { tagScore($0) > tagScore($1) }) {
            let values = field.value.compactMap { raw -> String? in
                let value = HTMLTools.cleanText(raw.trimmingCharacters(in: CharacterSet(charactersIn: "#")))
                guard value.count >= 2, value.count <= 80 else { return nil }
                let key = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                return seen.insert(key).inserted ? value : nil
            }
            guard !values.isEmpty else { continue }
            var copy = field
            copy.value = Array(values.prefix(maximum - count))
            output.append(copy)
            count += copy.value.count
            if count >= maximum { break }
        }
        return output
    }

    private func resolveAttributes(_ values: [String: [ExtractedField<JSONValue>]]) -> [String: ExtractedField<JSONValue>] {
        values.compactMapValues { fields in
            fields.max { lhs, rhs in
                sourceRank(lhs.source) + lhs.confidence * 10 < sourceRank(rhs.source) + rhs.confidence * 10
            }
        }
    }

    private func resolveStatus(
        inspection: HTTPInspection?,
        fragment: MetadataFragment,
        title: ExtractedField<String>?,
        description: ExtractedField<String>?,
        attributes: [String: ExtractedField<JSONValue>]
    ) -> MetadataStatus {
        if inspection?.isRemovedPage == true { return .removed }
        if inspection?.isBlockedPage == true { return .blocked }
        if inspection?.isLoginPage == true { return .loginRequired }
        if let hint = fragment.statusHints.max(by: { $0.confidence < $1.confidence }), hint.confidence >= 0.60 { return hint.status }
        guard title != nil else { return .failed }
        let hasRichFields = description != nil || !fragment.imageCandidates.isEmpty || !attributes.isEmpty || !fragment.creatorCandidates.isEmpty
        return hasRichFields ? .complete : .partial
    }

    private func isWeakTitle(_ value: String) -> Bool {
        let lower = value.lowercased()
        return value.count < 2 || ["untitled", "document", "home", "index", "javascript required", "로그인"].contains(lower)
    }

    private func sourceRank(_ source: MetadataSource) -> Double {
        [.jsonLD: 100, .openGraph: 90, .microdata: 84, .rdfa: 82, .semanticDOM: 78, .httpHeader: 74, .twitterCard: 72, .embeddedState: 70, .urlPattern: 45, .derived: 30][source] ?? 0
    }

    private func imageScore(_ field: ExtractedField<String>) -> Double {
        let rank: Double = [.openGraph: 100, .twitterCard: 90, .jsonLD: 85, .microdata: 80, .rdfa: 78, .semanticDOM: 70, .embeddedState: 68, .httpHeader: 65, .urlPattern: 40, .derived: 30][field.source] ?? 0
        return rank + field.confidence * 10
    }

    private func tagScore(_ field: ExtractedField<[String]>) -> Double {
        let rank: Double = [.jsonLD: 100, .openGraph: 90, .httpHeader: 80, .semanticDOM: 70, .embeddedState: 65, .microdata: 75, .rdfa: 72, .twitterCard: 55, .urlPattern: 40, .derived: 30][field.source] ?? 0
        return rank + field.confidence * 10
    }

    private func registrableHost(_ host: String?) -> String? {
        guard let host else { return nil }
        let labels = host.lowercased().split(separator: ".")
        guard labels.count > 2 else { return host.lowercased() }
        return labels.suffix(2).joined(separator: ".")
    }
}
