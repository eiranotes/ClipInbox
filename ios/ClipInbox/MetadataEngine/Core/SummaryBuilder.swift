import Foundation

struct SummaryBuilder: Sendable {
    func apply(to result: inout LinkMetadataResult, fragment: MetadataFragment) {
        guard let source = selectSource(result: result, fragment: fragment) else { return }
        let cleaned = clean(source.value, title: result.title?.value)
        guard cleaned.count >= 20 else { return }

        let detail = truncate(cleaned, maximum: 240)
        guard detail.count >= 20 else { return }
        let short = truncate(detail, maximum: 60)
        let confidence = max(0.40, min(source.confidence * 0.92, 0.92))
        result.summaryDetail = .init(value: detail, source: .derived, confidence: confidence, rawValue: .string(source.value))
        result.summaryShort = .init(value: short, source: .derived, confidence: max(0.35, confidence - 0.04), rawValue: .string(source.value))
    }

    private func selectSource(result: LinkMetadataResult, fragment: MetadataFragment) -> ExtractedField<String>? {
        let type = result.contentType.lowercased()
        var candidates: [ExtractedField<String>] = []

        let isRepository = ["repository", "githubrepository", "softwaresourcecode"].contains(type)
            && (result.contentSubtype?.lowercased() == "repository" || type != "softwaresourcecode")
        if isRepository {
            if let about = result.description { candidates.append(about) }
            if let readme = stringAttribute("readmeExcerpt", in: result.attributes) { candidates.append(readme) }
        }
        if ["scholarlyarticle", "paper"].contains(type), let abstract = stringAttribute("abstract", in: result.attributes) {
            candidates.append(abstract)
        }
        if type == "product", let product = result.description {
            candidates.append(product)
        }
        if ["article", "newsarticle", "blogposting"].contains(type) {
            candidates += fragment.excerptCandidates
        }
        if ["socialpost", "socialmediaposting", "discussion"].contains(type) {
            candidates += fragment.bodyTextCandidates
        }
        candidates += [result.description].compactMap { $0 }
        candidates += fragment.excerptCandidates
        candidates += fragment.bodyTextCandidates
        return candidates.first(where: { HTMLTools.isMeaningful($0.value, minimumLength: 20) })
    }

    private func stringAttribute(_ key: String, in values: [String: ExtractedField<JSONValue>]) -> ExtractedField<String>? {
        guard let field = values[key], let value = field.value.stringValue else { return nil }
        return .init(value: value, source: field.source, confidence: field.confidence, rawValue: field.rawValue)
    }

    private func clean(_ raw: String, title: String?) -> String {
        var value = HTMLTools.cleanText(raw, maximumLength: 3_000)
        value = HTMLTools.removeHashtags(from: value)
        value = HTMLTools.replacingMatches(#"https?://\S+"#, in: value, with: " ", options: [.caseInsensitive])
        value = HTMLTools.replacingMatches(#"\s+"#, in: value, with: " ", options: [])

        let boilerplate = [
            "sign in to continue", "log in to continue", "create an account", "enable javascript",
            "accept all cookies", "we use cookies", "로그인 후 이용", "로그인하여 계속", "회원가입",
            "쿠키를 사용", "javascript를 활성화"
        ]
        let sentences = splitSentences(value).filter { sentence in
            let lower = sentence.lowercased()
            return !boilerplate.contains(where: lower.contains)
        }
        value = sentences.joined(separator: " ")

        if let title {
            let normalizedTitle = normalizeForComparison(title)
            let prefix = String(value.prefix(max(title.count + 12, 30)))
            if normalizeForComparison(prefix).hasPrefix(normalizedTitle), let firstBoundary = firstSentenceBoundary(in: value) {
                let first = String(value[..<firstBoundary])
                if normalizeForComparison(first) == normalizedTitle {
                    value = String(value[firstBoundary...]).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                }
            }
        }
        return HTMLTools.cleanText(value)
    }

    private func truncate(_ value: String, maximum: Int) -> String {
        guard value.count > maximum else { return value }
        let prefix = String(value.prefix(maximum + 1))
        let boundaries = prefix.indices.filter { index in
            let character = prefix[index]
            return ".!?。！？\n".contains(character)
        }
        if let boundary = boundaries.last, prefix.distance(from: prefix.startIndex, to: boundary) >= maximum / 2 {
            return String(prefix[...boundary]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let allowed = String(prefix.prefix(maximum))
        if let space = allowed.lastIndex(where: { $0.isWhitespace }), allowed.distance(from: allowed.startIndex, to: space) >= maximum / 2 {
            return String(allowed[..<space]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }
        return allowed.trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private func splitSentences(_ value: String) -> [String] {
        value.split(whereSeparator: { ".!?。！？\n".contains($0) }).map { HTMLTools.cleanText(String($0)) }.filter { !$0.isEmpty }
    }

    private func firstSentenceBoundary(in value: String) -> String.Index? {
        value.firstIndex(where: { ".!?。！？\n".contains($0) })
    }

    private func normalizeForComparison(_ value: String) -> String {
        HTMLTools.replacingMatches(#"[^\p{L}\p{N}]+"#, in: value.lowercased(), with: "", options: [])
    }
}
