import XCTest
@testable import ClipInbox

final class RenderingFileAndStatusTests: XCTestCase {
    func testClientRenderedPageUsesRendererOnlyOnce() async throws {
        let html = try fixture("client-rendered")
        let inspector = MockHTTPInspector(payloads: [htmlPayload(url: "https://example.app/item/42", html: html)])
        let renderer = MockRenderer(page: RenderedPage(
            finalURL: "https://example.app/item/42",
            title: "렌더된 페이지 제목",
            meta: ["og:description": ["렌더링 후 DOM에서 확인한 공개 설명입니다. 서버 HTML에는 없었지만 같은 URL의 화면에 포함돼 있습니다."]],
            canonicalURL: "https://example.app/item/42",
            heading: "렌더된 페이지 제목",
            mainText: "렌더링된 본문 첫 문단입니다. 메타데이터가 부족할 때에만 WKWebView 분석을 한 번 수행합니다.",
            creator: "렌더 작성자",
            imageURLs: ["https://example.app/cover.jpg"],
            language: "ko"
        ))
        let result = await makeEngine(inspector: inspector, renderer: renderer).analyze("https://example.app/item/42")

        XCTAssertEqual(result.title?.value, "렌더된 페이지 제목")
        XCTAssertEqual(result.creator?.value, "렌더 작성자")
        XCTAssertEqual(result.thumbnail?.value, "https://example.app/cover.jpg")
        XCTAssertEqual(renderer.calls, 1)
        XCTAssertTrue(result.extractionAttempts.contains(where: { $0.stage == .renderedDOM && $0.succeeded }))
    }

    func testDirectPDFBuildsFileMetadataWithoutDownloadingImages() async {
        var pdf = Data("%PDF-1.7\n1 0 obj << /Type /Pages /Count 12 >> endobj\n%%EOF".utf8)
        pdf.append(Data(repeating: 0, count: 32))
        let payload = binaryPayload(url: "https://files.example.com/report.pdf", data: pdf, mime: "application/pdf", filename: "2026_report.pdf")
        let inspector = MockHTTPInspector(payloads: [payload])
        let result = await makeEngine(inspector: inspector).analyze("https://files.example.com/report.pdf")

        XCTAssertEqual(result.contentType, "document")
        XCTAssertEqual(result.contentSubtype, "pdf")
        XCTAssertEqual(result.title?.value, "2026 report")
        XCTAssertEqual(result.attributes["fileName"]?.value, .string("2026_report.pdf"))
        XCTAssertEqual(result.attributes["pageCount"]?.value, .number(12))
        XCTAssertEqual(result.status, .complete)
    }

    func testDirectPNGExtractsDimensionsAndUsesURLAsThumbnailWithoutExtraFetch() async {
        var bytes = [UInt8](repeating: 0, count: 32)
        bytes[0...7] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        bytes[16...19] = [0x00, 0x00, 0x04, 0x00]
        bytes[20...23] = [0x00, 0x00, 0x03, 0x00]
        let url = "https://files.example.com/cover-image.png"
        let inspector = MockHTTPInspector(payloads: [binaryPayload(url: url, data: Data(bytes), mime: "image/png")])
        let result = await makeEngine(inspector: inspector).analyze(url)

        XCTAssertEqual(result.contentType, "image")
        XCTAssertEqual(result.thumbnail?.value, url)
        XCTAssertEqual(result.thumbnail?.source, .httpHeader)
        XCTAssertEqual(result.attributes["imageWidth"]?.value, .number(1024))
        XCTAssertEqual(result.attributes["imageHeight"]?.value, .number(768))
        let requestCount = await inspector.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testDirectTextFileBuildsExcerptSummaryAndReadingTime() async {
        let text = """
        Clip Inbox metadata fixture

        This public text document contains enough material to produce a deterministic excerpt and summary without HTML parsing or an external language model. The engine should keep the source text bounded and classify the resource as a text document.
        """
        let data = Data(text.utf8)
        let url = "https://files.example.com/metadata-notes.txt"
        let inspector = MockHTTPInspector(payloads: [binaryPayload(url: url, data: data, mime: "text/plain", filename: "metadata-notes.txt")])
        let result = await makeEngine(inspector: inspector).analyze(url)

        XCTAssertEqual(result.contentType, "document")
        XCTAssertEqual(result.contentSubtype, "text")
        XCTAssertEqual(result.title?.value, "metadata notes")
        XCTAssertEqual(result.description?.source, .httpHeader)
        XCTAssertNotNil(result.summaryDetail)
        XCTAssertNotNil(result.readingMinutes)
        XCTAssertLessThanOrEqual(result.summaryDetail?.value.count ?? 999, 240)
    }

    func testLoginRemovedAndBlockedStatusesTakePriority() async throws {
        let loginHTML = try fixture("login")
        let removedHTML = try fixture("removed")
        let blockedHTML = "<html><head><title>Access denied</title></head><body>Verify you are human. Request blocked.</body></html>"
        let inspector = MockHTTPInspector(payloads: [
            htmlPayload(url: "https://social.example.com/p/1", html: loginHTML, login: true),
            htmlPayload(url: "https://example.com/deleted", html: removedHTML, statusCode: 404, removed: true),
            htmlPayload(url: "https://example.com/blocked", html: blockedHTML, statusCode: 403, blocked: true)
        ])
        let engine = makeEngine(inspector: inspector)

        let loginResult = await engine.analyze("https://social.example.com/p/1", forceRefresh: true)
        let removedResult = await engine.analyze("https://example.com/deleted", forceRefresh: true)
        let blockedResult = await engine.analyze("https://example.com/blocked", forceRefresh: true)
        XCTAssertEqual(loginResult.status, .loginRequired)
        XCTAssertEqual(removedResult.status, .removed)
        XCTAssertEqual(blockedResult.status, .blocked)
    }

    func testNetworkFailureStillReturnsURLPatternFallback() async {
        let inspector = MockHTTPInspector(results: [.failure(URLError(.notConnectedToInternet))])
        let result = await makeEngine(inspector: inspector).analyze("https://youtu.be/abc123")
        XCTAssertEqual(result.platform, "YouTube")
        XCTAssertEqual(result.attributes["videoID"]?.value, .string("abc123"))
        XCTAssertEqual(result.status, .partial)
        XCTAssertEqual(result.originalURL, "https://youtu.be/abc123")
    }
}
