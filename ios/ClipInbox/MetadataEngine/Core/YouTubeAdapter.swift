import Foundation

struct YouTubeAdapter: PlatformAdapter {
    let identifier = "youtube"

    func matches(_ url: URL) -> Bool {
        let host = url.lowercasedHost
        return host == "youtu.be" || host == "youtube.com" || host.hasSuffix(".youtube.com")
    }

    func extract(_ context: PlatformAdapterContext) -> MetadataFragment {
        var fragment = MetadataFragment()
        fragment.platformCandidates.append(.init(value: "YouTube", confidence: 1.0, source: .urlPattern))

        let facts = classify(context.url)
        fragment.contentTypeCandidates.append(.init(value: facts.contentType, confidence: 0.96, source: .urlPattern))
        fragment.contentSubtypeCandidates.append(.init(value: facts.subtype, confidence: 0.96, source: .urlPattern))
        if let videoID = facts.videoID {
            fragment.addAttribute("videoID", value: .string(videoID), source: .urlPattern, confidence: 1.0)
        }
        if let playlistID = facts.playlistID {
            fragment.addAttribute("playlistID", value: .string(playlistID), source: .urlPattern, confidence: 1.0)
        }
        if let channelIdentifier = facts.channelIdentifier {
            fragment.addAttribute("channelIdentifier", value: .string(channelIdentifier), source: .urlPattern, confidence: 0.98)
        }
        fragment.addAttribute("isShorts", value: .bool(facts.isShorts), source: .urlPattern, confidence: 1.0)
        fragment.addAttribute("isLiveURL", value: .bool(facts.isLive), source: .urlPattern, confidence: 0.92)

        guard let document = context.document else { return fragment }
        let parser = EmbeddedStateParser()
        let payloads = parser.balancedJSONAssignments(named: "ytInitialPlayerResponse", in: document.html)
            + parser.balancedJSONAssignments(named: "playerResponse", in: document.html)

        for payload in payloads.prefix(3) {
            guard payload.utf8.count <= document.configuration.maximumEmbeddedStateBytes,
                  let data = payload.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            extractPlayerResponse(root, baseURL: context.url, fragment: &fragment)
        }

        let text = [
            fragment.titleCandidates.first?.value,
            fragment.descriptionCandidates.first?.value,
            fragment.originalTagCandidates.first?.value.joined(separator: " ")
        ].compactMap { $0 }.joined(separator: " ")
        if !text.isEmpty {
            let genre = classifyGenre(text)
            fragment.derivedTopicCandidates.append(.init(value: [genre], source: .derived, confidence: genre == "기타 영상" ? 0.45 : 0.72, rawValue: .string(text)))
            fragment.addAttribute("videoGenre", value: .string(genre), source: .derived, confidence: genre == "기타 영상" ? 0.45 : 0.72)
        }
        return fragment
    }

    private func classify(_ url: URL) -> Facts {
        let host = url.lowercasedHost
        let components = url.decodedPathComponents
        let query = url.queryDictionary
        var facts = Facts(contentType: "video", subtype: "video")

        if host == "youtu.be" {
            facts.videoID = components.first
        } else if components.first == "watch" || url.path == "/watch" {
            facts.videoID = query["v"]
        } else if components.first == "shorts" {
            facts.videoID = components.dropFirst().first
            facts.isShorts = true
            facts.subtype = "shorts"
        } else if components.first == "live" {
            facts.videoID = components.dropFirst().first
            facts.isLive = true
            facts.subtype = "live"
        } else if components.first == "embed" {
            facts.videoID = components.dropFirst().first
            facts.subtype = "embeddedVideo"
        } else if components.first == "playlist" || query["list"] != nil {
            facts.contentType = "collection"
            facts.subtype = "playlist"
        } else if let first = components.first, first == "channel" || first == "c" || first == "user" || first.hasPrefix("@") {
            facts.contentType = "profile"
            facts.subtype = "channel"
            facts.channelIdentifier = first.hasPrefix("@") ? first : components.dropFirst().first
        }
        facts.playlistID = query["list"]
        return facts
    }

    private func extractPlayerResponse(_ root: [String: Any], baseURL: URL, fragment: inout MetadataFragment) {
        if let details = root["videoDetails"] as? [String: Any] {
            appendString(details["title"], to: &fragment.titleCandidates, confidence: 0.98)
            appendString(details["shortDescription"], to: &fragment.descriptionCandidates, confidence: 0.94)
            appendString(details["author"], to: &fragment.creatorCandidates, confidence: 0.97)
            if let channelID = scalar(details["channelId"]) {
                fragment.addAttribute("channelID", value: .string(channelID), source: .embeddedState, confidence: 0.98)
            }
            if let seconds = Int(scalar(details["lengthSeconds"]) ?? ""), seconds >= 0 {
                fragment.durationCandidates.append(.init(value: seconds, source: .embeddedState, confidence: 0.98, rawValue: JSONValue(details["lengthSeconds"])))
            }
            if let live = details["isLiveContent"] as? Bool {
                fragment.addAttribute("isLive", value: .bool(live), source: .embeddedState, confidence: 0.98)
            }
            let keywords = (details["keywords"] as? [Any])?.compactMap(scalar) ?? []
            if !keywords.isEmpty {
                fragment.originalTagCandidates.append(.init(value: keywords, source: .embeddedState, confidence: 0.92, rawValue: JSONValue(details["keywords"])))
            }
            if let viewCount = Double(scalar(details["viewCount"]) ?? "") {
                fragment.addAttribute("viewCount", value: .number(viewCount), source: .embeddedState, confidence: 0.88, volatile: true)
            }
            if let thumbnail = details["thumbnail"] as? [String: Any] {
                appendThumbnails(thumbnail["thumbnails"], baseURL: baseURL, fragment: &fragment)
            }
        }

        if let microformat = root["microformat"] as? [String: Any],
           let renderer = microformat["playerMicroformatRenderer"] as? [String: Any] {
            appendDate(renderer["publishDate"], to: &fragment.publishedAtCandidates, confidence: 0.94)
            appendDate(renderer["uploadDate"], to: &fragment.publishedAtCandidates, confidence: 0.92)
            appendString(renderer["ownerChannelName"], to: &fragment.creatorCandidates, confidence: 0.94)
            if let category = scalar(renderer["category"]) {
                fragment.originalTagCandidates.append(.init(value: [category], source: .embeddedState, confidence: 0.82))
            }
            if let live = renderer["liveBroadcastDetails"] as? [String: Any] {
                fragment.addAttribute("isLive", value: .bool(true), source: .embeddedState, confidence: 0.98)
                appendDate(live["startTimestamp"], to: &fragment.publishedAtCandidates, confidence: 0.84)
            }
            if let thumbnail = renderer["thumbnail"] as? [String: Any] {
                appendThumbnails(thumbnail["thumbnails"], baseURL: baseURL, fragment: &fragment)
            }
        }
    }

    private func appendThumbnails(_ value: Any?, baseURL: URL, fragment: inout MetadataFragment) {
        guard let values = value as? [Any] else { return }
        let sorted = values.compactMap { item -> (url: String, area: Int)? in
            guard let item = item as? [String: Any],
                  let raw = scalar(item["url"]),
                  let url = HTMLTools.resolveURL(raw, relativeTo: baseURL) else { return nil }
            let width = Int(scalar(item["width"]) ?? "") ?? 0
            let height = Int(scalar(item["height"]) ?? "") ?? 0
            return (url, width * height)
        }.sorted { $0.area > $1.area }
        for item in sorted.prefix(5) {
            fragment.imageCandidates.append(.init(value: item.url, source: .embeddedState, confidence: 0.93))
        }
    }

    private func appendString(_ value: Any?, to fields: inout [ExtractedField<String>], confidence: Double) {
        guard let raw = scalar(value) else { return }
        let clean = HTMLTools.cleanText(raw)
        guard !clean.isEmpty else { return }
        fields.append(.init(value: clean, source: .embeddedState, confidence: confidence, rawValue: JSONValue(value)))
    }

    private func appendDate(_ value: Any?, to fields: inout [ExtractedField<String>], confidence: Double) {
        guard let raw = scalar(value), let date = HTMLTools.normalizedDate(raw) else { return }
        fields.append(.init(value: date, source: .embeddedState, confidence: confidence, rawValue: JSONValue(value)))
    }

    private func scalar(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        if let value = value as? [String: Any] {
            if let simple = value["simpleText"] as? String { return simple }
            if let runs = value["runs"] as? [[String: Any]] {
                return runs.compactMap { $0["text"] as? String }.joined()
            }
        }
        return nil
    }

    private func classifyGenre(_ rawText: String) -> String {
        let text = rawText.lowercased()
        let rules: [(String, [String])] = [
            ("튜토리얼", ["tutorial", "how to", "사용법", "하는 법", "가이드", "따라하기"]),
            ("리뷰", ["review", "리뷰", "후기", "unboxing", "언박싱"]),
            ("뉴스", ["news", "뉴스", "속보", "브리핑", "update"]),
            ("브이로그", ["vlog", "브이로그", "일상"]),
            ("게임", ["gameplay", "gaming", "게임", "플레이"]),
            ("음악", ["music", "official audio", "뮤직비디오", "노래", "concert", "live performance"]),
            ("개발", ["coding", "programming", "developer", "swift", "python", "javascript", "개발", "코딩"]),
            ("인터뷰", ["interview", "인터뷰", "대담", "conversation"]),
            ("강의", ["lecture", "course", "lesson", "강의", "수업", "세미나"])
        ]
        return rules.first(where: { rule in rule.1.contains(where: text.contains) })?.0 ?? "기타 영상"
    }

    private struct Facts {
        var contentType: String
        var subtype: String
        var videoID: String?
        var playlistID: String?
        var channelIdentifier: String?
        var isShorts = false
        var isLive = false
    }
}
