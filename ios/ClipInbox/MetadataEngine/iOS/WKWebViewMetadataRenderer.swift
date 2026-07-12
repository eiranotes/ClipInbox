#if canImport(WebKit)
import Foundation
import WebKit

/// 서버 HTML에 유효한 정보가 거의 없을 때 같은 URL을 한 번만 렌더링한다.
/// nonPersistent 데이터 저장소를 사용하므로 Safari 쿠키나 로그인 세션을 가져오지 않는다.
@MainActor
final class WKWebViewMetadataRenderer: NSObject, MetadataRendering, @unchecked Sendable {
    func render(url: URL, configuration: MetadataConfiguration) async throws -> RenderedPage {
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.websiteDataStore = .nonPersistent()
        webConfiguration.defaultWebpagePreferences.allowsContentJavaScript = true
        webConfiguration.preferences.javaScriptCanOpenWindowsAutomatically = false
        webConfiguration.allowsInlineMediaPlayback = false

        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.customUserAgent = configuration.userAgent
        let waiter = NavigationWaiter()
        webView.navigationDelegate = waiter

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: configuration.renderTimeout)
        request.httpShouldHandleCookies = false
        request.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")
        try await waiter.load(request, in: webView, timeout: configuration.renderTimeout)

        let value = try await webView.callAsyncJavaScript(
            Self.extractionScript(maximumTextCharacters: configuration.maximumDOMTextCharacters),
            arguments: [:],
            in: nil,
            contentWorld: .page
        )
        guard let object = value as? [String: Any],
              let finalURL = object["finalURL"] as? String else {
            throw MetadataEngineError.renderingFailed
        }

        let rawMeta = object["meta"] as? [String: Any] ?? [:]
        let meta = rawMeta.reduce(into: [String: [String]]()) { output, item in
            if let values = item.value as? [String] {
                output[item.key] = values
            } else if let value = item.value as? String {
                output[item.key] = [value]
            }
        }

        return RenderedPage(
            finalURL: finalURL,
            title: object["title"] as? String,
            meta: meta,
            canonicalURL: object["canonicalURL"] as? String,
            jsonLDScripts: object["jsonLD"] as? [String] ?? [],
            heading: object["heading"] as? String,
            mainText: object["mainText"] as? String,
            creator: object["creator"] as? String,
            date: object["date"] as? String,
            imageURLs: object["images"] as? [String] ?? [],
            language: object["language"] as? String
        )
    }

    private static func extractionScript(maximumTextCharacters: Int) -> String {
        #"""
        const maxText = \#(maximumTextCharacters);
        const clean = value => (value || "").replace(/\\s+/g, " ").trim();
        const meta = {};
        document.querySelectorAll("meta").forEach(node => {
          const key = (node.getAttribute("property") || node.getAttribute("name") || node.getAttribute("itemprop") || "").toLowerCase();
          const value = node.getAttribute("content") || "";
          if (!key || !value) return;
          if (!meta[key]) meta[key] = [];
          if (meta[key].length < 10) meta[key].push(value);
        });
        const canonical = document.querySelector('link[rel~="canonical"]')?.href || null;
        const jsonLD = Array.from(document.querySelectorAll('script[type*="ld+json"]'))
          .map(node => node.textContent || "")
          .filter(value => value.length > 0 && value.length <= 524288)
          .slice(0, 20);
        const root = document.querySelector("article") || document.querySelector("main") || document.querySelector('[role="main"]') || document.body;
        const clone = root ? root.cloneNode(true) : null;
        if (clone) {
          clone.querySelectorAll("script,style,noscript,template,nav,header,footer,aside,form,[hidden],[aria-hidden=true]").forEach(node => node.remove());
        }
        const mainText = clean(clone?.innerText || "").slice(0, maxText);
        const heading = clean((root || document).querySelector("h1")?.innerText || "") || null;
        const creatorNode = (root || document).querySelector('[rel="author"], [class*="author" i], [class*="byline" i], [itemprop="author"]');
        const dateNode = (root || document).querySelector('time[datetime], [itemprop="datePublished"], [class*="publish" i], [class*="date" i]');
        const images = Array.from((root || document).querySelectorAll("img"))
          .map(node => node.currentSrc || node.src || node.getAttribute("data-src") || "")
          .filter(value => /^https?:/i.test(value))
          .filter((value, index, values) => values.indexOf(value) === index)
          .slice(0, 5);
        return {
          finalURL: document.location.href,
          title: clean(document.title) || null,
          meta,
          canonicalURL: canonical,
          jsonLD,
          heading,
          mainText: mainText || null,
          creator: clean(creatorNode?.textContent || "") || null,
          date: dateNode?.getAttribute("datetime") || clean(dateNode?.textContent || "") || null,
          images,
          language: document.documentElement.lang || null
        };
        """#
    }
}

@MainActor
private final class NavigationWaiter: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?
    private weak var webView: WKWebView?
    private var timeoutTask: Task<Void, Never>?

    func load(_ request: URLRequest, in webView: WKWebView, timeout: TimeInterval) async throws {
        self.webView = webView
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            webView.load(request)
            timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard let self, self.continuation != nil else { return }
                self.webView?.stopLoading()
                self.finish(.failure(MetadataEngineError.requestTimedOut))
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finish(.success(()))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard navigationAction.targetFrame?.isMainFrame == true,
              let url = navigationAction.request.url,
              let scheme = url.scheme?.lowercased() else {
            decisionHandler(.allow)
            return
        }
        decisionHandler((scheme == "http" || scheme == "https") ? .allow : .cancel)
    }

    private func finish(_ result: Result<Void, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation.resume(with: result)
    }
}
#endif
