import Foundation

public final class URLMetadataEngine: @unchecked Sendable {
    private let configuration: MetadataConfiguration
    private let normalizer: URLNormalizer
    private let inspector: any HTTPInspecting
    private let cache: any MetadataCaching
    private let renderer: (any MetadataRendering)?
    private let registry: PlatformRegistry

    public convenience init(configuration: MetadataConfiguration = .default) {
        self.init(
            configuration: configuration,
            normalizer: URLNormalizer(),
            inspector: URLSessionHTTPInspector(),
            cache: MemoryMetadataCache(),
            renderer: nil,
            registry: PlatformRegistry()
        )
    }

    init(
        configuration: MetadataConfiguration,
        normalizer: URLNormalizer,
        inspector: any HTTPInspecting,
        cache: any MetadataCaching,
        renderer: (any MetadataRendering)?,
        registry: PlatformRegistry
    ) {
        self.configuration = configuration
        self.normalizer = normalizer
        self.inspector = inspector
        self.cache = cache
        self.renderer = renderer
        self.registry = registry
    }

    public func analyze(_ rawURL: String, forceRefresh: Bool = false) async -> LinkMetadataResult {
        do {
            return try await withTimeout(seconds: configuration.totalTimeout) { [self] in
                try await performAnalysis(rawURL, forceRefresh: forceRefresh)
            }
        } catch {
            return failureResult(rawURL: rawURL, error: error, stage: error is MetadataEngineError ? .http : .resolution)
        }
    }

    public func clearCache() async {
        await cache.removeAll()
    }

    private func performAnalysis(_ rawURL: String, forceRefresh: Bool) async throws -> LinkMetadataResult {
        var attempts: [ExtractionAttempt] = []
        let normalizationStarted = Date()
        let normalization: URLNormalizationResult
        do {
            normalization = try normalizer.normalize(rawURL)
            attempts.append(attempt(.normalization, started: normalizationStarted, succeeded: true, message: normalization.removedTrackingParameters.isEmpty ? nil : "추적 매개변수 \(normalization.removedTrackingParameters.count)개 제거"))
        } catch {
            attempts.append(attempt(.normalization, started: normalizationStarted, succeeded: false, error: error))
            var result = failureResult(rawURL: rawURL, error: error, stage: .normalization)
            result.extractionAttempts = attempts
            return result
        }

        if !forceRefresh {
            let started = Date()
            if var cached = await cache.value(for: normalization.normalizedURL.absoluteString) {
                cached.extractionAttempts.append(attempt(.cache, started: started, succeeded: true, message: "canonical URL 캐시 적중"))
                return cached
            }
            attempts.append(attempt(.cache, started: started, succeeded: true, message: "캐시 없음"))
        }

        let httpStarted = Date()
        let payload: HTTPPayload
        do {
            payload = try await inspector.inspect(url: normalization.normalizedURL, configuration: configuration)
            attempts.append(attempt(.http, started: httpStarted, succeeded: true, message: "HTTP \(payload.inspection.statusCode.map(String.init) ?? "-") · \(payload.data.count) bytes"))
        } catch {
            attempts.append(attempt(.http, started: httpStarted, succeeded: false, error: error))
            var fragment = registry.extract(url: normalization.normalizedURL, document: nil, genericFragment: MetadataFragment())
            fragment.statusHints.append(.init(status: .partial, confidence: 0.58, reason: "HTTP 분석 실패 후 URL 패턴 fallback"))
            var result = FieldResolver().resolve(
                normalization: normalization,
                inspection: nil,
                fragment: fragment,
                attempts: attempts,
                configuration: configuration
            )
            result.status = result.title?.source == .derived ? .failed : .partial
            return result
        }

        let finalURL = URL(string: payload.inspection.finalURL) ?? normalization.normalizedURL
        var aggregate = MetadataFragment()
        var document: HTMLDocument?

        if payload.inspection.isHTML, let html = payload.text {
            let parsedDocument = HTMLDocument(html: html, baseURL: finalURL, configuration: configuration)
            document = parsedDocument

            let headStarted = Date()
            let head = HeadMetadataParser().parse(parsedDocument)
            aggregate.merge(head)
            attempts.append(attempt(.head, started: headStarted, succeeded: true, message: "head metadata 분석"))

            let structuredStarted = Date()
            let structured = StructuredDataParser().parse(parsedDocument, canonicalCandidates: head.canonicalURLCandidates.map(\.value))
            aggregate.merge(structured)
            attempts.append(attempt(.structuredData, started: structuredStarted, succeeded: true, message: structured.hasJSONLD ? "JSON-LD 분석" : "JSON-LD 없음"))

            let semanticStarted = Date()
            let semantic = SemanticDOMParser().parse(parsedDocument)
            aggregate.merge(semantic)
            attempts.append(attempt(.semanticDOM, started: semanticStarted, succeeded: true, message: "본문 후보 \(semantic.visibleTextLength)자"))

            let embeddedStarted = Date()
            let embedded = EmbeddedStateParser().parse(parsedDocument)
            aggregate.merge(embedded)
            attempts.append(attempt(.embeddedState, started: embeddedStarted, succeeded: true, message: embedded.attributes.isEmpty ? "embedded state 후보 없음" : "embedded state 분석"))

            let adapterStarted = Date()
            let platform = registry.extract(url: finalURL, document: parsedDocument, genericFragment: aggregate)
            aggregate.merge(platform)
            attempts.append(attempt(
                .platformAdapter,
                started: adapterStarted,
                succeeded: platform.adapterFailures.isEmpty,
                message: platform.adapterFailures.isEmpty
                    ? "플랫폼 adapter 격리 실행"
                    : "일부 adapter 실패 · generic fallback 유지: \(platform.adapterFailures.joined(separator: "; "))"
            ))

            if let explicit = firstExplicitContentURL(in: aggregate, excluding: finalURL) {
                let explicitStarted = Date()
                do {
                    let nested = try await inspectExplicitContent(explicit)
                    aggregate.merge(nested.fragment)
                    if aggregate.canonicalURLCandidates.isEmpty {
                        aggregate.canonicalURLCandidates.append(.init(value: nested.finalURL.absoluteString, source: .semanticDOM, confidence: 0.84))
                    }
                    attempts.append(attempt(.platformAdapter, started: explicitStarted, succeeded: true, message: "명시된 콘텐츠 문서 1단계 분석"))
                } catch {
                    attempts.append(attempt(.platformAdapter, started: explicitStarted, succeeded: false, error: error))
                }
            }
        } else {
            let fileStarted = Date()
            aggregate.merge(FileMetadataParser().parse(payload: payload, url: finalURL))
            let platform = registry.extract(url: finalURL, document: nil, genericFragment: aggregate)
            aggregate.merge(platform)
            attempts.append(attempt(.file, started: fileStarted, succeeded: true, message: payload.inspection.contentType ?? "binary"))
        }

        if let renderer, shouldRender(fragment: aggregate, inspection: payload.inspection, url: finalURL) {
            let renderStarted = Date()
            do {
                let rendered = try await renderer.render(url: finalURL, configuration: configuration)
                let renderedFragment = RenderedPageParser().parse(rendered, configuration: configuration)
                aggregate.merge(renderedFragment)
                if let renderedURL = URL(string: rendered.finalURL) {
                    let platform = registry.extract(url: renderedURL, document: document, genericFragment: aggregate)
                    aggregate.merge(platform)
                }
                attempts.append(attempt(.renderedDOM, started: renderStarted, succeeded: true, message: "WKWebView DOM 1회 분석"))
            } catch {
                attempts.append(attempt(.renderedDOM, started: renderStarted, succeeded: false, error: error))
            }
        }

        let resolveStarted = Date()
        var result = FieldResolver().resolve(
            normalization: normalization,
            inspection: payload.inspection,
            fragment: aggregate,
            attempts: attempts,
            configuration: configuration
        )
        result.extractionAttempts.append(attempt(.resolution, started: resolveStarted, succeeded: true, message: "필드 출처·신뢰도 병합"))

        let summaryStarted = Date()
        SummaryBuilder().apply(to: &result, fragment: aggregate)
        result.extractionAttempts.append(attempt(.summary, started: summaryStarted, succeeded: true, message: result.summaryDetail == nil ? "요약 원문 부족" : "규칙 기반 요약"))

        let keys = [result.normalizedURL, result.resolvedURL, result.canonicalURL].compactMap { $0 }
        await cache.store(result, for: keys, ttl: configuration.cacheTTL)
        return result
    }

    private func inspectExplicitContent(_ url: URL) async throws -> (fragment: MetadataFragment, finalURL: URL) {
        _ = try normalizer.validateRedirect(url)
        let payload = try await inspector.inspect(url: url, configuration: configuration)
        let finalURL = URL(string: payload.inspection.finalURL) ?? url
        guard payload.inspection.isHTML, let html = payload.text else {
            return (FileMetadataParser().parse(payload: payload, url: finalURL), finalURL)
        }
        let document = HTMLDocument(html: html, baseURL: finalURL, configuration: configuration)
        var fragment = HeadMetadataParser().parse(document)
        fragment.merge(StructuredDataParser().parse(document, canonicalCandidates: fragment.canonicalURLCandidates.map(\.value)))
        fragment.merge(SemanticDOMParser().parse(document))
        fragment.merge(EmbeddedStateParser().parse(document))
        fragment.merge(registry.extract(url: finalURL, document: document, genericFragment: fragment))
        return (fragment, finalURL)
    }

    private func firstExplicitContentURL(in fragment: MetadataFragment, excluding baseURL: URL) -> URL? {
        for value in fragment.explicitContentDocumentURLs.prefix(3) {
            guard let url = URL(string: value), url.absoluteString != baseURL.absoluteString else { continue }
            return url
        }
        return nil
    }

    private func shouldRender(fragment: MetadataFragment, inspection: HTTPInspection, url: URL) -> Bool {
        guard inspection.isHTML, !inspection.isLoginPage, !inspection.isBlockedPage, !inspection.isRemovedPage else { return false }
        let title = fragment.titleCandidates.max(by: { $0.confidence < $1.confidence })?.value.lowercased()
        let host = HTMLTools.domainDisplayName(url).lowercased()
        let domainOnlyTitle = title == nil || title == host || title == "www.\(host)"
        let knownClientRendered = ["instagram.com", "threads.net", "x.com", "tiktok.com", "notion.site", "figma.com"].contains { url.lowercasedHost.hasSuffix($0) }
        return fragment.requiresJavaScript
            || knownClientRendered
            || (domainOnlyTitle && !fragment.hasOpenGraph && !fragment.hasJSONLD)
            || (!fragment.hasOpenGraph && !fragment.hasJSONLD && fragment.visibleTextLength < 160)
    }

    private func attempt(_ stage: ExtractionStage, started: Date, succeeded: Bool, message: String? = nil, error: Error? = nil) -> ExtractionAttempt {
        ExtractionAttempt(
            stage: stage,
            startedAt: ISO8601DateFormatter.clipInbox.string(from: started),
            finishedAt: ISO8601DateFormatter.clipInbox.string(from: Date()),
            succeeded: succeeded,
            message: message ?? error?.localizedDescription,
            errorCode: error.map { String(describing: $0) }
        )
    }

    private func failureResult(rawURL: String, error: Error, stage: ExtractionStage) -> LinkMetadataResult {
        LinkMetadataResult(
            originalURL: rawURL,
            platform: "web",
            contentType: "webPage",
            status: .failed,
            extractionAttempts: [attempt(stage, started: Date(), succeeded: false, error: error)]
        )
    }

    private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw MetadataEngineError.requestTimedOut
            }
            guard let result = try await group.next() else { throw MetadataEngineError.cancelled }
            group.cancelAll()
            return result
        }
    }
}
