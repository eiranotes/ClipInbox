import Foundation

struct NamedCandidate: Equatable, Sendable {
    var value: String
    var confidence: Double
    var source: MetadataSource
}

struct MetadataStatusHint: Equatable, Sendable {
    var status: MetadataStatus
    var confidence: Double
    var reason: String
}

struct MetadataFragment: Sendable {
    var platformCandidates: [NamedCandidate] = []
    var contentTypeCandidates: [NamedCandidate] = []
    var contentSubtypeCandidates: [NamedCandidate] = []

    var titleCandidates: [ExtractedField<String>] = []
    var descriptionCandidates: [ExtractedField<String>] = []
    var siteNameCandidates: [ExtractedField<String>] = []
    var creatorCandidates: [ExtractedField<String>] = []
    var publishedAtCandidates: [ExtractedField<String>] = []
    var modifiedAtCandidates: [ExtractedField<String>] = []
    var canonicalURLCandidates: [ExtractedField<String>] = []
    var imageCandidates: [ExtractedField<String>] = []
    var originalTagCandidates: [ExtractedField<[String]>] = []
    var derivedTopicCandidates: [ExtractedField<[String]>] = []
    var durationCandidates: [ExtractedField<Int>] = []
    var readingMinutesCandidates: [ExtractedField<Int>] = []
    var languageCandidates: [ExtractedField<String>] = []
    var excerptCandidates: [ExtractedField<String>] = []
    var bodyTextCandidates: [ExtractedField<String>] = []

    var attributes: [String: [ExtractedField<JSONValue>]] = [:]
    var volatileAttributes: [String: [ExtractedField<JSONValue>]] = [:]
    var explicitContentDocumentURLs: [String] = []
    var statusHints: [MetadataStatusHint] = []
    var adapterFailures: [String] = []

    var hasOpenGraph = false
    var hasJSONLD = false
    var hasSemanticBody = false
    var requiresJavaScript = false
    var visibleTextLength = 0

    mutating func merge(_ other: MetadataFragment) {
        platformCandidates += other.platformCandidates
        contentTypeCandidates += other.contentTypeCandidates
        contentSubtypeCandidates += other.contentSubtypeCandidates
        titleCandidates += other.titleCandidates
        descriptionCandidates += other.descriptionCandidates
        siteNameCandidates += other.siteNameCandidates
        creatorCandidates += other.creatorCandidates
        publishedAtCandidates += other.publishedAtCandidates
        modifiedAtCandidates += other.modifiedAtCandidates
        canonicalURLCandidates += other.canonicalURLCandidates
        imageCandidates += other.imageCandidates
        originalTagCandidates += other.originalTagCandidates
        derivedTopicCandidates += other.derivedTopicCandidates
        durationCandidates += other.durationCandidates
        readingMinutesCandidates += other.readingMinutesCandidates
        languageCandidates += other.languageCandidates
        excerptCandidates += other.excerptCandidates
        bodyTextCandidates += other.bodyTextCandidates
        for (key, values) in other.attributes { attributes[key, default: []] += values }
        for (key, values) in other.volatileAttributes { volatileAttributes[key, default: []] += values }
        explicitContentDocumentURLs += other.explicitContentDocumentURLs
        statusHints += other.statusHints
        adapterFailures += other.adapterFailures
        hasOpenGraph = hasOpenGraph || other.hasOpenGraph
        hasJSONLD = hasJSONLD || other.hasJSONLD
        hasSemanticBody = hasSemanticBody || other.hasSemanticBody
        requiresJavaScript = requiresJavaScript || other.requiresJavaScript
        visibleTextLength = max(visibleTextLength, other.visibleTextLength)
    }

    mutating func addAttribute(
        _ key: String,
        value: JSONValue,
        source: MetadataSource,
        confidence: Double,
        rawValue: JSONValue? = nil,
        volatile: Bool = false
    ) {
        let field = ExtractedField(value: value, source: source, confidence: confidence, rawValue: rawValue)
        if volatile {
            volatileAttributes[key, default: []].append(field)
        } else {
            attributes[key, default: []].append(field)
        }
    }
}
