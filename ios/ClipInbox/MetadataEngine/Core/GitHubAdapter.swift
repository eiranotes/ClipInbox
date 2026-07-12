import Foundation

struct GitHubAdapter: PlatformAdapter {
    let identifier = "github"

    func matches(_ url: URL) -> Bool {
        let host = url.lowercasedHost
        return host == "github.com" || host == "www.github.com" || host == "gist.github.com"
    }

    func extract(_ context: PlatformAdapterContext) -> MetadataFragment {
        var fragment = MetadataFragment()
        fragment.platformCandidates.append(.init(value: "GitHub", confidence: 1.0, source: .urlPattern))

        let facts = classify(context.url)
        fragment.contentTypeCandidates.append(.init(value: facts.contentType, confidence: 0.96, source: .urlPattern))
        fragment.contentSubtypeCandidates.append(.init(value: facts.subtype, confidence: 0.98, source: .urlPattern))
        if let owner = facts.owner {
            fragment.addAttribute("owner", value: .string(owner), source: .urlPattern, confidence: 1.0)
        }
        if let repository = facts.repository {
            fragment.addAttribute("repository", value: .string(repository), source: .urlPattern, confidence: 1.0)
            fragment.addAttribute("repositoryFullName", value: .string("\(facts.owner ?? "")/\(repository)"), source: .urlPattern, confidence: 1.0)
        }
        if let number = facts.number {
            fragment.addAttribute("number", value: .number(Double(number)), source: .urlPattern, confidence: 1.0)
        }
        if let identifier = facts.itemIdentifier {
            fragment.addAttribute("itemIdentifier", value: .string(identifier), source: .urlPattern, confidence: 1.0)
        }

        switch facts.subtype {
        case "repository":
            if let owner = facts.owner, let repository = facts.repository {
                fragment.titleCandidates.append(.init(value: "\(owner) / \(repository)", source: .urlPattern, confidence: 0.78))
            }
        case "issue", "pullRequest", "discussion":
            fragment.contentTypeCandidates.append(.init(value: "discussion", confidence: 0.90, source: .urlPattern))
        case "profile", "organization":
            fragment.contentTypeCandidates.append(.init(value: "profile", confidence: 0.95, source: .urlPattern))
        default:
            break
        }

        guard let document = context.document else { return fragment }
        parseRepositoryMetadata(document, facts: facts, fragment: &fragment)
        parseIssueLikeMetadata(document, facts: facts, fragment: &fragment)
        return fragment
    }

    private func classify(_ url: URL) -> Facts {
        let parts = url.decodedPathComponents
        if url.lowercasedHost == "gist.github.com" {
            return Facts(
                contentType: "code",
                subtype: "gist",
                owner: parts.first,
                repository: nil,
                number: nil,
                itemIdentifier: parts.dropFirst().first
            )
        }
        guard let owner = parts.first else {
            return Facts(contentType: "webPage", subtype: "githubHome")
        }
        guard parts.count >= 2 else {
            return Facts(contentType: "profile", subtype: owner == "orgs" ? "organization" : "profile", owner: owner)
        }
        let repository = parts[1]
        guard parts.count >= 3 else {
            return Facts(contentType: "softwareSourceCode", subtype: "repository", owner: owner, repository: repository)
        }
        let action = parts[2].lowercased()
        switch action {
        case "issues":
            return Facts(contentType: "discussion", subtype: "issue", owner: owner, repository: repository, number: parts.count > 3 ? Int(parts[3]) : nil)
        case "pull":
            return Facts(contentType: "discussion", subtype: "pullRequest", owner: owner, repository: repository, number: parts.count > 3 ? Int(parts[3]) : nil)
        case "releases":
            let tag = parts.count > 4 && parts[3] == "tag" ? parts[4] : nil
            return Facts(contentType: "softwareRelease", subtype: "release", owner: owner, repository: repository, itemIdentifier: tag)
        case "commit", "commits":
            return Facts(contentType: "code", subtype: "commit", owner: owner, repository: repository, itemIdentifier: parts.count > 3 ? parts[3] : nil)
        case "discussions":
            return Facts(contentType: "discussion", subtype: "discussion", owner: owner, repository: repository, number: parts.count > 3 ? Int(parts[3]) : nil)
        case "blob":
            return Facts(contentType: "code", subtype: "file", owner: owner, repository: repository, itemIdentifier: parts.dropFirst(3).joined(separator: "/"))
        case "tree":
            return Facts(contentType: "code", subtype: "directory", owner: owner, repository: repository, itemIdentifier: parts.dropFirst(3).joined(separator: "/"))
        default:
            return Facts(contentType: "softwareSourceCode", subtype: "repository", owner: owner, repository: repository)
        }
    }

    private func parseRepositoryMetadata(_ document: HTMLDocument, facts: Facts, fragment: inout MetadataFragment) {
        guard facts.subtype == "repository" || facts.subtype == "release" || facts.subtype == "file" || facts.subtype == "directory" else { return }
        let html = document.html

        if let about = extractAbout(html) {
            fragment.descriptionCandidates.append(.init(value: about, source: .semanticDOM, confidence: 0.88))
            fragment.addAttribute("about", value: .string(about), source: .semanticDOM, confidence: 0.90)
        }

        let topics = extractTopics(html)
        if !topics.isEmpty {
            fragment.originalTagCandidates.append(.init(value: topics, source: .semanticDOM, confidence: 0.88))
            fragment.addAttribute("topics", value: .array(topics.map(JSONValue.string)), source: .semanticDOM, confidence: 0.90)
        }

        if let language = extractProgrammingLanguage(html) {
            fragment.addAttribute("primaryLanguage", value: .string(language), source: .semanticDOM, confidence: 0.88)
            fragment.derivedTopicCandidates.append(.init(value: [language], source: .derived, confidence: 0.82))
        }
        if let license = extractLicense(html) {
            fragment.addAttribute("license", value: .string(license), source: .semanticDOM, confidence: 0.82)
        }
        if let branch = extractMeta(name: "octolytics-dimension-repository_default_branch", html: html) {
            fragment.addAttribute("defaultBranch", value: .string(branch), source: .semanticDOM, confidence: 0.90)
        }
        if html.localizedCaseInsensitiveContains("This repository was archived") || html.localizedCaseInsensitiveContains("repository is archived") {
            fragment.addAttribute("isArchived", value: .bool(true), source: .semanticDOM, confidence: 0.94)
        }

        if let readme = extractReadme(html) {
            if let firstParagraph = HTMLTools.firstMeaningfulParagraph(in: readme, minimumLength: 30) {
                fragment.excerptCandidates.append(.init(value: firstParagraph, source: .semanticDOM, confidence: 0.86))
                fragment.addAttribute("readmeExcerpt", value: .string(firstParagraph), source: .semanticDOM, confidence: 0.88)
            }
            let headings = (1...3).flatMap { level in
                HTMLTools.pairedTags(named: "h\(level)", in: readme).map { HTMLTools.cleanText($0.innerHTML) }
            }.filter { !$0.isEmpty && $0.count <= 160 }
            if !headings.isEmpty {
                fragment.addAttribute("readmeHeadings", value: .array(Array(headings.prefix(12)).map(JSONValue.string)), source: .semanticDOM, confidence: 0.82)
            }
        }
    }

    private func parseIssueLikeMetadata(_ document: HTMLDocument, facts: Facts, fragment: inout MetadataFragment) {
        guard ["issue", "pullRequest", "discussion"].contains(facts.subtype) else { return }
        let html = document.html
        let lower = html.lowercased()

        let state: String?
        if facts.subtype == "pullRequest" && (lower.contains("state--merged") || lower.contains(">merged<") || lower.contains("pull request successfully merged")) {
            state = "merged"
        } else if lower.contains("state--closed") || lower.contains(">closed<") {
            state = "closed"
        } else if lower.contains("state--open") || lower.contains(">open<") {
            state = "open"
        } else {
            state = nil
        }
        if let state {
            fragment.addAttribute("state", value: .string(state), source: .semanticDOM, confidence: 0.88)
        }

        let labels = HTMLTools.pairedTags(named: "a", in: html).compactMap { anchor -> String? in
            let hints = ((anchor.attributes["class"] ?? "") + " " + (anchor.attributes["data-name"] ?? "")).lowercased()
            guard hints.contains("issuelabel") || hints.contains("label") else { return nil }
            let value = HTMLTools.cleanText(anchor.innerHTML)
            return value.count >= 1 && value.count <= 80 ? value : nil
        }
        if !labels.isEmpty {
            var seen = Set<String>()
            let unique = labels.filter { seen.insert($0.lowercased()).inserted }
            fragment.originalTagCandidates.append(.init(value: Array(unique.prefix(20)), source: .semanticDOM, confidence: 0.82))
            fragment.addAttribute("labels", value: .array(Array(unique.prefix(20)).map(JSONValue.string)), source: .semanticDOM, confidence: 0.84)
        }

        if let body = extractFirstCommentBody(html), let paragraph = HTMLTools.firstMeaningfulParagraph(in: body, minimumLength: 20) ?? HTMLTools.cleanText(body).nilIfEmpty {
            fragment.excerptCandidates.append(.init(value: String(paragraph.prefix(2_000)), source: .semanticDOM, confidence: 0.82))
        }

        if let author = extractAuthorLogin(html) {
            fragment.creatorCandidates.append(.init(value: author, source: .semanticDOM, confidence: 0.82))
        }
        for time in HTMLTools.pairedTags(named: "relative-time", in: html).prefix(2) {
            if let raw = time.attributes["datetime"], let date = HTMLTools.normalizedDate(raw) {
                fragment.publishedAtCandidates.append(.init(value: date, source: .semanticDOM, confidence: 0.86))
                break
            }
        }
    }

    private func extractAbout(_ html: String) -> String? {
        let patterns = [
            #"<h2\b[^>]*>\s*About\s*</h2>(.*?)(?:<h2\b|</aside>|</div>\s*</div>)"#,
            #"<p\b[^>]*class=['\"][^'\"]*f4[^'\"]*my-3[^'\"]*['\"][^>]*>(.*?)</p>"#,
            #"<meta\b[^>]*name=['\"]description['\"][^>]*content=['\"]([^'\"]+)['\"]"#
        ]
        for pattern in patterns {
            guard let match = HTMLTools.firstMatch(pattern, in: html), match.count > 1 else { continue }
            let value = HTMLTools.cleanText(match[1])
            if HTMLTools.isMeaningful(value, minimumLength: 12), value.count <= 1_000 { return value }
        }
        return nil
    }

    private func extractTopics(_ html: String) -> [String] {
        var values: [String] = []
        for anchor in HTMLTools.pairedTags(named: "a", in: html).prefix(1_000) {
            let hints = ((anchor.attributes["class"] ?? "") + " " + (anchor.attributes["href"] ?? "")).lowercased()
            guard hints.contains("topic-tag") || hints.contains("/topics/") else { continue }
            let value = HTMLTools.cleanText(anchor.innerHTML)
            if value.count >= 1, value.count <= 60 { values.append(value) }
        }
        var seen = Set<String>()
        return values.filter { seen.insert($0.lowercased()).inserted }.prefix(20).map { $0 }
    }

    private func extractProgrammingLanguage(_ html: String) -> String? {
        let patterns = [
            #"itemprop=['\"]programmingLanguage['\"][^>]*>(.*?)</"#,
            #"aria-label=['\"]([^'\"]+)\s+\d+(?:\.\d+)?%['\"]"#
        ]
        for pattern in patterns {
            if let match = HTMLTools.firstMatch(pattern, in: html), match.count > 1 {
                let value = HTMLTools.cleanText(match[1])
                if !value.isEmpty, value.count <= 80 { return value }
            }
        }
        return nil
    }

    private func extractLicense(_ html: String) -> String? {
        let patterns = [
            #"<a\b[^>]*href=['\"][^'\"]*(?:LICENSE|license)[^'\"]*['\"][^>]*>(.*?)</a>"#,
            #"<span\b[^>]*class=['\"][^'\"]*license[^'\"]*['\"][^>]*>(.*?)</span>"#
        ]
        for pattern in patterns {
            if let match = HTMLTools.firstMatch(pattern, in: html), match.count > 1 {
                let value = HTMLTools.cleanText(match[1]).replacingOccurrences(of: " license", with: "", options: .caseInsensitive)
                if value.count >= 2, value.count <= 100 { return value }
            }
        }
        return nil
    }

    private func extractReadme(_ html: String) -> String? {
        let patterns = [
            #"<article\b[^>]*class=['\"][^'\"]*markdown-body[^'\"]*['\"][^>]*>(.*?)</article>"#,
            #"<div\b[^>]*id=['\"]readme['\"][^>]*>(.*?)</div>\s*</div>"#
        ]
        for pattern in patterns {
            if let match = HTMLTools.firstMatch(pattern, in: html), match.count > 1 { return match[1] }
        }
        return nil
    }

    private func extractFirstCommentBody(_ html: String) -> String? {
        let patterns = [
            #"<div\b[^>]*class=['\"][^'\"]*comment-body[^'\"]*['\"][^>]*>(.*?)</div>\s*</div>"#,
            #"<td\b[^>]*class=['\"][^'\"]*comment-body[^'\"]*['\"][^>]*>(.*?)</td>"#
        ]
        for pattern in patterns {
            if let match = HTMLTools.firstMatch(pattern, in: html), match.count > 1 { return match[1] }
        }
        return nil
    }

    private func extractAuthorLogin(_ html: String) -> String? {
        let patterns = [
            #"<a\b[^>]*class=['\"][^'\"]*author[^'\"]*['\"][^>]*>(.*?)</a>"#,
            #"data-hovercard-type=['\"]user['\"][^>]*>(.*?)</a>"#
        ]
        for pattern in patterns {
            if let match = HTMLTools.firstMatch(pattern, in: html), match.count > 1 {
                let value = HTMLTools.cleanText(match[1])
                if value.count >= 1, value.count <= 80 { return value }
            }
        }
        return nil
    }

    private func extractMeta(name: String, html: String) -> String? {
        for attributes in HTMLTools.tags(named: "meta", in: html) {
            if attributes["name"]?.lowercased() == name.lowercased() {
                return attributes["content"].map { HTMLTools.cleanText($0) }
            }
        }
        return nil
    }

    private struct Facts {
        var contentType: String
        var subtype: String
        var owner: String?
        var repository: String?
        var number: Int?
        var itemIdentifier: String?

        init(contentType: String, subtype: String, owner: String? = nil, repository: String? = nil, number: Int? = nil, itemIdentifier: String? = nil) {
            self.contentType = contentType
            self.subtype = subtype
            self.owner = owner
            self.repository = repository
            self.number = number
            self.itemIdentifier = itemIdentifier
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
