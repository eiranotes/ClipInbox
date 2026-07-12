import XCTest
@testable import ClipInbox

final class GenericPipelineTests: XCTestCase {
    func testArticlePipelineResolvesSourcesSummaryAndPresentation() async throws {
        let html = try fixture("article")
        let inspector = MockHTTPInspector(payloads: [htmlPayload(url: "https://example.com/articles/url-metadata", html: html)])
        let engine = makeEngine(inspector: inspector)

        let result = await engine.analyze("https://example.com/articles/url-metadata?utm_source=share#intro")

        XCTAssertEqual(result.status, .complete)
        XCTAssertEqual(result.title?.value, "URL 하나로 만드는 안전한 메타데이터 엔진")
        XCTAssertEqual(result.title?.source, .jsonLD)
        XCTAssertEqual(result.creator?.value, "김개발")
        XCTAssertEqual(result.creator?.source, .jsonLD)
        XCTAssertEqual(result.contentType.lowercased(), "article")
        XCTAssertEqual(result.canonicalURL, "https://example.com/articles/url-metadata")
        XCTAssertEqual(result.thumbnail?.value, "https://example.com/images/article-cover.jpg")
        XCTAssertEqual(result.thumbnail?.source, .openGraph)
        XCTAssertEqual(result.originalTags.flatMap(\.value).prefix(3), ["Swift", "iOS", "메타데이터"])
        XCTAssertNotNil(result.summaryShort)
        XCTAssertLessThanOrEqual(result.summaryShort?.value.count ?? 999, 61)
        XCTAssertLessThanOrEqual(result.summaryDetail?.value.count ?? 999, 241)
        XCTAssertEqual(result.attributes["section"]?.value, .string("개발"))
        XCTAssertEqual(result.attributes["wordCount"]?.value, .number(1100))

        let card = PresentationBuilder().mainCard(from: result)
        XCTAssertEqual(card.title, result.title?.value)
        XCTAssertTrue(card.subtitle.contains("김개발"))
        XCTAssertFalse(card.subtitle.contains(result.description?.value ?? "__missing__"))

        let sections = PresentationBuilder().detailSections(from: result)
        XCTAssertFalse(sections.isEmpty)
        XCTAssertTrue(sections.contains(where: { $0.id == "overview" }))
        XCTAssertFalse(sections.flatMap(\.items).contains(where: { $0.value == "정보 없음" }))
    }

    func testBrokenJSONLDScriptDoesNotDiscardValidScript() async throws {
        let html = try fixture("broken-jsonld")
        let inspector = MockHTTPInspector(payloads: [htmlPayload(url: "https://example.org/broken", html: html)])
        let result = await makeEngine(inspector: inspector).analyze("https://example.org/broken")
        XCTAssertEqual(result.title?.value, "정상 JSON-LD는 살아 있어야 한다")
        XCTAssertEqual(result.title?.source, .jsonLD)
        XCTAssertEqual(result.creator?.value, "테스터")
    }

    func testJapaneseAndHTMLEntitiesAreDecoded() async throws {
        let html = try fixture("entities-ja")
        let inspector = MockHTTPInspector(payloads: [htmlPayload(url: "https://jp.example.jp/post", html: html)])
        let result = await makeEngine(inspector: inspector).analyze("https://jp.example.jp/post")
        XCTAssertEqual(result.title?.value, "HTML&Emoji 📎 のテスト")
        XCTAssertEqual(result.title?.source, .openGraph)
        XCTAssertTrue(result.description?.value.contains("日本語") == true)
    }

    func testRedirectChainKeepsOriginalResolvedAndCanonicalURLsSeparate() async throws {
        let html = try fixture("article")
        let hop = RedirectHop(
            statusCode: 302,
            fromURL: "https://short.example/r/42",
            toURL: "https://example.com/articles/url-metadata"
        )
        let inspector = MockHTTPInspector(payloads: [
            htmlPayload(
                url: "https://example.com/articles/url-metadata",
                html: html,
                redirects: [hop]
            )
        ])
        let result = await makeEngine(inspector: inspector).analyze("https://short.example/r/42#shared")

        XCTAssertEqual(result.originalURL, "https://short.example/r/42#shared")
        XCTAssertEqual(result.normalizedURL, "https://short.example/r/42")
        XCTAssertEqual(result.resolvedURL, "https://example.com/articles/url-metadata")
        XCTAssertEqual(result.canonicalURL, "https://example.com/articles/url-metadata")
        XCTAssertEqual(result.http?.redirects, [hop])
    }

    func testAdapterFailureDoesNotDiscardGenericMetadata() async throws {
        let html = try fixture("article")
        let inspector = MockHTTPInspector(payloads: [htmlPayload(url: "https://example.com/articles/url-metadata", html: html)])
        let registry = PlatformRegistry(adapters: [AlwaysFailingAdapter()])
        let result = await makeEngine(inspector: inspector, registry: registry).analyze("https://example.com/articles/url-metadata")

        XCTAssertEqual(result.title?.value, "URL 하나로 만드는 안전한 메타데이터 엔진")
        XCTAssertEqual(result.title?.source, .jsonLD)
        XCTAssertEqual(result.status, .complete)
        XCTAssertTrue(result.extractionAttempts.contains(where: {
            $0.stage == .platformAdapter && !$0.succeeded && $0.message?.contains("generic fallback") == true
        }))
    }

    func testOpenGraphOnlyPageProducesCompleteGenericFallback() async throws {
        let html = try fixture("og-only")
        let inspector = MockHTTPInspector(payloads: [htmlPayload(url: "https://og.example.com/post/1", html: html)])
        let result = await makeEngine(inspector: inspector).analyze("https://og.example.com/post/1")

        XCTAssertEqual(result.title?.value, "OG 전용 문서")
        XCTAssertEqual(result.title?.source, .openGraph)
        XCTAssertEqual(result.description?.source, .openGraph)
        XCTAssertEqual(result.thumbnail?.value, "https://og.example.com/assets/og-cover.png")
        XCTAssertEqual(result.siteName?.value, "OG Lab")
        XCTAssertEqual(result.contentType.lowercased(), "article")
        XCTAssertEqual(result.status, .complete)
    }

    func testJSONLDOnlyPageProducesVideoFieldsWithoutHeadMetadata() async throws {
        let html = try fixture("jsonld-only")
        let inspector = MockHTTPInspector(payloads: [htmlPayload(url: "https://media.example.net/watch/42", html: html)])
        let result = await makeEngine(inspector: inspector).analyze("https://media.example.net/watch/42")

        XCTAssertEqual(result.title?.value, "JSON-LD only video")
        XCTAssertEqual(result.title?.source, .jsonLD)
        XCTAssertEqual(result.creator?.value, "Alex Parser")
        XCTAssertEqual(result.creator?.source, .jsonLD)
        XCTAssertEqual(result.contentType.lowercased(), "video")
        XCTAssertEqual(result.durationSeconds?.value, 545)
        XCTAssertEqual(result.thumbnail?.value, "https://media.example.net/thumb.jpg")
        XCTAssertEqual(result.publishedAt?.value, "2026-07-01T10:30:00.000Z")
    }

    func testMicrodataCanSupplyFieldsWhenOGAndJSONLDAreMissing() async throws {
        let html = try fixture("microdata-only")
        let inspector = MockHTTPInspector(payloads: [htmlPayload(url: "https://micro.example.kr/post/7", html: html)])
        let result = await makeEngine(inspector: inspector).analyze("https://micro.example.kr/post/7")

        XCTAssertEqual(result.title?.value, "Microdata 문서 제목")
        XCTAssertEqual(result.title?.source, .microdata)
        XCTAssertEqual(result.creator?.value, "마이크로 작성자")
        XCTAssertEqual(result.creator?.source, .microdata)
        XCTAssertEqual(result.description?.source, .microdata)
        XCTAssertEqual(result.thumbnail?.value, "https://micro.example.kr/micro-cover.jpg")
        XCTAssertEqual(result.thumbnail?.source, .microdata)
    }

    func testTwitterCardOnlyPageSuppliesFallbackFields() async throws {
        let html = try fixture("twitter-only")
        let inspector = MockHTTPInspector(payloads: [htmlPayload(url: "https://cards.example.com/item/9", html: html)])
        let result = await makeEngine(inspector: inspector).analyze("https://cards.example.com/item/9")

        XCTAssertEqual(result.title?.value, "Twitter Card only page")
        XCTAssertEqual(result.title?.source, .twitterCard)
        XCTAssertEqual(result.description?.source, .twitterCard)
        XCTAssertEqual(result.creator?.value, "card_author")
        XCTAssertEqual(result.creator?.source, .twitterCard)
        XCTAssertEqual(result.thumbnail?.value, "https://cards.example.com/twitter-card.jpg")
        XCTAssertEqual(result.thumbnail?.source, .twitterCard)
        XCTAssertEqual(result.attributes["twitterCard"]?.value, .string("summary_large_image"))
    }

    func testRDFaOnlyPageSuppliesFieldsWithProvenance() async throws {
        let html = try fixture("rdfa-only")
        let inspector = MockHTTPInspector(payloads: [htmlPayload(url: "https://rdfa.example.org/page", html: html)])
        let result = await makeEngine(inspector: inspector).analyze("https://rdfa.example.org/page")

        XCTAssertEqual(result.title?.value, "RDFa metadata title")
        XCTAssertEqual(result.title?.source, .rdfa)
        XCTAssertEqual(result.description?.source, .rdfa)
        XCTAssertEqual(result.creator?.value, "RDFa Author")
        XCTAssertEqual(result.creator?.source, .rdfa)
        XCTAssertEqual(result.thumbnail?.value, "https://rdfa.example.org/rdfa-cover.jpg")
        XCTAssertEqual(result.thumbnail?.source, .rdfa)
        XCTAssertEqual(result.publishedAt?.source, .rdfa)
    }

    func testCacheAvoidsSecondNetworkRequest() async throws {
        let html = try fixture("article")
        let inspector = MockHTTPInspector(payloads: [htmlPayload(url: "https://example.com/articles/url-metadata", html: html)])
        let cache = MemoryMetadataCache()
        let engine = makeEngine(inspector: inspector, cache: cache)

        _ = await engine.analyze("https://example.com/articles/url-metadata")
        let cached = await engine.analyze("https://example.com/articles/url-metadata")

        let count = await inspector.requestCount
        XCTAssertEqual(count, 1)
        XCTAssertTrue(cached.extractionAttempts.contains(where: { $0.stage == .cache && $0.message?.contains("적중") == true }))
    }
}


private enum AdapterFixtureError: Error {
    case expected
}

private struct AlwaysFailingAdapter: PlatformAdapter {
    let identifier = "always-failing-test-adapter"
    func matches(_ url: URL) -> Bool { true }
    func extract(_ context: PlatformAdapterContext) throws -> MetadataFragment {
        throw AdapterFixtureError.expected
    }
}
