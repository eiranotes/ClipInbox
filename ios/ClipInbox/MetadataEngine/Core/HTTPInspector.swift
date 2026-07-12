import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct HTTPPayload: Sendable {
    var inspection: HTTPInspection
    var data: Data
    var text: String?
    var headers: [String: String]
}

protocol HTTPInspecting: Sendable {
    func inspect(url: URL, configuration: MetadataConfiguration) async throws -> HTTPPayload
}

final class URLSessionHTTPInspector: HTTPInspecting, @unchecked Sendable {
    private let normalizer: URLNormalizer

    init(normalizer: URLNormalizer = URLNormalizer()) {
        self.normalizer = normalizer
    }

    func inspect(url: URL, configuration: MetadataConfiguration) async throws -> HTTPPayload {
        var lastError: Error?
        for attempt in 0...configuration.automaticRetryCount {
            do {
                let loader = LimitedURLSessionLoader(
                    maximumBytes: configuration.maximumHTMLBytes,
                    maximumRedirects: configuration.maximumRedirects,
                    normalizer: normalizer
                )
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: configuration.requestTimeout)
                request.httpMethod = "GET"
                request.httpShouldHandleCookies = false
                request.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")
                request.setValue("text/html,application/xhtml+xml,application/pdf,image/*,text/plain;q=0.9,*/*;q=0.5", forHTTPHeaderField: "Accept")
                request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                let loaded = try await loader.load(request)
                return makePayload(from: loaded)
            } catch {
                lastError = error
                if attempt >= configuration.automaticRetryCount || !isTransient(error) { throw error }
            }
        }
        throw lastError ?? MetadataEngineError.invalidResponse
    }

    private func makePayload(from loaded: LimitedURLSessionLoader.Result) -> HTTPPayload {
        let response = loaded.response
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            result[String(describing: pair.key).lowercased()] = String(describing: pair.value)
        }
        let contentTypeHeader = headers["content-type"]
        let parsedContentType = parseContentType(contentTypeHeader)
        let text = decodeText(loaded.data, charset: parsedContentType.charset)
        let sniffedHTML = text.map { value in
            let prefix = value.prefix(1_024).lowercased()
            return prefix.contains("<!doctype html") || prefix.contains("<html") || prefix.contains("<head")
        } ?? false
        let isHTML = parsedContentType.mimeType.map { mime in
            mime.contains("text/html") || mime.contains("application/xhtml")
        } ?? sniffedHTML

        let statusFlags = classifyStatus(statusCode: response.statusCode, text: text)
        let finalURL = response.url?.absoluteString ?? loaded.originalURL.absoluteString
        let inspection = HTTPInspection(
            statusCode: response.statusCode,
            finalURL: finalURL,
            contentType: parsedContentType.mimeType,
            contentLength: contentLength(headers: headers, response: response),
            contentDisposition: headers["content-disposition"],
            charset: parsedContentType.charset,
            language: headers["content-language"].flatMap(HTMLTools.normalizedLanguage),
            downloadFilename: downloadFilename(from: headers["content-disposition"], fallbackURL: response.url),
            redirects: loaded.redirects,
            isHTML: isHTML,
            isLoginPage: statusFlags.login,
            isBlockedPage: statusFlags.blocked,
            isRemovedPage: statusFlags.removed,
            responseBytes: loaded.data.count
        )
        return HTTPPayload(inspection: inspection, data: loaded.data, text: isHTML || parsedContentType.mimeType?.hasPrefix("text/") == true ? text : nil, headers: headers)
    }

    private func parseContentType(_ rawValue: String?) -> (mimeType: String?, charset: String?) {
        guard let rawValue else { return (nil, nil) }
        let parts = rawValue.split(separator: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let mime = parts.first?.lowercased()
        let charset = parts.dropFirst().first(where: { $0.lowercased().hasPrefix("charset=") })?
            .split(separator: "=", maxSplits: 1).last?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            .lowercased()
        return (mime, charset)
    }

    private func decodeText(_ data: Data, charset: String?) -> String? {
        let encodings: [String.Encoding] = {
            var values: [String.Encoding] = []
            if let charset {
                switch charset.lowercased() {
                case "utf-8", "utf8": values.append(.utf8)
                case "iso-8859-1", "latin1": values.append(.isoLatin1)
                case "windows-1252", "cp1252": values.append(.windowsCP1252)
                case "shift_jis", "shift-jis", "sjis": values.append(.shiftJIS)
                case "utf-16", "utf16": values.append(.utf16)
                default: break
                }
            }
            values += [.utf8, .isoLatin1, .windowsCP1252]
            return values
        }()
        for encoding in encodings {
            if let text = String(data: data, encoding: encoding) { return text }
        }
        return nil
    }

    private func contentLength(headers: [String: String], response: HTTPURLResponse) -> Int64? {
        if let value = headers["content-length"], let length = Int64(value) { return length }
        return response.expectedContentLength >= 0 ? response.expectedContentLength : nil
    }

    private func downloadFilename(from contentDisposition: String?, fallbackURL: URL?) -> String? {
        if let contentDisposition {
            if let match = HTMLTools.firstMatch(#"filename\*\s*=\s*UTF-8''([^;]+)"#, in: contentDisposition, options: [.caseInsensitive]), match.count > 1 {
                return match[1].removingPercentEncoding ?? match[1]
            }
            if let match = HTMLTools.firstMatch(#"filename\s*=\s*(?:\"([^\"]+)\"|'([^']+)'|([^;]+))"#, in: contentDisposition, options: [.caseInsensitive]), match.count > 1 {
                let value = match.dropFirst().first(where: { !$0.isEmpty })?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let value, !value.isEmpty { return value }
            }
        }
        return fallbackURL?.lastPathComponent.nilIfEmpty
    }

    private func classifyStatus(statusCode: Int, text: String?) -> (login: Bool, blocked: Bool, removed: Bool) {
        let lower = String((text ?? "").prefix(24_000)).lowercased()
        let loginMarkers = [
            "login required", "sign in to continue", "log in to continue", "please sign in", "로그인이 필요", "로그인하여 계속", "로그인 후 이용"
        ]
        let blockedMarkers = [
            "access denied", "request blocked", "temporarily blocked", "unusual traffic", "verify you are human", "captcha", "cloudflare ray id", "봇이 아님을", "접근이 차단"
        ]
        let removedMarkers = [
            "page not found", "content is unavailable", "this page isn't available", "post has been removed", "페이지를 찾을 수 없", "게시물이 삭제", "존재하지 않는 페이지"
        ]
        let login = statusCode == 401 || loginMarkers.contains(where: lower.contains)
        let blocked = statusCode == 403 || statusCode == 429 || blockedMarkers.contains(where: lower.contains)
        let removed = statusCode == 404 || statusCode == 410 || removedMarkers.contains(where: lower.contains)
        return (login, blocked, removed)
    }

    private func isTransient(_ error: Error) -> Bool {
        if let error = error as? URLError {
            return [.timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost, .dnsLookupFailed].contains(error.code)
        }
        return (error as? MetadataEngineError) == .requestTimedOut
    }
}

private final class LimitedURLSessionLoader: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    struct Result: @unchecked Sendable {
        var originalURL: URL
        var response: HTTPURLResponse
        var data: Data
        var redirects: [RedirectHop]
    }

    private let maximumBytes: Int
    private let maximumRedirects: Int
    private let normalizer: URLNormalizer
    private var continuation: CheckedContinuation<Result, Error>?
    private var response: HTTPURLResponse?
    private var data = Data()
    private var redirects: [RedirectHop] = []
    private var visitedRedirectURLs: Set<String> = []
    private var originalURL: URL?
    private var finished = false
    private let lock = NSLock()
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
#if !os(Linux)
        configuration.waitsForConnectivity = false
#endif
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
    }()

    init(maximumBytes: Int, maximumRedirects: Int, normalizer: URLNormalizer) {
        self.maximumBytes = maximumBytes
        self.maximumRedirects = maximumRedirects
        self.normalizer = normalizer
        super.init()
    }

    func load(_ request: URLRequest) async throws -> Result {
        guard let url = request.url else { throw MetadataEngineError.invalidURL }
        originalURL = url
        visitedRedirectURLs = [redirectKey(url)]
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            session.dataTask(with: request).resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            finish(.failure(MetadataEngineError.invalidResponse))
            return
        }
        self.response = http
        if http.expectedContentLength > Int64(maximumBytes) {
            completionHandler(.cancel)
            finish(.failure(MetadataEngineError.responseTooLarge))
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive newData: Data) {
        guard !finished else { return }
        if data.count + newData.count > maximumBytes {
            dataTask.cancel()
            finish(.failure(MetadataEngineError.responseTooLarge))
            return
        }
        data.append(newData)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let from = task.currentRequest?.url ?? response.url, let to = request.url else {
            completionHandler(nil)
            finish(.failure(MetadataEngineError.invalidResponse))
            return
        }
        do {
            _ = try normalizer.validateRedirect(to)
            let key = redirectKey(to)
            guard visitedRedirectURLs.insert(key).inserted else {
                completionHandler(nil)
                finish(.failure(MetadataEngineError.redirectLoop))
                return
            }
            guard redirects.count < maximumRedirects else {
                completionHandler(nil)
                finish(.failure(MetadataEngineError.redirectLimitExceeded))
                return
            }
            redirects.append(.init(statusCode: response.statusCode, fromURL: from.absoluteString, toURL: to.absoluteString))
            var safeRequest = request
            safeRequest.httpShouldHandleCookies = false
            completionHandler(safeRequest)
        } catch {
            completionHandler(nil)
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if finished { return }
        if let error {
            if let urlError = error as? URLError, urlError.code == .timedOut {
                finish(.failure(MetadataEngineError.requestTimedOut))
            } else if let urlError = error as? URLError, urlError.code == .cancelled, finished {
                return
            } else {
                finish(.failure(error))
            }
            return
        }
        guard let originalURL, let response else {
            finish(.failure(MetadataEngineError.invalidResponse))
            return
        }
        finish(.success(.init(originalURL: originalURL, response: response, data: data, redirects: redirects)))
    }

    private func redirectKey(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        return components?.string?.lowercased() ?? url.absoluteString.lowercased()
    }

    private func finish(_ result: Swift.Result<LimitedURLSessionLoader.Result, Error>) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        session.finishTasksAndInvalidate()
        continuation?.resume(with: result)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
