import Foundation

struct HTMLDocument: Sendable {
    var html: String
    var baseURL: URL
    var configuration: MetadataConfiguration
}

enum HTMLTools {
    static func matches(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = [.caseInsensitive, .dotMatchesLineSeparators]
    ) -> [[String]] {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, options: [], range: range).map { match in
            (0..<match.numberOfRanges).map { index in
                let range = match.range(at: index)
                guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return "" }
                return String(text[swiftRange])
            }
        }
    }

    static func firstMatch(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = [.caseInsensitive, .dotMatchesLineSeparators]
    ) -> [String]? {
        matches(pattern, in: text, options: options).first
    }

    static func replacingMatches(
        _ pattern: String,
        in text: String,
        with replacement: String,
        options: NSRegularExpression.Options = [.caseInsensitive, .dotMatchesLineSeparators]
    ) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }

    static func attributes(from source: String) -> [String: String] {
        let pattern = #"([A-Za-z_:][A-Za-z0-9_:.-]*)\s*(?:=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s\"'=<>`]+)))?"#
        var values: [String: String] = [:]
        for match in matches(pattern, in: source, options: []) where match.count >= 5 {
            let key = match[1].lowercased()
            let raw = [match[2], match[3], match[4]].first(where: { !$0.isEmpty }) ?? ""
            values[key] = decodeHTMLEntities(raw)
        }
        return values
    }

    static func tags(named name: String, in html: String) -> [[String: String]] {
        matches(#"<"# + NSRegularExpression.escapedPattern(for: name) + #"\b([^>]*)>"#, in: html)
            .compactMap { $0.count > 1 ? attributes(from: $0[1]) : nil }
    }

    static func pairedTags(named name: String, in html: String) -> [(attributes: [String: String], innerHTML: String)] {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        return matches(#"<"# + escaped + #"\b([^>]*)>(.*?)</"# + escaped + #"\s*>"#, in: html).compactMap { match in
            guard match.count > 2 else { return nil }
            return (attributes(from: match[1]), match[2])
        }
    }

    static func scriptBlocks(in html: String) -> [(attributes: [String: String], content: String)] {
        pairedTags(named: "script", in: html).map { ($0.attributes, $0.innerHTML) }
    }

    static func resolveURL(_ rawValue: String?, relativeTo baseURL: URL) -> String? {
        guard let rawValue else { return nil }
        let cleaned = decodeHTMLEntities(rawValue).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              !cleaned.lowercased().hasPrefix("data:"),
              !cleaned.lowercased().hasPrefix("javascript:") else { return nil }
        return URL(string: cleaned, relativeTo: baseURL)?.absoluteURL.absoluteString
    }

    static func cleanText(_ rawValue: String, maximumLength: Int? = nil) -> String {
        var value = decodeHTMLEntities(rawValue)
        value = replacingMatches(#"(?is)<br\s*/?>"#, in: value, with: "\n")
        value = replacingMatches(#"(?is)</(?:p|div|li|h[1-6]|article|section|blockquote|tr)>"#, in: value, with: "\n")
        value = replacingMatches(#"(?is)<[^>]+>"#, in: value, with: " ")
        value = value.replacingOccurrences(of: "\u{00A0}", with: " ")
        value = replacingMatches(#"[\t\u{000B}\f\r ]+"#, in: value, with: " ", options: [])
        value = replacingMatches(#"\n[ \t]+"#, in: value, with: "\n", options: [])
        value = replacingMatches(#"\n{3,}"#, in: value, with: "\n\n", options: [])
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let maximumLength, value.count > maximumLength {
            value = String(value.prefix(maximumLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
    }

    static func sanitizeBody(_ html: String) -> String {
        var value = replacingMatches(#"(?is)<!--.*?-->"#, in: html, with: " ")
        let removable = ["script", "style", "noscript", "template", "svg", "canvas", "header", "nav", "footer", "aside", "form"]
        for tag in removable {
            let escaped = NSRegularExpression.escapedPattern(for: tag)
            value = replacingMatches(#"(?is)<"# + escaped + #"\b[^>]*>.*?</"# + escaped + #"\s*>"#, in: value, with: " ")
        }
        value = replacingMatches(#"(?is)<([a-z0-9]+)\b[^>]*(?:aria-hidden\s*=\s*['\"]?true|\bhidden\b|display\s*:\s*none|visibility\s*:\s*hidden)[^>]*>.*?</\1\s*>"#, in: value, with: " ")
        return value
    }

    static func firstMeaningfulParagraph(in html: String, minimumLength: Int = 40) -> String? {
        for paragraph in pairedTags(named: "p", in: html) {
            let value = cleanText(paragraph.innerHTML)
            if isMeaningful(value, minimumLength: minimumLength) { return value }
        }
        return nil
    }

    static func isMeaningful(_ value: String, minimumLength: Int = 24) -> Bool {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= minimumLength else { return false }
        let lower = text.lowercased()
        let boilerplate = [
            "cookie", "쿠키", "로그인", "회원가입", "sign in", "sign up", "enable javascript",
            "javascript를 활성화", "all rights reserved", "privacy policy", "개인정보처리방침"
        ]
        return !boilerplate.contains(where: lower.contains)
    }

    static func decodeHTMLEntities(_ value: String) -> String {
        var output = value
        let named: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'",
            "&apos;": "'", "&nbsp;": " ", "&ndash;": "–", "&mdash;": "—", "&hellip;": "…",
            "&copy;": "©", "&reg;": "®", "&trade;": "™", "&middot;": "·", "&bull;": "•",
            "&lsquo;": "‘", "&rsquo;": "’", "&ldquo;": "“", "&rdquo;": "”"
        ]
        for (entity, replacement) in named {
            output = output.replacingOccurrences(of: entity, with: replacement, options: .caseInsensitive)
        }

        guard let expression = try? NSRegularExpression(pattern: #"&#(x?[0-9A-Fa-f]+);?"#, options: []) else { return output }
        let matches = expression.matches(in: output, range: NSRange(output.startIndex..<output.endIndex, in: output)).reversed()
        for match in matches {
            guard match.numberOfRanges > 1,
                  let wholeRange = Range(match.range(at: 0), in: output),
                  let numberRange = Range(match.range(at: 1), in: output) else { continue }
            let token = String(output[numberRange])
            let radix = token.lowercased().hasPrefix("x") ? 16 : 10
            let digits = radix == 16 ? String(token.dropFirst()) : token
            guard let scalarValue = UInt32(digits, radix: radix), let scalar = UnicodeScalar(scalarValue) else { continue }
            output.replaceSubrange(wholeRange, with: String(Character(scalar)))
        }
        return output
    }

    static func commaSeparated(_ rawValue: String) -> [String] {
        rawValue
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "|" })
            .map { cleanText(String($0)) }
            .filter { !$0.isEmpty }
    }

    static func hashtags(in text: String) -> [String] {
        let matches = matches(#"(?<![\p{L}\p{N}_])#([\p{L}\p{N}_]{2,50})"#, in: text, options: [])
        var seen = Set<String>()
        return matches.compactMap { match in
            guard match.count > 1 else { return nil }
            let value = match[1]
            let key = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return seen.insert(key).inserted ? value : nil
        }
    }

    static func removeHashtags(from text: String) -> String {
        cleanText(replacingMatches(#"(?<![\p{L}\p{N}_])#[\p{L}\p{N}_]{2,50}"#, in: text, with: "", options: []))
    }

    static func parseISODuration(_ rawValue: String?) -> Int? {
        guard let rawValue, !rawValue.isEmpty else { return nil }
        if let seconds = Int(rawValue), seconds >= 0 { return seconds }
        guard let match = firstMatch(#"^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?)?$"#, in: rawValue, options: [.caseInsensitive]), match.count >= 5 else {
            return nil
        }
        let days = Int(match[1]) ?? 0
        let hours = Int(match[2]) ?? 0
        let minutes = Int(match[3]) ?? 0
        let seconds = Double(match[4]) ?? 0
        return days * 86_400 + hours * 3_600 + minutes * 60 + Int(seconds.rounded())
    }

    static func normalizedDate(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let value = cleanText(rawValue)
        guard !value.isEmpty else { return nil }
        let formatters: [ISO8601DateFormatter] = {
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let internet = ISO8601DateFormatter()
            internet.formatOptions = [.withInternetDateTime]
            let dateOnly = ISO8601DateFormatter()
            dateOnly.formatOptions = [.withFullDate]
            return [withFraction, internet, dateOnly]
        }()
        for formatter in formatters {
            if let date = formatter.date(from: value) {
                return ISO8601DateFormatter.clipInbox.string(from: date)
            }
        }
        if firstMatch(#"\b(?:19|20)\d{2}[-./]\d{1,2}[-./]\d{1,2}\b"#, in: value, options: []) != nil {
            return value
        }
        return nil
    }

    static func normalizedLanguage(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else { return nil }
        return String(value.split(separator: "-").first ?? Substring(value))
    }

    static func approximateReadingMinutes(text: String, language: String?) -> Int? {
        let clean = cleanText(text)
        guard clean.count >= 160 else { return nil }
        let isCJK = ["ko", "ja", "zh"].contains(language ?? "") || clean.unicodeScalars.contains { scalar in
            (0x3040...0x30FF).contains(scalar.value) || (0x3400...0x9FFF).contains(scalar.value) || (0xAC00...0xD7AF).contains(scalar.value)
        }
        if isCJK {
            return max(1, Int(ceil(Double(clean.count) / 500.0)))
        }
        let words = clean.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        return max(1, Int(ceil(Double(words) / 220.0)))
    }

    static func slugTitle(from url: URL) -> String? {
        let component = url.pathComponents.last(where: { $0 != "/" && !$0.isEmpty }) ?? ""
        guard !component.isEmpty else { return nil }
        let decoded = component.removingPercentEncoding ?? component
        let withoutExtension = (decoded as NSString).deletingPathExtension
        let spaced = withoutExtension.replacingOccurrences(of: #"[-_]+"#, with: " ", options: .regularExpression)
        let clean = cleanText(spaced)
        guard clean.count >= 3, clean.rangeOfCharacter(from: .letters) != nil else { return nil }
        return clean
    }

    static func domainDisplayName(_ url: URL) -> String {
        guard var host = url.host?.lowercased() else { return url.absoluteString }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }
}
