import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(_ value: Any?) {
        switch value {
        case nil, is NSNull:
            self = .null
        case let value as String:
            self = .string(value)
        case let value as Bool:
            self = .bool(value)
        case let value as NSNumber:
            self = .number(value.doubleValue)
        case let value as [Any]:
            self = .array(value.map(JSONValue.init))
        case let value as [String: Any]:
            self = .object(value.mapValues(JSONValue.init))
        default:
            self = .string(String(describing: value!))
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    public var stringValue: String? {
        switch self {
        case .string(let value): return value
        case .number(let value):
            return value.rounded() == value ? String(Int(value)) : String(value)
        case .bool(let value): return value ? "true" : "false"
        case .object, .array, .null: return nil
        }
    }
}

public enum MetadataSource: String, Codable, CaseIterable, Sendable {
    case httpHeader
    case openGraph
    case twitterCard
    case jsonLD
    case microdata
    case rdfa
    case semanticDOM
    case embeddedState
    case urlPattern
    case derived
}

public struct ExtractedField<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var value: Value
    public var source: MetadataSource
    public var confidence: Double
    public var rawValue: JSONValue?
    public var extractedAt: String

    public init(
        value: Value,
        source: MetadataSource,
        confidence: Double,
        rawValue: JSONValue? = nil,
        extractedAt: String = ISO8601DateFormatter.clipInbox.string(from: Date())
    ) {
        self.value = value
        self.source = source
        self.confidence = min(max(confidence, 0), 1)
        self.rawValue = rawValue
        self.extractedAt = extractedAt
    }
}

public enum MetadataStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case complete
    case partial
    case blocked
    case loginRequired
    case removed
    case unsupported
    case failed
}

public enum ExtractionStage: String, Codable, CaseIterable, Sendable {
    case normalization
    case http
    case head
    case structuredData
    case semanticDOM
    case embeddedState
    case platformAdapter
    case renderedDOM
    case file
    case resolution
    case summary
    case cache
}

public struct ExtractionAttempt: Codable, Equatable, Sendable {
    public var stage: ExtractionStage
    public var startedAt: String
    public var finishedAt: String
    public var succeeded: Bool
    public var message: String?
    public var errorCode: String?

    public init(
        stage: ExtractionStage,
        startedAt: String,
        finishedAt: String,
        succeeded: Bool,
        message: String? = nil,
        errorCode: String? = nil
    ) {
        self.stage = stage
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.succeeded = succeeded
        self.message = message
        self.errorCode = errorCode
    }
}

public struct RedirectHop: Codable, Equatable, Sendable {
    public var statusCode: Int
    public var fromURL: String
    public var toURL: String

    public init(statusCode: Int, fromURL: String, toURL: String) {
        self.statusCode = statusCode
        self.fromURL = fromURL
        self.toURL = toURL
    }
}

public struct HTTPInspection: Codable, Equatable, Sendable {
    public var statusCode: Int?
    public var finalURL: String
    public var contentType: String?
    public var contentLength: Int64?
    public var contentDisposition: String?
    public var charset: String?
    public var language: String?
    public var downloadFilename: String?
    public var redirects: [RedirectHop]
    public var isHTML: Bool
    public var isLoginPage: Bool
    public var isBlockedPage: Bool
    public var isRemovedPage: Bool
    public var responseBytes: Int

    public init(
        statusCode: Int? = nil,
        finalURL: String,
        contentType: String? = nil,
        contentLength: Int64? = nil,
        contentDisposition: String? = nil,
        charset: String? = nil,
        language: String? = nil,
        downloadFilename: String? = nil,
        redirects: [RedirectHop] = [],
        isHTML: Bool = false,
        isLoginPage: Bool = false,
        isBlockedPage: Bool = false,
        isRemovedPage: Bool = false,
        responseBytes: Int = 0
    ) {
        self.statusCode = statusCode
        self.finalURL = finalURL
        self.contentType = contentType
        self.contentLength = contentLength
        self.contentDisposition = contentDisposition
        self.charset = charset
        self.language = language
        self.downloadFilename = downloadFilename
        self.redirects = redirects
        self.isHTML = isHTML
        self.isLoginPage = isLoginPage
        self.isBlockedPage = isBlockedPage
        self.isRemovedPage = isRemovedPage
        self.responseBytes = responseBytes
    }
}

public struct LinkMetadataResult: Codable, Equatable, Sendable {
    public var originalURL: String
    public var resolvedURL: String?
    public var canonicalURL: String?
    public var normalizedURL: String?
    public var originalFragment: String?

    public var platform: String
    public var contentType: String
    public var contentSubtype: String?

    public var title: ExtractedField<String>?
    public var description: ExtractedField<String>?
    public var summaryShort: ExtractedField<String>?
    public var summaryDetail: ExtractedField<String>?

    public var siteName: ExtractedField<String>?
    public var creator: ExtractedField<String>?
    public var publishedAt: ExtractedField<String>?
    public var modifiedAt: ExtractedField<String>?

    public var thumbnail: ExtractedField<String>?
    public var images: [ExtractedField<String>]

    public var originalTags: [ExtractedField<[String]>]
    public var derivedTopics: [ExtractedField<[String]>]

    public var durationSeconds: ExtractedField<Int>?
    public var readingMinutes: ExtractedField<Int>?

    public var attributes: [String: ExtractedField<JSONValue>]
    public var volatileAttributes: [String: ExtractedField<JSONValue>]

    public var status: MetadataStatus
    public var http: HTTPInspection?
    public var extractionAttempts: [ExtractionAttempt]
    public var analyzedAt: String
    public var engineVersion: Int

    public init(
        originalURL: String,
        resolvedURL: String? = nil,
        canonicalURL: String? = nil,
        normalizedURL: String? = nil,
        originalFragment: String? = nil,
        platform: String = "web",
        contentType: String = "webPage",
        contentSubtype: String? = nil,
        title: ExtractedField<String>? = nil,
        description: ExtractedField<String>? = nil,
        summaryShort: ExtractedField<String>? = nil,
        summaryDetail: ExtractedField<String>? = nil,
        siteName: ExtractedField<String>? = nil,
        creator: ExtractedField<String>? = nil,
        publishedAt: ExtractedField<String>? = nil,
        modifiedAt: ExtractedField<String>? = nil,
        thumbnail: ExtractedField<String>? = nil,
        images: [ExtractedField<String>] = [],
        originalTags: [ExtractedField<[String]>] = [],
        derivedTopics: [ExtractedField<[String]>] = [],
        durationSeconds: ExtractedField<Int>? = nil,
        readingMinutes: ExtractedField<Int>? = nil,
        attributes: [String: ExtractedField<JSONValue>] = [:],
        volatileAttributes: [String: ExtractedField<JSONValue>] = [:],
        status: MetadataStatus = .pending,
        http: HTTPInspection? = nil,
        extractionAttempts: [ExtractionAttempt] = [],
        analyzedAt: String = ISO8601DateFormatter.clipInbox.string(from: Date()),
        engineVersion: Int = 1
    ) {
        self.originalURL = originalURL
        self.resolvedURL = resolvedURL
        self.canonicalURL = canonicalURL
        self.normalizedURL = normalizedURL
        self.originalFragment = originalFragment
        self.platform = platform
        self.contentType = contentType
        self.contentSubtype = contentSubtype
        self.title = title
        self.description = description
        self.summaryShort = summaryShort
        self.summaryDetail = summaryDetail
        self.siteName = siteName
        self.creator = creator
        self.publishedAt = publishedAt
        self.modifiedAt = modifiedAt
        self.thumbnail = thumbnail
        self.images = images
        self.originalTags = originalTags
        self.derivedTopics = derivedTopics
        self.durationSeconds = durationSeconds
        self.readingMinutes = readingMinutes
        self.attributes = attributes
        self.volatileAttributes = volatileAttributes
        self.status = status
        self.http = http
        self.extractionAttempts = extractionAttempts
        self.analyzedAt = analyzedAt
        self.engineVersion = engineVersion
    }

    public var bestOpenURL: String {
        canonicalURL ?? resolvedURL ?? normalizedURL ?? originalURL
    }

    public var hasUsefulMetadata: Bool {
        title != nil || description != nil || thumbnail != nil || creator != nil || !attributes.isEmpty
    }
}

public struct MetadataConfiguration: Codable, Equatable, Sendable {
    public var maximumRedirects: Int
    public var requestTimeout: TimeInterval
    public var totalTimeout: TimeInterval
    public var maximumHTMLBytes: Int
    public var maximumDOMTextCharacters: Int
    public var maximumEmbeddedStateBytes: Int
    public var maximumImages: Int
    public var maximumOriginalTags: Int
    public var automaticRetryCount: Int
    public var renderTimeout: TimeInterval
    public var cacheTTL: TimeInterval
    public var userAgent: String

    public init(
        maximumRedirects: Int = 5,
        requestTimeout: TimeInterval = 5,
        totalTimeout: TimeInterval = 12,
        maximumHTMLBytes: Int = 2 * 1_024 * 1_024,
        maximumDOMTextCharacters: Int = 24_000,
        maximumEmbeddedStateBytes: Int = 512 * 1_024,
        maximumImages: Int = 5,
        maximumOriginalTags: Int = 20,
        automaticRetryCount: Int = 1,
        renderTimeout: TimeInterval = 6,
        cacheTTL: TimeInterval = 7 * 24 * 60 * 60,
        userAgent: String = "ClipInbox/1.0 (iOS; URL metadata preview)"
    ) {
        self.maximumRedirects = max(0, maximumRedirects)
        self.requestTimeout = max(1, requestTimeout)
        self.totalTimeout = max(requestTimeout, totalTimeout)
        self.maximumHTMLBytes = max(64 * 1_024, maximumHTMLBytes)
        self.maximumDOMTextCharacters = max(1_000, maximumDOMTextCharacters)
        self.maximumEmbeddedStateBytes = max(8 * 1_024, maximumEmbeddedStateBytes)
        self.maximumImages = max(1, maximumImages)
        self.maximumOriginalTags = max(1, maximumOriginalTags)
        self.automaticRetryCount = max(0, automaticRetryCount)
        self.renderTimeout = max(1, renderTimeout)
        self.cacheTTL = max(60, cacheTTL)
        self.userAgent = userAgent
    }

    public static let `default` = MetadataConfiguration()
}

public struct RenderedPage: Codable, Equatable, Sendable {
    public var finalURL: String
    public var title: String?
    public var meta: [String: [String]]
    public var canonicalURL: String?
    public var jsonLDScripts: [String]
    public var heading: String?
    public var mainText: String?
    public var creator: String?
    public var date: String?
    public var imageURLs: [String]
    public var language: String?

    public init(
        finalURL: String,
        title: String? = nil,
        meta: [String: [String]] = [:],
        canonicalURL: String? = nil,
        jsonLDScripts: [String] = [],
        heading: String? = nil,
        mainText: String? = nil,
        creator: String? = nil,
        date: String? = nil,
        imageURLs: [String] = [],
        language: String? = nil
    ) {
        self.finalURL = finalURL
        self.title = title
        self.meta = meta
        self.canonicalURL = canonicalURL
        self.jsonLDScripts = jsonLDScripts
        self.heading = heading
        self.mainText = mainText
        self.creator = creator
        self.date = date
        self.imageURLs = imageURLs
        self.language = language
    }
}

public struct MainCardPresentation: Codable, Equatable, Sendable {
    public var title: String
    public var subtitle: String
    public var thumbnailURL: String?
    public var contentTypeLabel: String
    public var status: MetadataStatus

    public init(title: String, subtitle: String, thumbnailURL: String?, contentTypeLabel: String, status: MetadataStatus) {
        self.title = title
        self.subtitle = subtitle
        self.thumbnailURL = thumbnailURL
        self.contentTypeLabel = contentTypeLabel
        self.status = status
    }
}

public struct DetailPresentationItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var label: String
    public var value: String

    public init(id: String, label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}

public struct DetailPresentationSection: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var items: [DetailPresentationItem]

    public init(id: String, title: String, items: [DetailPresentationItem]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

public extension ISO8601DateFormatter {
    static let clipInbox: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
