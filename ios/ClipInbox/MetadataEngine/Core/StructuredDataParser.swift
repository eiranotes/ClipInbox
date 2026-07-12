import Foundation

struct StructuredDataParser: Sendable {
    private let preferredTypes: [String: Double] = [
        "newsarticle": 1.00,
        "article": 0.98,
        "blogposting": 0.98,
        "techarticle": 0.98,
        "scholarlyarticle": 1.00,
        "report": 0.95,
        "socialmediaposting": 0.96,
        "discussionforumposting": 0.96,
        "videoobject": 1.00,
        "audioobject": 1.00,
        "product": 1.00,
        "softwareapplication": 1.00,
        "mobileapplication": 1.00,
        "webapplication": 0.98,
        "recipe": 0.98,
        "place": 0.95,
        "localbusiness": 0.98,
        "event": 0.98,
        "book": 0.96,
        "profilepage": 0.94,
        "person": 0.68,
        "organization": 0.68,
        "breadcrumblist": 0.55,
        "webpage": 0.62,
        "website": 0.50
    ]

    func parse(_ document: HTMLDocument, canonicalCandidates: [String] = []) -> MetadataFragment {
        let scripts = HTMLTools.scriptBlocks(in: document.html).filter { block in
            let type = block.attributes["type"]?.lowercased() ?? ""
            return type.contains("ld+json")
        }
        return parseScripts(
            scripts.map(\.content),
            baseURL: document.baseURL,
            canonicalCandidates: canonicalCandidates,
            maximumBytes: document.configuration.maximumEmbeddedStateBytes
        )
    }

    func parseScripts(
        _ scripts: [String],
        baseURL: URL,
        canonicalCandidates: [String],
        maximumBytes: Int
    ) -> MetadataFragment {
        var fragment = MetadataFragment()
        var objects: [[String: Any]] = []

        for script in scripts {
            guard script.utf8.count <= maximumBytes else { continue }
            let cleaned = cleanJSONScript(script)
            guard let data = cleaned.data(using: .utf8) else { continue }
            do {
                let root = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
                flatten(root, into: &objects, depth: 0)
                fragment.hasJSONLD = true
            } catch {
                continue
            }
        }

        guard !objects.isEmpty else { return fragment }
        let targetURLs = Set(([baseURL.absoluteString] + canonicalCandidates).map(normalizedComparableURL))
        let scored = objects.map { object in
            (object, score(object: object, targetURLs: targetURLs))
        }.sorted { lhs, rhs in lhs.1 > rhs.1 }

        for (index, pair) in scored.enumerated() {
            let object = pair.0
            let score = pair.1
            let confidenceScale = max(0.56, min(1.0, score))
            extract(
                object,
                isPrimary: index == 0,
                confidenceScale: confidenceScale,
                baseURL: baseURL,
                fragment: &fragment
            )
        }
        return fragment
    }

    private func cleanJSONScript(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("<!--") { value.removeFirst(4) }
        if value.hasSuffix("-->") { value.removeLast(3) }
        value = value.replacingOccurrences(of: "<![CDATA[", with: "")
        value = value.replacingOccurrences(of: "]]>", with: "")
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasSuffix(";") { value.removeLast() }
        return value
    }

    private func flatten(_ value: Any, into objects: inout [[String: Any]], depth: Int) {
        guard depth <= 12, objects.count < 500 else { return }
        if let array = value as? [Any] {
            for item in array { flatten(item, into: &objects, depth: depth + 1) }
            return
        }
        guard let dictionary = value as? [String: Any] else { return }
        if dictionary["@type"] != nil || dictionary["headline"] != nil || dictionary["mainEntity"] != nil {
            objects.append(dictionary)
        }
        if let graph = dictionary["@graph"] { flatten(graph, into: &objects, depth: depth + 1) }
        for (key, child) in dictionary where key != "@graph" {
            if child is [String: Any] || child is [Any] {
                flatten(child, into: &objects, depth: depth + 1)
            }
        }
    }

    private func score(object: [String: Any], targetURLs: Set<String>) -> Double {
        let types = typeNames(object)
        var value = types.compactMap { preferredTypes[$0] }.max() ?? 0.45

        let urlCandidates = [
            string(object["url"]),
            string(object["@id"]),
            entityURL(object["mainEntityOfPage"]),
            entityURL(object["mainEntity"])
        ].compactMap { $0 }.map(normalizedComparableURL)
        if urlCandidates.contains(where: targetURLs.contains) { value += 0.26 }

        if object["headline"] != nil || object["name"] != nil { value += 0.05 }
        if object["description"] != nil || object["abstract"] != nil { value += 0.04 }
        return min(1.0, value)
    }

    private func extract(
        _ object: [String: Any],
        isPrimary: Bool,
        confidenceScale: Double,
        baseURL: URL,
        fragment: inout MetadataFragment
    ) {
        let types = typeNames(object)
        let typeConfidence = isPrimary ? 0.98 : max(0.60, 0.82 * confidenceScale)
        for type in types {
            if let mapped = contentType(for: type) {
                fragment.contentTypeCandidates.append(.init(value: mapped, confidence: typeConfidence, source: .jsonLD))
                fragment.contentSubtypeCandidates.append(.init(value: canonicalTypeName(type), confidence: typeConfidence, source: .jsonLD))
            }
        }

        let titleValue = string(object["headline"]) ?? string(object["name"])
        appendString(titleValue, to: &fragment.titleCandidates, confidence: (isPrimary ? 0.98 : 0.78) * confidenceScale)
        let descriptionValue = string(object["description"]) ?? string(object["abstract"])
        appendString(descriptionValue, to: &fragment.descriptionCandidates, confidence: (isPrimary ? 0.96 : 0.76) * confidenceScale)

        for author in entityNames(object["author"] ?? object["creator"]) {
            appendString(author, to: &fragment.creatorCandidates, confidence: (isPrimary ? 0.95 : 0.74) * confidenceScale)
        }
        for publisher in entityNames(object["publisher"]) {
            appendString(publisher, to: &fragment.siteNameCandidates, confidence: (isPrimary ? 0.90 : 0.70) * confidenceScale)
        }
        if types.contains("organization") || types.contains("website") {
            appendString(string(object["name"]), to: &fragment.siteNameCandidates, confidence: 0.72 * confidenceScale)
        }

        appendDate(string(object["datePublished"]) ?? string(object["uploadDate"]) ?? string(object["startDate"]), to: &fragment.publishedAtCandidates, confidence: 0.96 * confidenceScale)
        appendDate(string(object["dateModified"]), to: &fragment.modifiedAtCandidates, confidence: 0.94 * confidenceScale)

        for image in imageURLs(object["image"] ?? object["thumbnailUrl"], baseURL: baseURL) {
            fragment.imageCandidates.append(.init(value: image, source: .jsonLD, confidence: (isPrimary ? 0.94 : 0.72) * confidenceScale))
        }

        let keywords = stringArray(object["keywords"])
        if !keywords.isEmpty {
            fragment.originalTagCandidates.append(.init(value: keywords, source: .jsonLD, confidence: 0.92 * confidenceScale, rawValue: JSONValue(object["keywords"])))
        }

        if let duration = HTMLTools.parseISODuration(string(object["duration"])) {
            fragment.durationCandidates.append(.init(value: duration, source: .jsonLD, confidence: 0.97 * confidenceScale, rawValue: JSONValue(object["duration"])))
        }

        if let language = HTMLTools.normalizedLanguage(string(object["inLanguage"])) {
            fragment.languageCandidates.append(.init(value: language, source: .jsonLD, confidence: 0.90 * confidenceScale))
        }

        if let canonical = string(object["url"]) ?? entityURL(object["mainEntityOfPage"]),
           let url = HTMLTools.resolveURL(canonical, relativeTo: baseURL) {
            fragment.canonicalURLCandidates.append(.init(value: url, source: .jsonLD, confidence: (isPrimary ? 0.93 : 0.68) * confidenceScale))
        }

        if let section = string(object["articleSection"]) {
            fragment.addAttribute("section", value: .string(section), source: .jsonLD, confidence: 0.90 * confidenceScale)
        }
        if let wordCount = integer(object["wordCount"]), wordCount > 0 {
            fragment.addAttribute("wordCount", value: .number(Double(wordCount)), source: .jsonLD, confidence: 0.92 * confidenceScale)
        }
        let genre = stringArrayOrScalar(object["genre"])
        if !genre.isEmpty {
            fragment.originalTagCandidates.append(.init(value: genre, source: .jsonLD, confidence: 0.80 * confidenceScale))
        }

        if types.contains("product") { extractProduct(object, confidenceScale: confidenceScale, fragment: &fragment) }
        if !types.intersection(["softwareapplication", "mobileapplication", "webapplication"]).isEmpty {
            extractSoftware(object, confidenceScale: confidenceScale, fragment: &fragment)
        }
        if types.contains("videoobject") { extractVideo(object, confidenceScale: confidenceScale, fragment: &fragment) }
        if types.contains("audioobject") { extractAudio(object, confidenceScale: confidenceScale, fragment: &fragment) }
        if types.contains("scholarlyarticle") || types.contains("report") { extractScholarly(object, confidenceScale: confidenceScale, fragment: &fragment) }
        if types.contains("event") { extractEvent(object, confidenceScale: confidenceScale, fragment: &fragment) }
        if types.contains("place") || types.contains("localbusiness") { extractPlace(object, confidenceScale: confidenceScale, fragment: &fragment) }
        if types.contains("breadcrumblist") { extractBreadcrumbs(object, confidenceScale: confidenceScale, fragment: &fragment) }
        if types.contains("recipe") { extractRecipe(object, confidenceScale: confidenceScale, fragment: &fragment) }
        if types.contains("book") { extractBook(object, confidenceScale: confidenceScale, fragment: &fragment) }

        extractInteractionStatistics(object, confidenceScale: confidenceScale, fragment: &fragment)
    }

    private func extractProduct(_ object: [String: Any], confidenceScale: Double, fragment: inout MetadataFragment) {
        addStringAttribute("brand", value: entityNames(object["brand"]).first, confidence: 0.94 * confidenceScale, fragment: &fragment)
        addStringAttribute("sku", value: string(object["sku"]), confidence: 0.90 * confidenceScale, fragment: &fragment)
        addStringAttribute("mpn", value: string(object["mpn"]), confidence: 0.88 * confidenceScale, fragment: &fragment)
        addStringAttribute("productID", value: string(object["productID"]), confidence: 0.90 * confidenceScale, fragment: &fragment)
        addStringAttribute("category", value: string(object["category"]), confidence: 0.84 * confidenceScale, fragment: &fragment)

        let offers = dictionaries(object["offers"])
        guard !offers.isEmpty else { return }
        let offer = offers.first(where: { string($0["price"]) != nil }) ?? offers[0]
        addStringAttribute("price", value: string(offer["price"]) ?? string(offer["lowPrice"]), confidence: 0.96 * confidenceScale, fragment: &fragment)
        addStringAttribute("highPrice", value: string(offer["highPrice"]), confidence: 0.90 * confidenceScale, fragment: &fragment)
        addStringAttribute("currency", value: string(offer["priceCurrency"]), confidence: 0.96 * confidenceScale, fragment: &fragment)
        addStringAttribute("availability", value: tailName(string(offer["availability"])), confidence: 0.90 * confidenceScale, fragment: &fragment)
        addStringAttribute("seller", value: entityNames(offer["seller"]).first, confidence: 0.82 * confidenceScale, fragment: &fragment)
        if offers.count > 1 || string(offer["lowPrice"]) != nil {
            fragment.addAttribute("offerType", value: .string("aggregate"), source: .jsonLD, confidence: 0.86 * confidenceScale)
        } else {
            fragment.addAttribute("offerType", value: .string("offer"), source: .jsonLD, confidence: 0.86 * confidenceScale)
        }
    }

    private func extractSoftware(_ object: [String: Any], confidenceScale: Double, fragment: inout MetadataFragment) {
        addStringAttribute("applicationCategory", value: string(object["applicationCategory"]), confidence: 0.92 * confidenceScale, fragment: &fragment)
        addStringAttribute("operatingSystem", value: string(object["operatingSystem"]), confidence: 0.92 * confidenceScale, fragment: &fragment)
        addStringAttribute("softwareVersion", value: string(object["softwareVersion"]), confidence: 0.90 * confidenceScale, fragment: &fragment)
        addStringAttribute("downloadURL", value: string(object["downloadUrl"]), confidence: 0.82 * confidenceScale, fragment: &fragment)
        addStringAttribute("contentRating", value: string(object["contentRating"]), confidence: 0.86 * confidenceScale, fragment: &fragment)
        let offers = dictionaries(object["offers"])
        if let offer = offers.first {
            addStringAttribute("price", value: string(offer["price"]), confidence: 0.92 * confidenceScale, fragment: &fragment)
            addStringAttribute("currency", value: string(offer["priceCurrency"]), confidence: 0.92 * confidenceScale, fragment: &fragment)
        }
    }

    private func extractVideo(_ object: [String: Any], confidenceScale: Double, fragment: inout MetadataFragment) {
        addStringAttribute("videoURL", value: string(object["contentUrl"]) ?? string(object["embedUrl"]), confidence: 0.90 * confidenceScale, fragment: &fragment)
        if let live = bool(object["isLiveBroadcast"]) {
            fragment.addAttribute("isLive", value: .bool(live), source: .jsonLD, confidence: 0.94 * confidenceScale)
        }
        addStringAttribute("transcript", value: string(object["transcript"]), confidence: 0.80 * confidenceScale, fragment: &fragment)
    }

    private func extractAudio(_ object: [String: Any], confidenceScale: Double, fragment: inout MetadataFragment) {
        addStringAttribute("audioURL", value: string(object["contentUrl"]) ?? string(object["embedUrl"]), confidence: 0.90 * confidenceScale, fragment: &fragment)
        addStringAttribute("encodingFormat", value: string(object["encodingFormat"]), confidence: 0.82 * confidenceScale, fragment: &fragment)
    }

    private func extractScholarly(_ object: [String: Any], confidenceScale: Double, fragment: inout MetadataFragment) {
        addStringAttribute("doi", value: identifierMatchingDOI(object["identifier"]), confidence: 0.94 * confidenceScale, fragment: &fragment)
        addStringAttribute("publication", value: entityNames(object["isPartOf"]).first, confidence: 0.86 * confidenceScale, fragment: &fragment)
        addStringAttribute("pagination", value: string(object["pagination"]), confidence: 0.82 * confidenceScale, fragment: &fragment)
    }

    private func extractEvent(_ object: [String: Any], confidenceScale: Double, fragment: inout MetadataFragment) {
        addStringAttribute("endDate", value: HTMLTools.normalizedDate(string(object["endDate"])), confidence: 0.90 * confidenceScale, fragment: &fragment)
        addStringAttribute("eventStatus", value: tailName(string(object["eventStatus"])), confidence: 0.86 * confidenceScale, fragment: &fragment)
        addStringAttribute("location", value: entityNames(object["location"]).first, confidence: 0.88 * confidenceScale, fragment: &fragment)
    }

    private func extractPlace(_ object: [String: Any], confidenceScale: Double, fragment: inout MetadataFragment) {
        addStringAttribute("address", value: addressString(object["address"]), confidence: 0.90 * confidenceScale, fragment: &fragment)
        addStringAttribute("telephone", value: string(object["telephone"]), confidence: 0.88 * confidenceScale, fragment: &fragment)
        if let geo = object["geo"] as? [String: Any] {
            if let latitude = number(geo["latitude"]), let longitude = number(geo["longitude"]) {
                fragment.addAttribute("latitude", value: .number(latitude), source: .jsonLD, confidence: 0.92 * confidenceScale)
                fragment.addAttribute("longitude", value: .number(longitude), source: .jsonLD, confidence: 0.92 * confidenceScale)
            }
        }
    }

    private func extractBreadcrumbs(_ object: [String: Any], confidenceScale: Double, fragment: inout MetadataFragment) {
        let items = dictionaries(object["itemListElement"])
        let names = items.compactMap { item -> String? in
            if let nested = item["item"] as? [String: Any] { return string(nested["name"]) }
            return string(item["name"])
        }
        guard !names.isEmpty else { return }
        fragment.addAttribute("breadcrumbs", value: .array(names.map(JSONValue.string)), source: .jsonLD, confidence: 0.86 * confidenceScale)
    }

    private func extractRecipe(_ object: [String: Any], confidenceScale: Double, fragment: inout MetadataFragment) {
        addStringAttribute("recipeCuisine", value: string(object["recipeCuisine"]), confidence: 0.88 * confidenceScale, fragment: &fragment)
        addStringAttribute("recipeCategory", value: string(object["recipeCategory"]), confidence: 0.88 * confidenceScale, fragment: &fragment)
        if let total = HTMLTools.parseISODuration(string(object["totalTime"])) {
            fragment.addAttribute("totalTimeSeconds", value: .number(Double(total)), source: .jsonLD, confidence: 0.92 * confidenceScale)
        }
    }

    private func extractBook(_ object: [String: Any], confidenceScale: Double, fragment: inout MetadataFragment) {
        addStringAttribute("isbn", value: string(object["isbn"]), confidence: 0.94 * confidenceScale, fragment: &fragment)
        addStringAttribute("bookFormat", value: tailName(string(object["bookFormat"])), confidence: 0.82 * confidenceScale, fragment: &fragment)
        addStringAttribute("numberOfPages", value: string(object["numberOfPages"]), confidence: 0.88 * confidenceScale, fragment: &fragment)
    }

    private func extractInteractionStatistics(_ object: [String: Any], confidenceScale: Double, fragment: inout MetadataFragment) {
        for statistic in dictionaries(object["interactionStatistic"]) {
            guard let count = number(statistic["userInteractionCount"]) else { continue }
            let type = tailName(entityURL(statistic["interactionType"]) ?? string(statistic["interactionType"])) ?? "interaction"
            let key = type.prefix(1).lowercased() + type.dropFirst() + "Count"
            fragment.addAttribute(String(key), value: .number(count), source: .jsonLD, confidence: 0.82 * confidenceScale, volatile: true)
        }
        if let aggregate = object["aggregateRating"] as? [String: Any] {
            if let rating = number(aggregate["ratingValue"]) {
                fragment.addAttribute("ratingValue", value: .number(rating), source: .jsonLD, confidence: 0.88 * confidenceScale, volatile: true)
            }
            if let count = number(aggregate["ratingCount"]) ?? number(aggregate["reviewCount"]) {
                fragment.addAttribute("ratingCount", value: .number(count), source: .jsonLD, confidence: 0.82 * confidenceScale, volatile: true)
            }
        }
    }

    private func contentType(for type: String) -> String? {
        switch type {
        case "article", "newsarticle", "blogposting", "techarticle", "socialmediaposting", "discussionforumposting": return "article"
        case "videoobject": return "video"
        case "audioobject": return "audio"
        case "product": return "product"
        case "softwareapplication", "mobileapplication", "webapplication": return "softwareApplication"
        case "recipe": return "recipe"
        case "place", "localbusiness": return "place"
        case "event": return "event"
        case "scholarlyarticle", "report": return "scholarlyArticle"
        case "book": return "book"
        case "profilepage", "person", "organization": return "profile"
        case "webpage", "website": return "webPage"
        default: return nil
        }
    }

    private func canonicalTypeName(_ type: String) -> String {
        let map = [
            "newsarticle": "NewsArticle", "blogposting": "BlogPosting", "techarticle": "TechArticle",
            "socialmediaposting": "SocialMediaPosting", "discussionforumposting": "DiscussionForumPosting",
            "videoobject": "VideoObject", "audioobject": "AudioObject", "product": "Product",
            "softwareapplication": "SoftwareApplication", "mobileapplication": "MobileApplication",
            "webapplication": "WebApplication", "scholarlyarticle": "ScholarlyArticle",
            "localbusiness": "LocalBusiness", "profilepage": "ProfilePage", "breadcrumblist": "BreadcrumbList"
        ]
        return map[type] ?? type.prefix(1).uppercased() + type.dropFirst()
    }

    private func typeNames(_ object: [String: Any]) -> Set<String> {
        Set(stringArrayOrScalar(object["@type"]).map { value in
            let tail = value.split(separator: "/").last.map(String.init) ?? value
            return tail.lowercased()
        })
    }

    private func normalizedComparableURL(_ rawValue: String) -> String {
        guard var components = URLComponents(string: rawValue) else { return rawValue.lowercased() }
        components.fragment = nil
        components.host = components.host?.lowercased()
        var value = components.string ?? rawValue
        if value.hasSuffix("/") { value.removeLast() }
        return value.lowercased()
    }

    private func string(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            let clean = HTMLTools.cleanText(value)
            return clean.isEmpty ? nil : clean
        case let value as NSNumber:
            return value.stringValue
        case let value as [String: Any]:
            return string(value["name"]) ?? string(value["@value"]) ?? string(value["value"])
        default:
            return nil
        }
    }

    private func stringArray(_ value: Any?) -> [String] {
        if let value = value as? String { return HTMLTools.commaSeparated(value) }
        if let values = value as? [Any] { return values.compactMap(string) }
        return []
    }

    private func stringArrayOrScalar(_ value: Any?) -> [String] {
        if let string = string(value) { return [string] }
        return stringArray(value)
    }

    private func dictionaries(_ value: Any?) -> [[String: Any]] {
        if let dictionary = value as? [String: Any] { return [dictionary] }
        return (value as? [Any])?.compactMap { $0 as? [String: Any] } ?? []
    }

    private func entityNames(_ value: Any?) -> [String] {
        if let string = string(value) { return [string] }
        if let values = value as? [Any] { return values.flatMap(entityNames) }
        if let dictionary = value as? [String: Any], let name = string(dictionary["name"]) { return [name] }
        return []
    }

    private func entityURL(_ value: Any?) -> String? {
        if let string = value as? String { return string }
        if let dictionary = value as? [String: Any] {
            return string(dictionary["@id"]) ?? string(dictionary["url"])
        }
        return nil
    }

    private func imageURLs(_ value: Any?, baseURL: URL) -> [String] {
        var rawValues: [String] = []
        if let string = value as? String {
            rawValues.append(string)
        } else if let dictionary = value as? [String: Any] {
            if let url = string(dictionary["url"]) ?? string(dictionary["contentUrl"]) { rawValues.append(url) }
        } else if let values = value as? [Any] {
            rawValues += values.flatMap { imageURLs($0, baseURL: baseURL) }
            return deduplicated(rawValues)
        }
        return deduplicated(rawValues.compactMap { HTMLTools.resolveURL($0, relativeTo: baseURL) })
    }

    private func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value.filter { $0.isNumber || $0 == "-" }) }
        return nil
    }

    private func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value.replacingOccurrences(of: ",", with: "")) }
        return nil
    }

    private func bool(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        if let value = value as? String {
            if value.lowercased() == "true" { return true }
            if value.lowercased() == "false" { return false }
        }
        return nil
    }

    private func addressString(_ value: Any?) -> String? {
        if let value = string(value) { return value }
        guard let dictionary = value as? [String: Any] else { return nil }
        return ["streetAddress", "addressLocality", "addressRegion", "postalCode", "addressCountry"]
            .compactMap { string(dictionary[$0]) }
            .joined(separator: ", ")
            .nilIfEmpty
    }

    private func identifierMatchingDOI(_ value: Any?) -> String? {
        for identifier in stringArrayOrScalar(value) {
            if let match = HTMLTools.firstMatch(#"10\.\d{4,9}/[-._;()/:A-Z0-9]+"#, in: identifier, options: [.caseInsensitive]), match.count > 0 {
                return match[0]
            }
        }
        for dictionary in dictionaries(value) {
            let propertyID = string(dictionary["propertyID"])?.lowercased()
            if propertyID == "doi", let doi = string(dictionary["value"]) { return doi }
        }
        return nil
    }

    private func tailName(_ value: String?) -> String? {
        guard let value else { return nil }
        return value.split(whereSeparator: { $0 == "/" || $0 == "#" }).last.map(String.init) ?? value
    }

    private func appendString(_ value: String?, to values: inout [ExtractedField<String>], confidence: Double) {
        guard let value else { return }
        let clean = HTMLTools.cleanText(value)
        guard !clean.isEmpty else { return }
        values.append(.init(value: clean, source: .jsonLD, confidence: confidence, rawValue: .string(value)))
    }

    private func appendDate(_ value: String?, to values: inout [ExtractedField<String>], confidence: Double) {
        guard let value, let date = HTMLTools.normalizedDate(value) else { return }
        values.append(.init(value: date, source: .jsonLD, confidence: confidence, rawValue: .string(value)))
    }

    private func addStringAttribute(_ key: String, value: String?, confidence: Double, fragment: inout MetadataFragment) {
        guard let value else { return }
        let clean = HTMLTools.cleanText(value)
        guard !clean.isEmpty else { return }
        fragment.addAttribute(key, value: .string(clean), source: .jsonLD, confidence: confidence, rawValue: .string(value))
    }

    private func deduplicated(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
