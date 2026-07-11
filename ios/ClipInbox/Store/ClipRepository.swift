import Foundation

enum ClipRepositoryError: LocalizedError, Equatable {
    case corruptSnapshot
    case unsupportedVersion(Int)
    case directoryUnavailable
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .corruptSnapshot:
            return L10n.text("보관함 파일을 읽을 수 없습니다. 원본 파일은 복구 폴더에 보존했습니다.")
        case .unsupportedVersion(let version):
            return L10n.format("format.unsupported_library_version", version)
        case .directoryUnavailable:
            return L10n.text("보관함 저장 위치를 준비하지 못했습니다.")
        case .writeFailed:
            return L10n.text("변경 내용을 기기에 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도하세요.")
        }
    }
}

enum ClipBootstrapResult {
    case firstRun
    case loaded(DataSnapshot)
    case recovered(DataSnapshot, quarantinedURL: URL?)
}

enum LibraryBootstrapState: Equatable {
    case firstRun
    case ready
    case recovered
    case recoveryRequired
    case updateRequired(version: Int)

    var blocksLibrary: Bool {
        switch self {
        case .recoveryRequired, .updateRequired: return true
        default: return false
        }
    }
}

protocol ClipRepository: AnyObject {
    func bootstrap() throws -> ClipBootstrapResult
    func commit(_ snapshot: DataSnapshot) throws
}

final class FileClipRepository: ClipRepository {
    static let supportedVersion = 2

    let fileURL: URL
    let previousURL: URL
    let recoveryDirectoryURL: URL

    private let fileManager: FileManager
    private var currentIsSafeToRotate = false

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        let directory = fileURL.deletingLastPathComponent()
        previousURL = directory.appendingPathComponent("clip-inbox-data.previous.json")
        recoveryDirectoryURL = directory.appendingPathComponent("ClipInboxRecovery", isDirectory: true)
    }

    func bootstrap() throws -> ClipBootstrapResult {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            currentIsSafeToRotate = false
            return .firstRun
        }

        do {
            let snapshot = try loadSnapshot(at: fileURL)
            currentIsSafeToRotate = true
            return .loaded(snapshot)
        } catch ClipRepositoryError.unsupportedVersion(let version) {
            throw ClipRepositoryError.unsupportedVersion(version)
        } catch {
            let quarantinedURL = quarantineCurrent()
            if fileManager.fileExists(atPath: previousURL.path) {
                do {
                    let previous = try loadSnapshot(at: previousURL)
                    currentIsSafeToRotate = false
                    return .recovered(previous, quarantinedURL: quarantinedURL)
                } catch ClipRepositoryError.unsupportedVersion(let version) {
                    throw ClipRepositoryError.unsupportedVersion(version)
                } catch {
                    throw ClipRepositoryError.corruptSnapshot
                }
            }
            throw ClipRepositoryError.corruptSnapshot
        }
    }

    func commit(_ snapshot: DataSnapshot) throws {
        guard snapshot.version == Self.supportedVersion else {
            throw ClipRepositoryError.unsupportedVersion(snapshot.version)
        }

        let directory = fileURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(snapshot)
            _ = try validatedSnapshot(from: data)

            if currentIsSafeToRotate, fileManager.fileExists(atPath: fileURL.path) {
                if fileManager.fileExists(atPath: previousURL.path) {
                    try fileManager.removeItem(at: previousURL)
                }
                try fileManager.copyItem(at: fileURL, to: previousURL)
                try applyFileProtection(to: previousURL)
            }

            try data.write(to: fileURL, options: .atomic)
            try applyFileProtection(to: fileURL)
            currentIsSafeToRotate = true
        } catch let error as ClipRepositoryError {
            throw error
        } catch {
            throw ClipRepositoryError.writeFailed
        }
    }

    private func loadSnapshot(at url: URL) throws -> DataSnapshot {
        do {
            return try validatedSnapshot(from: Data(contentsOf: url))
        } catch let error as ClipRepositoryError {
            throw error
        } catch {
            throw ClipRepositoryError.corruptSnapshot
        }
    }

    private func validatedSnapshot(from data: Data) throws -> DataSnapshot {
        let snapshot: DataSnapshot
        do {
            snapshot = try JSONDecoder().decode(DataSnapshot.self, from: data)
        } catch {
            throw ClipRepositoryError.corruptSnapshot
        }
        guard snapshot.version == Self.supportedVersion else {
            throw ClipRepositoryError.unsupportedVersion(snapshot.version)
        }
        return snapshot
    }

    private func quarantineCurrent() -> URL? {
        do {
            try fileManager.createDirectory(at: recoveryDirectoryURL, withIntermediateDirectories: true)
            let destination = recoveryDirectoryURL
                .appendingPathComponent("corrupt-\(UUID().uuidString)")
                .appendingPathExtension("json")
            try fileManager.copyItem(at: fileURL, to: destination)
            try applyFileProtection(to: destination)
            return destination
        } catch {
            return nil
        }
    }

    private func applyFileProtection(to url: URL) throws {
        #if os(iOS)
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        #endif
    }
}
