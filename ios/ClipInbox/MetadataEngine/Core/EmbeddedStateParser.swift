import Foundation

struct EmbeddedStateParser: Sendable {
    private let knownIdentifiers = [
        "__next_data__", "__nuxt__", "__nuxt_data__", "__initial_state__", "__preloaded_state__",
        "__apollo_state__", "hydration", "initial-state", "page-data", "player-response"
    ]

    func parse(_ document: HTMLDocument) -> MetadataFragment {
        var fragment = MetadataFragment()
        var roots: [Any] = []

        for block in HTMLTools.scriptBlocks(in: document.html) {
            let type = block.attributes["type"]?.lowercased() ?? ""
            let id = block.attributes["id"]?.lowercased() ?? ""
            let isCandidate = type == "application/json"
                || type == "application/ld+json; charset=utf-8"
                || knownIdentifiers.contains(where: { id.contains($0) })
            guard isCandidate,
                  block.content.utf8.count <= document.configuration.maximumEmbeddedStateBytes,
                  let root = parseJSON(block.content) else { continue }
            roots.append(root)
        }

        let assignmentNames = [
            "__NEXT_DATA__", "__NUXT__", "__INITIAL_STATE__", "__PRELOADED_STATE__",
            "ytInitialPlayerResponse", "window.__APOLLO_STATE__"
        ]
        for name in assignmentNames {
            for json in balancedJSONAssignments(named: name, in: document.html).prefix(3) {
                guard json.utf8.count <= document.configuration.maximumEmbeddedStateBytes,
                      let root = parseJSON(json) else { continue }
                roots.append(root)
            }
        }

        for root in roots.prefix(20) {
            extract(root, baseURL: document.baseURL, fragment: &fragment, depth: 0, path: [])
        }
        return fragment
    }

    func balancedJSONAssignments(named name: String, in html: String) -> [String] {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        let pattern = escaped + #"\s*(?:=|:)\s*"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        var results: [String] = []
        for match in expression.matches(in: html, range: nsRange) {
            guard let end = Range(match.range, in: html)?.upperBound else { continue }
            let suffix = html[end...]
            guard let firstIndex = suffix.firstIndex(where: { $0 == "{" || $0 == "[" }) else { continue }
            if let json = balancedJSON(from: html, start: firstIndex) { results.append(json) }
        }
        return results
    }

    private func parseJSON(_ raw: String) -> Any? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("<!--") { value.removeFirst(4) }
        if value.hasSuffix("-->") { value.removeLast(3) }
        if value.hasSuffix(";") { value.removeLast() }
        guard let data = value.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    private func balancedJSON(from text: String, start: String.Index) -> String? {
        let opener = text[start]
        guard opener == "{" || opener == "[" else { return nil }
        let closer: Character = opener == "{" ? "}" : "]"
        var depth = 0
        var inString = false
        var escaping = false
        var index = start
        while index < text.endIndex {
            let character = text[index]
            if inString {
                if escaping { escaping = false }
                else if character == "\\" { escaping = true }
                else if character == "\"" { inString = false }
            } else {
                if character == "\"" { inString = true }
                else if character == opener { depth += 1 }
                else if character == closer {
                    depth -= 1
                    if depth == 0 {
                        return String(text[start...index])
                    }
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    private func extract(
        _ value: Any,
        baseURL: URL,
        fragment: inout MetadataFragment,
        depth: Int,
        path: [String]
    ) {
        guard depth <= 14 else { return }
        if let array = value as? [Any] {
            for item in array.prefix(200) { extract(item, baseURL: baseURL, fragment: &fragment, depth: depth + 1, path: path) }
            return
        }
        guard let dictionary = value as? [String: Any] else { return }

        let keys = Set(dictionary.keys.map { $0.lowercased() })
        let contentSignals = ["title", "headline", "description", "caption", "author", "username", "thumbnail", "image", "url"]
            .filter(keys.contains).count
        let pathText = path.joined(separator: ".").lowercased()
        let likelyContentNode = contentSignals >= 2
            || pathText.contains("post")
            || pathText.contains("article")
            || pathText.contains("video")
            || pathText.contains("product")
            || pathText.contains("pageprops")

        if likelyContentNode {
            appendFirstString(dictionary, keys: ["headline", "title", "name"], to: &fragment.titleCandidates, confidence: 0.66)
            appendFirstString(dictionary, keys: ["description", "abstract", "caption", "summary"], to: &fragment.descriptionCandidates, confidence: 0.64)
            appendFirstString(dictionary, keys: ["authorname", "channelname", "username", "displayname", "creatorname"], to: &fragment.creatorCandidates, confidence: 0.62)
            appendFirstDate(dictionary, keys: ["datepublished", "publishedat", "uploaddate", "createdat", "publishdate"], to: &fragment.publishedAtCandidates, confidence: 0.66)
            appendFirstDate(dictionary, keys: ["datemodified", "modifiedat", "updatedat"], to: &fragment.modifiedAtCandidates, confidence: 0.62)
            appendImages(dictionary, baseURL: baseURL, fragment: &fragment)
            appendDuration(dictionary, fragment: &fragment)
            appendTags(dictionary, fragment: &fragment)
        }

        for (key, child) in dictionary {
            if child is [String: Any] || child is [Any] {
                extract(child, baseURL: baseURL, fragment: &fragment, depth: depth + 1, path: path + [key])
            }
        }
    }

    private func appendFirstString(
        _ dictionary: [String: Any],
        keys: [String],
        to values: inout [ExtractedField<String>],
        confidence: Double
    ) {
        for key in keys {
            guard let raw = value(forLowercasedKey: key, in: dictionary), let value = scalarString(raw) else { continue }
            let clean = HTMLTools.cleanText(value)
            guard clean.count >= 2, clean.count <= 5_000 else { continue }
            values.append(.init(value: clean, source: .embeddedState, confidence: confidence, rawValue: JSONValue(raw)))
            return
        }
    }

    private func appendFirstDate(
        _ dictionary: [String: Any],
        keys: [String],
        to values: inout [ExtractedField<String>],
        confidence: Double
    ) {
        for key in keys {
            guard let raw = value(forLowercasedKey: key, in: dictionary),
                  let value = scalarString(raw),
                  let normalized = HTMLTools.normalizedDate(value) else { continue }
            values.append(.init(value: normalized, source: .embeddedState, confidence: confidence, rawValue: JSONValue(raw)))
            return
        }
    }

    private func appendImages(_ dictionary: [String: Any], baseURL: URL, fragment: inout MetadataFragment) {
        let keys = ["thumbnailurl", "thumbnail_url", "imageurl", "image_url", "ogimage", "poster", "thumbnail"]
        for key in keys {
            guard let raw = value(forLowercasedKey: key, in: dictionary) else { continue }
            let candidates = strings(from: raw)
            for candidate in candidates.prefix(3) {
                if let url = HTMLTools.resolveURL(candidate, relativeTo: baseURL) {
                    fragment.imageCandidates.append(.init(value: url, source: .embeddedState, confidence: 0.64, rawValue: .string(candidate)))
                }
            }
        }
    }

    private func appendDuration(_ dictionary: [String: Any], fragment: inout MetadataFragment) {
        for key in ["lengthseconds", "durationseconds", "duration"] {
            guard let raw = value(forLowercasedKey: key, in: dictionary), let value = scalarString(raw), let seconds = HTMLTools.parseISODuration(value) else { continue }
            fragment.durationCandidates.append(.init(value: seconds, source: .embeddedState, confidence: 0.72, rawValue: JSONValue(raw)))
            return
        }
    }

    private func appendTags(_ dictionary: [String: Any], fragment: inout MetadataFragment) {
        for key in ["keywords", "tags", "hashtags"] {
            guard let raw = value(forLowercasedKey: key, in: dictionary) else { continue }
            let values = strings(from: raw).flatMap(HTMLTools.commaSeparated).map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "#")) }.filter { !$0.isEmpty }
            guard !values.isEmpty else { continue }
            fragment.originalTagCandidates.append(.init(value: Array(values.prefix(20)), source: .embeddedState, confidence: 0.64, rawValue: JSONValue(raw)))
            return
        }
    }

    private func value(forLowercasedKey key: String, in dictionary: [String: Any]) -> Any? {
        dictionary.first { $0.key.lowercased() == key }?.value
    }

    private func scalarString(_ value: Any) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        if let value = value as? [String: Any] {
            return scalarString(value["name"] as Any) ?? scalarString(value["text"] as Any) ?? scalarString(value["url"] as Any)
        }
        return nil
    }

    private func strings(from value: Any) -> [String] {
        if let string = scalarString(value) { return [string] }
        if let values = value as? [Any] { return values.compactMap(scalarString) }
        if let dictionary = value as? [String: Any] {
            return dictionary.values.compactMap(scalarString)
        }
        return []
    }
}
