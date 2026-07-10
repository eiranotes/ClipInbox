import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private var pendingImageData: Data?
    private var hasStartedSaving = false
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let statusLabel = UILabel()

    private enum AutoSaveError: LocalizedError {
        case missingPayload

        var errorDescription: String? {
            "공유한 링크, 텍스트 또는 이미지를 읽을 수 없습니다."
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSavingView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasStartedSaving else { return }
        hasStartedSaving = true
        Task { @MainActor in await saveAndComplete() }
    }

    private func configureSavingView() {
        view.backgroundColor = .systemBackground
        activityIndicator.startAnimating()
        statusLabel.text = "Clip Inbox에 저장하는 중…"
        statusLabel.font = UIFont(name: "Pretendard-Regular", size: 15) ?? .preferredFont(forTextStyle: .body)
        statusLabel.textColor = .label

        let stack = UIStackView(arrangedSubviews: [activityIndicator, statusLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @MainActor
    private func saveAndComplete() async {
        var newlyStoredImageName: String?
        do {
            guard let item = await loadPayload() else { throw AutoSaveError.missingPayload }
            let sharedImageName: String?
            if let pendingImageData {
                sharedImageName = try SharedClipQueue.storeImageData(pendingImageData, for: item.id)
                newlyStoredImageName = sharedImageName
            } else {
                sharedImageName = item.sharedImageName
            }
            let finalPayload = SharedClipPayload(
                id: item.id,
                type: item.type,
                title: item.title,
                source: item.source,
                url: item.url,
                text: item.text,
                sharedImageName: sharedImageName,
                folder: item.folder,
                tags: item.tags,
                memo: item.memo,
                createdAt: item.createdAt
            )
            try SharedClipQueue.enqueue(finalPayload)
            statusLabel.text = "저장 완료"
            extensionContext?.completeRequest(returningItems: nil)
        } catch {
            if let newlyStoredImageName { try? SharedClipQueue.removeImage(named: newlyStoredImageName) }
            showFailure(error)
        }
    }

    @MainActor
    private func showFailure(_ error: Error) {
        activityIndicator.stopAnimating()
        statusLabel.text = "저장할 수 없습니다"
        let alert = UIAlertController(title: "저장할 수 없습니다",
                                      message: error.localizedDescription,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "닫기", style: .default) { [weak self] _ in
            self?.extensionContext?.cancelRequest(withError: error)
        })
        present(alert, animated: true)
    }

    private func loadPayload() async -> SharedClipPayload? {
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        let attributedTitle = items.compactMap(\.attributedTitle?.string).first
        let attributedText = items.compactMap(\.attributedContentText?.string).first
        let providers = items.flatMap { $0.attachments ?? [] }

        var sharedURL: URL?
        var sharedText = attributedText
        var imageData: Data?

        for provider in providers {
            if sharedURL == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let item = try? await loadItem(from: provider, typeIdentifier: UTType.url.identifier) {
                sharedURL = item as? URL ?? (item as? NSURL).map { $0 as URL }
            }
            if sharedText == nil, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
               let item = try? await loadItem(from: provider, typeIdentifier: UTType.plainText.identifier) {
                sharedText = item as? String ?? (item as? NSString).map { String($0) }
            }
            if imageData == nil, provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
               let item = try? await loadItem(from: provider, typeIdentifier: UTType.image.identifier) {
                imageData = normalizedJPEGData(from: item)
            }
        }

        if let url = sharedURL {
            let host = url.host ?? "공유한 링크"
            return SharedClipPayload(
                type: .link,
                title: clean(attributedTitle, fallback: clean(sharedText, fallback: host, limit: 200), limit: 200),
                source: host,
                url: url.absoluteString,
                text: clean(sharedText, limit: 500)
            )
        }
        if imageData != nil {
            pendingImageData = imageData
            return SharedClipPayload(
                type: .image,
                title: clean(attributedTitle, fallback: "공유한 이미지", limit: 200),
                source: "사진",
                text: clean(sharedText, limit: 500)
            )
        }
        if let sharedText, !sharedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let firstLine = sharedText.split(separator: "\n", maxSplits: 1).first.map(String.init)
            return SharedClipPayload(
                type: .text,
                title: clean(attributedTitle, fallback: clean(firstLine, fallback: "공유한 텍스트", limit: 200), limit: 200),
                source: "공유 시트",
                text: clean(sharedText, limit: 500)
            )
        }
        return nil
    }

    private func loadItem(from provider: NSItemProvider, typeIdentifier: String) async throws -> NSSecureCoding? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: item)
                }
            }
        }
    }

    private func clean(_ value: String?, fallback: String = "", limit: Int) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : String(trimmed.prefix(limit))
    }

    private func normalizedJPEGData(from item: NSSecureCoding) -> Data? {
        let image: UIImage?
        if let uiImage = item as? UIImage {
            image = uiImage
        } else if let url = item as? URL {
            image = (try? Data(contentsOf: url)).flatMap(UIImage.init(data:))
        } else if let url = item as? NSURL {
            image = (try? Data(contentsOf: url as URL)).flatMap(UIImage.init(data:))
        } else if let data = item as? Data {
            image = UIImage(data: data)
        } else {
            image = nil
        }
        guard let image else { return nil }

        let maxDimension: CGFloat = 1_600
        let sourceMax = max(image.size.width, image.size.height)
        guard sourceMax > maxDimension else { return image.jpegData(compressionQuality: 0.82) }
        let scale = maxDimension / sourceMax
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: 0.82)
    }
}
