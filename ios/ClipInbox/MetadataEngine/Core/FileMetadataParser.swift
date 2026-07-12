import Foundation

struct FileMetadataParser: Sendable {
    func parse(payload: HTTPPayload, url: URL) -> MetadataFragment {
        var fragment = MetadataFragment()
        let mime = payload.inspection.contentType?.lowercased() ?? sniffMIME(data: payload.data, url: url)
        let filename = payload.inspection.downloadFilename ?? url.lastPathComponent.removingPercentEncoding

        if let filename, !filename.isEmpty {
            fragment.titleCandidates.append(.init(
                value: humanReadableFilename(filename),
                source: .httpHeader,
                confidence: payload.inspection.downloadFilename == nil ? 0.62 : 0.82,
                rawValue: .string(filename)
            ))
            fragment.addAttribute("fileName", value: .string(filename), source: .httpHeader, confidence: 0.92)
            let ext = (filename as NSString).pathExtension.lowercased()
            if !ext.isEmpty {
                fragment.addAttribute("fileExtension", value: .string(ext), source: .derived, confidence: 0.96)
            }
        }
        if let mime {
            fragment.addAttribute("mimeType", value: .string(mime), source: .httpHeader, confidence: 0.98)
        }
        fragment.addAttribute("fileSizeBytes", value: .number(Double(payload.data.count)), source: .httpHeader, confidence: 0.98)

        switch classify(mime: mime, url: url) {
        case .pdf:
            fragment.platformCandidates.append(.init(value: "PDF", confidence: 0.96, source: .httpHeader))
            fragment.contentTypeCandidates.append(.init(value: "document", confidence: 0.98, source: .httpHeader))
            fragment.contentSubtypeCandidates.append(.init(value: "pdf", confidence: 0.99, source: .httpHeader))
            if let pages = approximatePDFPageCount(payload.data) {
                fragment.addAttribute("pageCount", value: .number(Double(pages)), source: .derived, confidence: 0.58)
            }
        case .image:
            fragment.platformCandidates.append(.init(value: "Image", confidence: 0.92, source: .httpHeader))
            fragment.contentTypeCandidates.append(.init(value: "image", confidence: 0.98, source: .httpHeader))
            fragment.imageCandidates.append(.init(value: url.absoluteString, source: .httpHeader, confidence: 0.98))
            if let dimensions = imageDimensions(payload.data, mime: mime) {
                fragment.addAttribute("imageWidth", value: .number(Double(dimensions.width)), source: .derived, confidence: 0.96)
                fragment.addAttribute("imageHeight", value: .number(Double(dimensions.height)), source: .derived, confidence: 0.96)
            }
        case .text:
            fragment.platformCandidates.append(.init(value: "Text", confidence: 0.90, source: .httpHeader))
            fragment.contentTypeCandidates.append(.init(value: "document", confidence: 0.92, source: .httpHeader))
            fragment.contentSubtypeCandidates.append(.init(value: "text", confidence: 0.94, source: .httpHeader))
            if let text = payload.text ?? String(data: payload.data, encoding: .utf8) {
                let excerpt = HTMLTools.cleanText(String(text.prefix(4_000)))
                if HTMLTools.isMeaningful(excerpt, minimumLength: 20) {
                    fragment.descriptionCandidates.append(.init(value: excerpt, source: .httpHeader, confidence: 0.72))
                    fragment.excerptCandidates.append(.init(value: excerpt, source: .httpHeader, confidence: 0.78))
                    fragment.bodyTextCandidates.append(.init(value: excerpt, source: .httpHeader, confidence: 0.70))
                    if let minutes = HTMLTools.approximateReadingMinutes(text: excerpt, language: nil) {
                        fragment.readingMinutesCandidates.append(.init(value: minutes, source: .derived, confidence: 0.62))
                    }
                }
            }
        case .audio:
            fragment.platformCandidates.append(.init(value: "Audio", confidence: 0.90, source: .httpHeader))
            fragment.contentTypeCandidates.append(.init(value: "audio", confidence: 0.98, source: .httpHeader))
        case .video:
            fragment.platformCandidates.append(.init(value: "Video", confidence: 0.90, source: .httpHeader))
            fragment.contentTypeCandidates.append(.init(value: "video", confidence: 0.98, source: .httpHeader))
        case .archive:
            fragment.platformCandidates.append(.init(value: "File", confidence: 0.72, source: .httpHeader))
            fragment.contentTypeCandidates.append(.init(value: "file", confidence: 0.94, source: .httpHeader))
            fragment.contentSubtypeCandidates.append(.init(value: "archive", confidence: 0.88, source: .httpHeader))
        case .other:
            fragment.platformCandidates.append(.init(value: "File", confidence: 0.66, source: .httpHeader))
            fragment.contentTypeCandidates.append(.init(value: "file", confidence: 0.76, source: .httpHeader))
        }
        return fragment
    }

    private enum Kind { case pdf, image, text, audio, video, archive, other }

    private func classify(mime: String?, url: URL) -> Kind {
        let value = mime?.lowercased() ?? ""
        if value == "application/pdf" || url.pathExtension.lowercased() == "pdf" { return .pdf }
        if value.hasPrefix("image/") { return .image }
        if value.hasPrefix("text/") || ["json", "xml", "md", "csv", "log"].contains(url.pathExtension.lowercased()) { return .text }
        if value.hasPrefix("audio/") { return .audio }
        if value.hasPrefix("video/") { return .video }
        if value.contains("zip") || value.contains("gzip") || value.contains("tar") || value.contains("compressed") { return .archive }
        return .other
    }

    private func sniffMIME(data: Data, url: URL) -> String? {
        let bytes = [UInt8](data.prefix(12))
        if bytes.starts(with: [0x25, 0x50, 0x44, 0x46]) { return "application/pdf" }
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if bytes.starts(with: [0x47, 0x49, 0x46, 0x38]) { return "image/gif" }
        if bytes.count >= 12, String(bytes: bytes[0..<4], encoding: .ascii) == "RIFF", String(bytes: bytes[8..<12], encoding: .ascii) == "WEBP" { return "image/webp" }
        return nil
    }

    private func humanReadableFilename(_ filename: String) -> String {
        let base = (filename as NSString).deletingPathExtension
        let spaced = base.replacingOccurrences(of: #"[-_]+"#, with: " ", options: .regularExpression)
        return HTMLTools.cleanText(spaced).isEmpty ? filename : HTMLTools.cleanText(spaced)
    }

    private func approximatePDFPageCount(_ data: Data) -> Int? {
        guard data.count <= 2 * 1_024 * 1_024,
              let text = String(data: data, encoding: .isoLatin1) else { return nil }
        let values = HTMLTools.matches(#"/Type\s*/Pages\b[^>]{0,300}/Count\s+(\d+)"#, in: text).compactMap { $0.count > 1 ? Int($0[1]) : nil }
        return values.filter { (1...100_000).contains($0) }.max()
    }

    private func imageDimensions(_ data: Data, mime: String?) -> (width: Int, height: Int)? {
        let bytes = [UInt8](data)
        if (mime == "image/png" || bytes.starts(with: [0x89, 0x50, 0x4E, 0x47])), bytes.count >= 24 {
            let width = Int(bytes[16]) << 24 | Int(bytes[17]) << 16 | Int(bytes[18]) << 8 | Int(bytes[19])
            let height = Int(bytes[20]) << 24 | Int(bytes[21]) << 16 | Int(bytes[22]) << 8 | Int(bytes[23])
            return width > 0 && height > 0 ? (width, height) : nil
        }
        if mime == "image/jpeg" || bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            var index = 2
            while index + 9 < bytes.count {
                guard bytes[index] == 0xFF else { index += 1; continue }
                let marker = bytes[index + 1]
                if [0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF].contains(marker) {
                    let height = Int(bytes[index + 5]) << 8 | Int(bytes[index + 6])
                    let width = Int(bytes[index + 7]) << 8 | Int(bytes[index + 8])
                    return width > 0 && height > 0 ? (width, height) : nil
                }
                guard index + 3 < bytes.count else { break }
                let length = Int(bytes[index + 2]) << 8 | Int(bytes[index + 3])
                guard length >= 2 else { break }
                index += 2 + length
            }
        }
        return nil
    }
}
