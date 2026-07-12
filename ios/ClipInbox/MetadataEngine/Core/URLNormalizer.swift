import Foundation

public enum MetadataEngineError: LocalizedError, Equatable, Sendable {
    case invalidURL
    case unsupportedScheme
    case credentialsNotAllowed
    case unsafeDestination
    case redirectLoop
    case redirectLimitExceeded
    case responseTooLarge
    case requestTimedOut
    case invalidResponse
    case cancelled
    case renderingUnavailable
    case renderingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "유효한 URL이 아닙니다."
        case .unsupportedScheme: return "HTTP 또는 HTTPS URL만 지원합니다."
        case .credentialsNotAllowed: return "인증정보가 포함된 URL은 분석하지 않습니다."
        case .unsafeDestination: return "로컬 또는 비공개 네트워크 주소는 분석하지 않습니다."
        case .redirectLoop: return "리다이렉트가 같은 URL을 반복합니다."
        case .redirectLimitExceeded: return "리다이렉트 횟수 제한을 초과했습니다."
        case .responseTooLarge: return "응답이 허용된 크기를 초과했습니다."
        case .requestTimedOut: return "페이지 요청 시간이 초과됐습니다."
        case .invalidResponse: return "유효한 HTTP 응답을 받지 못했습니다."
        case .cancelled: return "분석이 취소됐습니다."
        case .renderingUnavailable: return "렌더링 분석을 사용할 수 없습니다."
        case .renderingFailed: return "렌더링된 페이지를 분석하지 못했습니다."
        }
    }
}

public struct URLNormalizationResult: Codable, Equatable, Sendable {
    public var originalURL: String
    public var normalizedURL: URL
    public var originalFragment: String?
    public var removedTrackingParameters: [String]

    public init(originalURL: String, normalizedURL: URL, originalFragment: String?, removedTrackingParameters: [String]) {
        self.originalURL = originalURL
        self.normalizedURL = normalizedURL
        self.originalFragment = originalFragment
        self.removedTrackingParameters = removedTrackingParameters
    }
}

public struct URLNormalizer: Sendable {
    private static let exactTrackingKeys: Set<String> = [
        "fbclid", "gclid", "dclid", "msclkid", "igshid", "mc_cid", "mc_eid",
        "mkt_tok", "yclid", "_hsenc", "_hsmi", "vero_conv", "vero_id",
        "ref_src", "ref_url", "spm", "scm", "si", "feature"
    ]

    private static let trackingPrefixes = ["utm_", "pk_", "ga_", "wt_"]

    public init() {}

    public func normalize(_ rawValue: String) throws -> URLNormalizationResult {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let originalHost = components.host,
              !originalHost.isEmpty else {
            throw MetadataEngineError.invalidURL
        }

        guard scheme == "http" || scheme == "https" else {
            throw MetadataEngineError.unsupportedScheme
        }
        guard components.user == nil, components.password == nil else {
            throw MetadataEngineError.credentialsNotAllowed
        }

        components.scheme = scheme
        components.user = nil
        components.password = nil
        components.fragment = nil
        components.host = normalizeHost(originalHost)

        if (scheme == "http" && components.port == 80) || (scheme == "https" && components.port == 443) {
            components.port = nil
        }

        let originalFragment = URLComponents(string: trimmed)?.fragment
        var removed: [String] = []
        if let items = components.queryItems, !items.isEmpty {
            var retained: [URLQueryItem] = []
            for item in items {
                let key = item.name.lowercased()
                if Self.exactTrackingKeys.contains(key) || Self.trackingPrefixes.contains(where: key.hasPrefix) {
                    removed.append(item.name)
                } else {
                    retained.append(item)
                }
            }
            components.queryItems = retained.isEmpty ? nil : retained.sorted {
                if $0.name == $1.name { return ($0.value ?? "") < ($1.value ?? "") }
                return $0.name < $1.name
            }
        }

        if components.percentEncodedPath.isEmpty {
            components.percentEncodedPath = "/"
        }
        components.percentEncodedPath = normalizedPath(components.percentEncodedPath)

        guard let url = components.url else { throw MetadataEngineError.invalidURL }
        try validateNetworkDestination(url)
        return URLNormalizationResult(
            originalURL: trimmed,
            normalizedURL: url,
            originalFragment: originalFragment,
            removedTrackingParameters: removed
        )
    }

    public func validateRedirect(_ url: URL) throws -> URL {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw MetadataEngineError.unsupportedScheme
        }
        guard url.user == nil, url.password == nil else {
            throw MetadataEngineError.credentialsNotAllowed
        }
        try validateNetworkDestination(url)
        return url
    }

    public func validateNetworkDestination(_ url: URL) throws {
        guard let host = url.host?.lowercased(), !host.isEmpty else {
            throw MetadataEngineError.invalidURL
        }
        if host == "localhost" || host.hasSuffix(".localhost") || host.hasSuffix(".local") || host == "0.0.0.0" {
            throw MetadataEngineError.unsafeDestination
        }
        if isPrivateIPv4(host) || isPrivateIPv6(host) {
            throw MetadataEngineError.unsafeDestination
        }
    }

    public func redactedForLogging(_ rawValue: String) -> String {
        guard var components = URLComponents(string: rawValue) else { return "<invalid-url>" }
        components.user = nil
        components.password = nil
        if let items = components.queryItems, !items.isEmpty {
            components.queryItems = items.map { URLQueryItem(name: $0.name, value: "<redacted>") }
        }
        return components.string ?? "<invalid-url>"
    }

    private func normalizeHost(_ rawHost: String) -> String {
        var host = rawHost.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let aliases: [String: String] = [
            "m.youtube.com": "www.youtube.com",
            "music.youtube.com": "www.youtube.com",
            "mobile.twitter.com": "x.com",
            "twitter.com": "x.com",
            "m.reddit.com": "www.reddit.com",
            "old.reddit.com": "www.reddit.com",
            "m.blog.naver.com": "blog.naver.com"
        ]
        host = aliases[host] ?? host
        return host
    }

    private func normalizedPath(_ rawPath: String) -> String {
        var path = rawPath.replacingOccurrences(of: #"/{2,}"#, with: "/", options: .regularExpression)
        if path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        return path.isEmpty ? "/" : path
    }

    private func isPrivateIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".")
        let values = parts.compactMap { Int($0) }
        guard parts.count == 4, values.count == 4, values.allSatisfy({ (0...255).contains($0) }) else {
            return false
        }
        let a = values[0], b = values[1]
        if a == 10 || a == 127 || a == 0 { return true }
        if a == 169 && b == 254 { return true }
        if a == 172 && (16...31).contains(b) { return true }
        if a == 192 && b == 168 { return true }
        if a == 100 && (64...127).contains(b) { return true }
        if a >= 224 { return true }
        return false
    }

    private func isPrivateIPv6(_ host: String) -> Bool {
        let value = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]")).lowercased()
        guard value.contains(":") else { return false }
        return value == "::1"
            || value == "::"
            || value.hasPrefix("fc")
            || value.hasPrefix("fd")
            || value.hasPrefix("fe8")
            || value.hasPrefix("fe9")
            || value.hasPrefix("fea")
            || value.hasPrefix("feb")
    }
}
