import Foundation

struct PlatformAdapterContext: Sendable {
    var url: URL
    var document: HTMLDocument?
    var genericFragment: MetadataFragment
}

protocol PlatformAdapter: Sendable {
    var identifier: String { get }
    func matches(_ url: URL) -> Bool
    func extract(_ context: PlatformAdapterContext) throws -> MetadataFragment
}

struct PlatformRegistry: Sendable {
    private let adapters: [any PlatformAdapter]

    init(adapters: [any PlatformAdapter] = PlatformRegistry.defaultAdapters) {
        self.adapters = adapters
    }

    func extract(url: URL, document: HTMLDocument?, genericFragment: MetadataFragment) -> MetadataFragment {
        var combined = MetadataFragment()
        for adapter in adapters where adapter.matches(url) {
            do {
                combined.merge(try adapter.extract(.init(url: url, document: document, genericFragment: genericFragment)))
            } catch {
                combined.adapterFailures.append("\(adapter.identifier): \(error.localizedDescription)")
            }
        }
        if combined.platformCandidates.isEmpty {
            combined.platformCandidates.append(.init(value: HTMLTools.domainDisplayName(url), confidence: 0.50, source: .urlPattern))
        }
        return combined
    }

    static let defaultAdapters: [any PlatformAdapter] = [
        YouTubeAdapter(),
        GitHubAdapter(),
        RedditAdapter(),
        NaverBlogAdapter(),
        KoreanPublishingAdapter(),
        SocialPlatformAdapter(),
        AppMarketplaceAdapter(),
        AcademicPlatformAdapter(),
        DeveloperResourceAdapter(),
        DocumentPlatformAdapter(),
        MediaPlatformAdapter(),
        ShoppingPlatformAdapter()
    ]
}

extension URL {
    var lowercasedHost: String { host?.lowercased() ?? "" }
    var decodedPathComponents: [String] {
        pathComponents.filter { $0 != "/" }.map { $0.removingPercentEncoding ?? $0 }
    }
    var queryDictionary: [String: String] {
        Dictionary(uniqueKeysWithValues: (URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems ?? []).compactMap {
            guard let value = $0.value else { return nil }
            return ($0.name, value)
        })
    }
}
