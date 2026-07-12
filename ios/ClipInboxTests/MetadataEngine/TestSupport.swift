import Foundation
@testable import ClipInbox

actor MockHTTPInspector: HTTPInspecting {
    private var queue: [Result<HTTPPayload, Error>]
    private(set) var requestCount = 0

    init(payloads: [HTTPPayload]) {
        self.queue = payloads.map(Result.success)
    }

    init(results: [Result<HTTPPayload, Error>]) {
        self.queue = results
    }

    func inspect(url: URL, configuration: MetadataConfiguration) async throws -> HTTPPayload {
        requestCount += 1
        guard !queue.isEmpty else { throw MetadataEngineError.invalidResponse }
        let result = queue.count == 1 ? queue[0] : queue.removeFirst()
        return try result.get()
    }
}

final class MockRenderer: MetadataRendering, @unchecked Sendable {
    let page: RenderedPage
    nonisolated(unsafe) private(set) var calls = 0

    init(page: RenderedPage) {
        self.page = page
    }

    @MainActor
    func render(url: URL, configuration: MetadataConfiguration) async throws -> RenderedPage {
        calls += 1
        return page
    }
}

/// Xcode 테스트 번들에서 fixture를 찾기 위한 앵커. SwiftPM의 `Bundle.module`은
/// XcodeGen 테스트 타깃에는 존재하지 않는다.
private final class FixtureBundleAnchor {}

func fixture(_ name: String) throws -> String {
    guard let url = Bundle(for: FixtureBundleAnchor.self).url(forResource: name, withExtension: "html") else {
        throw NSError(domain: "Fixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing fixture: \(name)"])
    }
    return try String(contentsOf: url, encoding: .utf8)
}

func htmlPayload(
    url: String,
    html: String,
    statusCode: Int = 200,
    login: Bool = false,
    blocked: Bool = false,
    removed: Bool = false,
    redirects: [RedirectHop] = []
) -> HTTPPayload {
    let data = Data(html.utf8)
    return HTTPPayload(
        inspection: HTTPInspection(
            statusCode: statusCode,
            finalURL: url,
            contentType: "text/html",
            contentLength: Int64(data.count),
            charset: "utf-8",
            redirects: redirects,
            isHTML: true,
            isLoginPage: login,
            isBlockedPage: blocked,
            isRemovedPage: removed,
            responseBytes: data.count
        ),
        data: data,
        text: html,
        headers: ["content-type": "text/html; charset=utf-8"]
    )
}

func binaryPayload(url: String, data: Data, mime: String, filename: String? = nil) -> HTTPPayload {
    HTTPPayload(
        inspection: HTTPInspection(
            statusCode: 200,
            finalURL: url,
            contentType: mime,
            contentLength: Int64(data.count),
            contentDisposition: filename.map { "attachment; filename=\"\($0)\"" },
            downloadFilename: filename,
            isHTML: false,
            responseBytes: data.count
        ),
        data: data,
        text: mime.hasPrefix("text/") ? String(data: data, encoding: .utf8) : nil,
        headers: ["content-type": mime]
    )
}

func makeEngine(
    inspector: any HTTPInspecting,
    cache: any MetadataCaching = MemoryMetadataCache(),
    renderer: (any MetadataRendering)? = nil,
    configuration: MetadataConfiguration = MetadataConfiguration(totalTimeout: 5),
    registry: PlatformRegistry = PlatformRegistry()
) -> URLMetadataEngine {
    URLMetadataEngine(
        configuration: configuration,
        normalizer: URLNormalizer(),
        inspector: inspector,
        cache: cache,
        renderer: renderer,
        registry: registry
    )
}
