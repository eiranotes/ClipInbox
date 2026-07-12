import XCTest
@testable import ClipInbox

final class URLNormalizerTests: XCTestCase {
    func testRemovesTrackingSortsQueryAndPreservesOriginalFragment() throws {
        let result = try URLNormalizer().normalize("HTTPS://M.YOUTUBE.COM/watch?utm_source=test&v=abc&b=2&a=1#chapter")
        XCTAssertEqual(result.normalizedURL.absoluteString, "https://www.youtube.com/watch?a=1&b=2&v=abc")
        XCTAssertEqual(result.originalFragment, "chapter")
        XCTAssertEqual(result.removedTrackingParameters, ["utm_source"])
    }

    func testRejectsUnsafeAndNonHTTPURLs() {
        XCTAssertThrowsError(try URLNormalizer().normalize("file:///tmp/test"))
        XCTAssertThrowsError(try URLNormalizer().normalize("javascript:alert(1)"))
        XCTAssertThrowsError(try URLNormalizer().normalize("http://127.0.0.1/private"))
        XCTAssertThrowsError(try URLNormalizer().normalize("https://user:password@example.com/path"))
    }

    func testRedactsCredentialsAndQueryValuesForLogs() {
        let redacted = URLNormalizer().redactedForLogging("https://user:secret@example.com/path?token=abc&email=a@b.com")
        XCTAssertFalse(redacted.contains("secret"))
        XCTAssertFalse(redacted.contains("abc"))
        XCTAssertTrue(redacted.contains("token=%3Credacted%3E") || redacted.contains("token=<redacted>"))
    }
}
