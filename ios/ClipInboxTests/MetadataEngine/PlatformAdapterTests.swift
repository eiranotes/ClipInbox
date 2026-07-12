import XCTest
@testable import ClipInbox

final class PlatformAdapterTests: XCTestCase {
    func testYouTubeUsesURLPatternAndEmbeddedPlayerStateWithoutAPI() async throws {
        let html = try fixture("youtube")
        let inspector = MockHTTPInspector(payloads: [htmlPayload(url: "https://www.youtube.com/watch?v=abc123", html: html)])
        let result = await makeEngine(inspector: inspector).analyze("https://youtu.be/abc123?si=tracking")

        XCTAssertEqual(result.platform, "YouTube")
        XCTAssertEqual(result.contentType, "video")
        XCTAssertEqual(result.title?.value, "OG 영상 제목")
        XCTAssertEqual(result.title?.source, .openGraph)
        XCTAssertEqual(result.creator?.value, "개발 채널")
        XCTAssertEqual(result.durationSeconds?.value, 754)
        XCTAssertEqual(result.attributes["videoID"]?.value, .string("abc123"))
        XCTAssertEqual(result.attributes["channelID"]?.value, .string("UC123"))
        XCTAssertEqual(result.attributes["videoGenre"]?.value, .string("개발"))
        XCTAssertNotNil(result.volatileAttributes["viewCount"])
        XCTAssertNil(result.attributes["viewCount"])
    }

    func testGitHubRepositoryExtractsAboutReadmeTopicsAndLanguageFromHTML() async throws {
        let html = try fixture("github-repository")
        let inspector = MockHTTPInspector(payloads: [htmlPayload(url: "https://github.com/eiranotes/ClipInbox", html: html)])
        let result = await makeEngine(inspector: inspector).analyze("https://github.com/eiranotes/ClipInbox")

        XCTAssertEqual(result.platform, "GitHub")
        XCTAssertEqual(result.contentSubtype, "repository")
        XCTAssertEqual(result.attributes["owner"]?.value, .string("eiranotes"))
        XCTAssertEqual(result.attributes["repository"]?.value, .string("ClipInbox"))
        XCTAssertEqual(result.attributes["primaryLanguage"]?.value, .string("Swift"))
        XCTAssertEqual(result.attributes["license"]?.value, .string("MIT"))
        XCTAssertEqual(result.attributes["defaultBranch"]?.value, .string("main"))
        XCTAssertNotNil(result.attributes["readmeExcerpt"])
        XCTAssertEqual(Set(result.originalTags.flatMap(\.value)), Set(["swift", "ios", "swiftui"]))
        XCTAssertTrue(result.summaryDetail?.value.contains("private-first iOS link inbox") == true)

        let card = PresentationBuilder().mainCard(from: result)
        XCTAssertEqual(card.contentTypeLabel, "GitHub 저장소")
        XCTAssertTrue(card.subtitle.contains("Swift"))
        let details = PresentationBuilder().detailSections(from: result).flatMap(\.items)
        XCTAssertTrue(details.contains(where: { $0.label == "기본 브랜치" && $0.value == "main" }))
    }

    func testRedditURLPatternAndPublicDOMProducePostFacts() async throws {
        let html = try fixture("reddit-post")
        let url = "https://www.reddit.com/r/swift/comments/abc123/metadata_fallbacks/"
        let inspector = MockHTTPInspector(payloads: [htmlPayload(url: url, html: html)])
        let result = await makeEngine(inspector: inspector).analyze(url)

        XCTAssertEqual(result.platform, "Reddit")
        XCTAssertEqual(result.contentType, "discussion")
        XCTAssertEqual(result.contentSubtype, "post")
        XCTAssertEqual(result.attributes["subreddit"]?.value, .string("swift"))
        XCTAssertEqual(result.attributes["subreddit"]?.source, .urlPattern)
        XCTAssertEqual(result.attributes["postID"]?.value, .string("abc123"))
        XCTAssertEqual(result.attributes["flair"]?.value, .string("Discussion"))
        XCTAssertEqual(result.attributes["isNSFW"]?.value, .bool(true))
        XCTAssertTrue(result.originalTags.flatMap(\.value).contains("Discussion"))
    }

    func testNaverWrapperFollowsOnlyExplicitContentIframeOneStep() async throws {
        let wrapper = try fixture("naver-wrapper")
        let content = try fixture("naver-content")
        let wrapperURL = "https://blog.naver.com/tester/123"
        let contentURL = "https://blog.naver.com/PostView.naver?blogId=tester&logNo=123"
        let inspector = MockHTTPInspector(payloads: [
            htmlPayload(url: wrapperURL, html: wrapper),
            htmlPayload(url: contentURL, html: content)
        ])
        let result = await makeEngine(inspector: inspector).analyze(wrapperURL)

        XCTAssertEqual(result.platform, "네이버 블로그")
        XCTAssertEqual(result.contentSubtype, "naverBlogPost")
        XCTAssertEqual(result.title?.value, "네이버 공개 본문 제목")
        XCTAssertEqual(result.creator?.value, "네이버 작성자")
        XCTAssertEqual(result.attributes["blogID"]?.value, .string("tester"))
        XCTAssertEqual(result.attributes["postID"]?.value, .string("123"))
        XCTAssertEqual(result.attributes["contentDocumentURL"]?.value, .string(contentURL))
        let requestCount = await inspector.requestCount
        XCTAssertEqual(requestCount, 2)
        XCTAssertTrue(result.extractionAttempts.contains(where: {
            $0.stage == .platformAdapter && $0.succeeded && $0.message?.contains("1단계") == true
        }))
    }

    func testRestrictedInstagramPageKeepsMinimumURLFactsAndLoginStatus() async throws {
        let html = try fixture("login")
        let url = "https://www.instagram.com/p/ABC123/"
        let inspector = MockHTTPInspector(payloads: [htmlPayload(url: url, html: html, login: true)])
        let result = await makeEngine(inspector: inspector).analyze(url)

        XCTAssertEqual(result.platform, "Instagram")
        XCTAssertEqual(result.contentType, "socialPost")
        XCTAssertEqual(result.contentSubtype, "post")
        XCTAssertEqual(result.attributes["shortcode"]?.value, .string("ABC123"))
        XCTAssertEqual(result.attributes["shortcode"]?.source, .urlPattern)
        XCTAssertEqual(result.status, .loginRequired)
        XCTAssertEqual(result.bestOpenURL, url)
    }

    func testAppStoreCombinesURLClassificationWithSoftwareApplicationJSONLD() async throws {
        let html = try fixture("app-store")
        let url = "https://apps.apple.com/us/app/clip-inbox-companion/id123456789"
        let inspector = MockHTTPInspector(payloads: [htmlPayload(url: url, html: html)])
        let result = await makeEngine(inspector: inspector).analyze(url)

        XCTAssertEqual(result.platform, "App Store")
        XCTAssertEqual(result.contentType.lowercased(), "softwareapplication")
        XCTAssertEqual(result.title?.value, "Clip Inbox Companion")
        XCTAssertEqual(result.creator?.value, "Inbox Labs")
        XCTAssertEqual(result.attributes["platform"]?.value, .string("Apple"))
        XCTAssertEqual(result.attributes["applicationCategory"]?.value, .string("ProductivityApplication"))
        XCTAssertEqual(result.attributes["operatingSystem"]?.value, .string("iOS 17.0 or later"))
        XCTAssertEqual(result.attributes["softwareVersion"]?.value, .string("2.1.0"))
        XCTAssertEqual(result.attributes["price"]?.value, .string("0"))
        XCTAssertEqual(result.attributes["currency"]?.value, .string("USD"))
    }

    func testProductJSONLDDoesNotParseArbitraryNumbersAsPrice() async throws {
        let html = try fixture("product")
        let inspector = MockHTTPInspector(payloads: [htmlPayload(url: "https://shop.example.com/products/clip-stand", html: html)])
        let result = await makeEngine(inspector: inspector).analyze("https://shop.example.com/products/clip-stand")

        XCTAssertEqual(result.contentType.lowercased(), "product")
        XCTAssertEqual(result.attributes["price"]?.value, .string("29000"))
        XCTAssertEqual(result.attributes["currency"]?.value, .string("KRW"))
        XCTAssertEqual(result.attributes["brand"]?.value, .string("Inbox Lab"))
        XCTAssertEqual(result.attributes["availability"]?.value, .string("InStock"))
    }

    func testScholarlyMetadataSupportsCitationMetaAndJSONLD() async throws {
        let html = try fixture("scholarly")
        let inspector = MockHTTPInspector(payloads: [htmlPayload(url: "https://papers.example.org/metadata", html: html)])
        let result = await makeEngine(inspector: inspector).analyze("https://papers.example.org/metadata")

        XCTAssertEqual(result.contentType.lowercased(), "scholarlyarticle")
        XCTAssertEqual(result.title?.source, .jsonLD)
        XCTAssertEqual(result.creator?.value, "Ada Kim")
        XCTAssertEqual(result.attributes["doi"]?.value, .string("10.1234/jwp.2025.42"))
        XCTAssertEqual(result.attributes["publication"]?.value, .string("Journal of Web Parsing"))
        XCTAssertNotNil(result.attributes["pdfURL"])
        XCTAssertTrue(result.summaryDetail?.value.contains("deterministic extraction pipeline") == true)
    }
}
