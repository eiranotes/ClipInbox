import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController, UIGestureRecognizerDelegate {
    private var configuration = SharedClipConfiguration.standard
    private var pendingImageAsset: SharedImageAsset?
    private var pendingPayload: SharedClipPayload?
    private var selectedFolder = ""
    private var hasStarted = false

    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let statusLabel = UILabel()
    private let statusIcon = UIImageView()
    private let statusCard = UIView()
    private let memoTextView = UITextView()
    private let folderButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)

    private enum ShareError: LocalizedError {
        case missingPayload

        var errorDescription: String? {
            SharedL10n.text("공유한 링크, 텍스트 또는 이미지를 읽을 수 없습니다.")
        }
    }

    // DESIGN.md: bg.app/card, accent.yellow/green, border.soft, text.primary/secondary.
    private enum Palette {
        static let bgApp = adaptive(light: 0xF3EFE7, dark: 0x171714)
        static let bgCard = adaptive(light: 0xFFFFFF, dark: 0x2B2924)
        static let accentYellow = adaptive(light: 0xFFD900, dark: 0xF4D21F)
        static let accentGreen = adaptive(light: 0x9BE7B0, dark: 0x68C982)
        static let borderSoft = adaptive(light: 0xD8D1C4, dark: 0x44413B)
        static let textPrimary = adaptive(light: 0x171714, dark: 0xF4F1E9)
        static let textSecondary = adaptive(light: 0x5F6368, dark: 0xB5B1A8)

        private static func adaptive(light: UInt32, dark: UInt32) -> UIColor {
            UIColor { traits in
                let value = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(
                    red: CGFloat((value >> 16) & 0xFF) / 255,
                    green: CGFloat((value >> 8) & 0xFF) / 255,
                    blue: CGFloat(value & 0xFF) / 255,
                    alpha: 1
                )
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configuration = SharedClipQueue.loadConfiguration()
        selectedFolder = configuration.defaultFolder
        switch configuration.theme {
        case "라이트": overrideUserInterfaceStyle = .light
        case "다크": overrideUserInterfaceStyle = .dark
        default: overrideUserInterfaceStyle = .unspecified
        }
        modalPresentationStyle = configuration.saveMode == .quick ? .overFullScreen : .formSheet
        view.backgroundColor = .clear
        view.isOpaque = false

        let dismissKeyboardTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissKeyboardTap.cancelsTouchesInView = false
        dismissKeyboardTap.delegate = self
        view.addGestureRecognizer(dismissKeyboardTap)

        switch configuration.saveMode {
        case .quick:
            preferredContentSize = CGSize(width: 280, height: 92)
            configureCompactStatus()
        case .review:
            preferredContentSize = CGSize(width: 0, height: 390)
            configureReviewLoadingState()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        clearHostBackgrounds()
        guard !hasStarted else { return }
        hasStarted = true
        Task { @MainActor in
            do {
                guard let payload = await loadPayload() else { throw ShareError.missingPayload }
                pendingPayload = payload
                switch configuration.saveMode {
                case .quick:
                    await saveAndComplete(payload)
                case .review:
                    configureReviewForm(payload)
                }
            } catch {
                showFailure(error)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        clearHostBackgrounds()
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        clearHostBackgrounds()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        clearHostBackgrounds()
    }

    private func localized(_ key: String) -> String {
        SharedL10n.text(key, language: configuration.language)
    }

    private func font(size: CGFloat, semibold: Bool = false) -> UIFont {
        let name = semibold ? "Pretendard-SemiBold" : "Pretendard-Regular"
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: semibold ? .semibold : .regular)
    }

    /// Quick mode paints only one compact card. The extension host remains transparent.
    private func configureCompactStatus() {
        statusCard.subviews.forEach { $0.removeFromSuperview() }
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
        activityIndicator.color = Palette.textPrimary
        statusIcon.image = UIImage(systemName: "checkmark.circle.fill")
        statusIcon.tintColor = Palette.textPrimary
        statusIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        statusIcon.isHidden = true
        statusLabel.text = localized("Clip Inbox에 저장하는 중…")
        statusLabel.font = font(size: 15)
        statusLabel.textColor = Palette.textPrimary

        let content = UIStackView(arrangedSubviews: [statusIcon, activityIndicator, statusLabel])
        content.axis = .horizontal
        content.alignment = .center
        content.spacing = 8
        content.translatesAutoresizingMaskIntoConstraints = false

        statusCard.backgroundColor = Palette.bgCard
        statusCard.layer.cornerRadius = 10
        statusCard.layer.cornerCurve = .continuous
        statusCard.layer.borderWidth = 1
        statusCard.layer.borderColor = Palette.borderSoft.cgColor
        statusCard.translatesAutoresizingMaskIntoConstraints = false
        statusCard.addSubview(content)
        view.addSubview(statusCard)

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: statusCard.topAnchor, constant: 12),
            content.bottomAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: -12),
            content.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: statusCard.trailingAnchor, constant: -16),
            statusCard.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusCard.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusCard.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
            statusCard.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            statusCard.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func configureReviewLoadingState() {
        configureCompactStatus()
        statusLabel.text = localized("공유할 클립")
    }

    @MainActor
    private func configureReviewForm(_ payload: SharedClipPayload) {
        statusCard.removeFromSuperview()
        activityIndicator.stopAnimating()

        let container = UIView()
        container.backgroundColor = Palette.bgApp
        container.layer.cornerRadius = 12
        container.layer.cornerCurve = .continuous
        container.layer.borderWidth = 1
        container.layer.borderColor = Palette.borderSoft.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false

        let heading = UILabel()
        heading.text = localized("폴더와 메모 확인")
        heading.font = font(size: 18, semibold: true)
        heading.textColor = Palette.textPrimary

        let clipTitle = UILabel()
        clipTitle.text = payload.title
        clipTitle.font = font(size: 13)
        clipTitle.textColor = Palette.textSecondary
        clipTitle.numberOfLines = 1
        clipTitle.lineBreakMode = .byTruncatingTail

        let folderLabel = fieldLabel(localized("저장할 폴더"))
        configureFolderButton()

        let memoLabel = fieldLabel(localized("메모 (선택)"))
        memoTextView.font = font(size: 15)
        memoTextView.textColor = Palette.textPrimary
        memoTextView.backgroundColor = Palette.bgCard
        memoTextView.layer.cornerRadius = 8
        memoTextView.layer.cornerCurve = .continuous
        memoTextView.layer.borderWidth = 1
        memoTextView.layer.borderColor = Palette.borderSoft.cgColor
        memoTextView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        memoTextView.heightAnchor.constraint(equalToConstant: 82).isActive = true

        var saveConfiguration = UIButton.Configuration.filled()
        saveConfiguration.title = localized("클립 저장")
        saveConfiguration.image = UIImage(systemName: "checkmark")
        saveConfiguration.imagePadding = 8
        saveConfiguration.baseBackgroundColor = Palette.accentYellow
        saveConfiguration.baseForegroundColor = Palette.textPrimary
        saveConfiguration.cornerStyle = .fixed
        saveConfiguration.background.cornerRadius = 10
        saveButton.configuration = saveConfiguration
        saveButton.titleLabel?.font = font(size: 16, semibold: true)
        saveButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        saveButton.addTarget(self, action: #selector(saveReviewedClip), for: .touchUpInside)

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle(localized("취소"), for: .normal)
        cancelButton.setTitleColor(Palette.textSecondary, for: .normal)
        cancelButton.titleLabel?.font = font(size: 15)
        cancelButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        cancelButton.addTarget(self, action: #selector(cancelShare), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [heading, clipTitle, folderLabel, folderButton,
                                                   memoLabel, memoTextView, saveButton, cancelButton])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(16, after: clipTitle)
        stack.setCustomSpacing(12, after: folderButton)
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        view.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])
    }

    private func fieldLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font(size: 13, semibold: true)
        label.textColor = Palette.textPrimary
        return label
    }

    private func configureFolderButton() {
        let folders = configuration.folders.isEmpty ? [configuration.defaultFolder] : configuration.folders
        if !folders.contains(selectedFolder) { selectedFolder = folders.first ?? configuration.defaultFolder }

        var buttonConfiguration = UIButton.Configuration.plain()
        buttonConfiguration.title = localized(selectedFolder)
        buttonConfiguration.image = UIImage(systemName: "folder")
        buttonConfiguration.imagePadding = 8
        buttonConfiguration.baseForegroundColor = Palette.textPrimary
        buttonConfiguration.background.backgroundColor = Palette.bgCard
        buttonConfiguration.background.strokeColor = Palette.borderSoft
        buttonConfiguration.background.strokeWidth = 1
        buttonConfiguration.background.cornerRadius = 8
        buttonConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        folderButton.configuration = buttonConfiguration
        folderButton.contentHorizontalAlignment = .leading
        if folderButton.constraints.first(where: { $0.firstAttribute == .height }) == nil {
            folderButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        }
        folderButton.showsMenuAsPrimaryAction = true
        folderButton.menu = UIMenu(children: folders.map { folder in
            UIAction(title: localized(folder), state: folder == selectedFolder ? .on : .off) { [weak self] _ in
                guard let self else { return }
                selectedFolder = folder
                configureFolderButton()
            }
        })
    }

    @objc private func saveReviewedClip() {
        guard let payload = pendingPayload else { return }
        saveButton.isEnabled = false
        memoTextView.resignFirstResponder()
        var reviewed = payload
        reviewed.folder = selectedFolder
        reviewed.memo = memoTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { @MainActor in await saveAndComplete(reviewed) }
    }

    @objc private func cancelShare() {
        extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }

    @MainActor
    private func saveAndComplete(_ item: SharedClipPayload) async {
        var newlyStoredImageName: String?
        do {
            let sharedImageName: String?
            if let pendingImageAsset {
                sharedImageName = try SharedClipQueue.storeImageAsset(pendingImageAsset, for: item.id)
                newlyStoredImageName = sharedImageName
            } else {
                sharedImageName = item.sharedImageName
            }
            var finalPayload = item
            finalPayload.sharedImageName = sharedImageName
            if finalPayload.folder.isEmpty { finalPayload.folder = configuration.defaultFolder }
            try SharedClipQueue.enqueue(finalPayload)
            showSavedConfirmation()
            try? await Task.sleep(for: .milliseconds(2_000))
            extensionContext?.completeRequest(returningItems: nil)
        } catch {
            if let newlyStoredImageName { try? SharedClipQueue.removeImage(named: newlyStoredImageName) }
            showFailure(error)
        }
    }

    @MainActor
    private func showSavedConfirmation() {
        view.subviews.forEach { $0.removeFromSuperview() }
        configureCompactStatus()
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        statusIcon.isHidden = false
        statusLabel.text = localized("Clip Inbox에 저장됨")
        statusLabel.font = font(size: 15, semibold: true)
        statusCard.backgroundColor = Palette.accentGreen
        statusCard.alpha = 0
        UIView.animate(withDuration: 0.18) { self.statusCard.alpha = 1 }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var candidate = touch.view
        while let view = candidate {
            if view is UITextField || view is UITextView { return false }
            candidate = view.superview
        }
        return true
    }

    private func clearHostBackgrounds() {
        guard configuration.saveMode == .quick else { return }
        var ancestor: UIView? = view
        while let current = ancestor {
            current.backgroundColor = .clear
            current.isOpaque = false
            ancestor = current.superview
        }
        presentationController?.presentedView?.backgroundColor = .clear
        presentationController?.presentedView?.isOpaque = false
        presentationController?.containerView?.backgroundColor = .clear
        presentationController?.containerView?.isOpaque = false
        navigationController?.view.backgroundColor = .clear
        navigationController?.view.isOpaque = false
    }

    @MainActor
    private func showFailure(_ error: Error) {
        activityIndicator.stopAnimating()
        statusLabel.text = localized("저장할 수 없습니다")
        let alert = UIAlertController(title: localized("저장할 수 없습니다"),
                                      message: error.localizedDescription,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: localized("닫기"), style: .default) { [weak self] _ in
            self?.extensionContext?.cancelRequest(withError: error)
        })
        present(alert, animated: true)
    }

    private func loadPayload() async -> SharedClipPayload? {
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        let attributedTitle = items.compactMap(\.attributedTitle?.string).first
        let attributedText = items.compactMap(\.attributedContentText?.string).first
        let providers = items.flatMap { $0.attachments ?? [] }

        // Photos와 일부 이미지 앱은 이미지와 파일 URL을 함께 제공한다. 이미지
        // provider가 하나라도 있으면 먼저 원본 이미지 표현을 읽어 URL 클립으로
        // 잘못 저장하지 않는다.
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            if let imageAsset = await loadImageAsset(from: provider) {
                pendingImageAsset = imageAsset
                return SharedClipPayload(type: .image,
                                         title: clean(attributedTitle, fallback: localized("공유한 이미지"), limit: 200),
                                         source: localized("사진"), text: clean(attributedText, limit: 500),
                                         folder: configuration.defaultFolder)
            }
        }

        var sharedURL: URL?
        var sharedText = attributedText

        for provider in providers {
            if sharedURL == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let item = try? await loadItem(from: provider, typeIdentifier: UTType.url.identifier) {
                sharedURL = item as? URL ?? (item as? NSURL).map { $0 as URL }
            }
            if sharedText == nil, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
               let item = try? await loadItem(from: provider, typeIdentifier: UTType.plainText.identifier) {
                sharedText = item as? String ?? (item as? NSString).map { String($0) }
            }
        }

        if let url = sharedURL {
            let host = url.host ?? localized("공유한 링크")
            return SharedClipPayload(type: .link,
                                     title: clean(attributedTitle, fallback: clean(sharedText, fallback: host, limit: 200), limit: 200),
                                     source: host, url: url.absoluteString,
                                     text: clean(sharedText, limit: 500),
                                     folder: configuration.defaultFolder)
        }
        if let sharedText, !sharedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let firstLine = sharedText.split(separator: "\n", maxSplits: 1).first.map(String.init)
            return SharedClipPayload(type: .text,
                                     title: clean(attributedTitle,
                                                  fallback: clean(firstLine, fallback: localized("공유한 텍스트"), limit: 200),
                                                  limit: 200),
                                     source: localized("공유 시트"), text: clean(sharedText, limit: 500),
                                     folder: configuration.defaultFolder)
        }
        return nil
    }

    private func loadItem(from provider: NSItemProvider, typeIdentifier: String) async throws -> NSSecureCoding? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: item) }
            }
        }
    }

    private func clean(_ value: String?, fallback: String = "", limit: Int) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : String(trimmed.prefix(limit))
    }

    private func loadImageAsset(from provider: NSItemProvider) async -> SharedImageAsset? {
        let imageIdentifiers = provider.registeredTypeIdentifiers
            .filter { UTType($0)?.conforms(to: .image) == true }
        // provider의 선호 순서는 유지하되 추상 public.image만 마지막으로 미룬다.
        let identifiers = imageIdentifiers.filter { UTType($0) != .image }
            + imageIdentifiers.filter { UTType($0) == .image }

        for identifier in identifiers {
            if let data = try? await loadDataRepresentation(from: provider, typeIdentifier: identifier),
               let asset = SharedImageAsset(data: data, typeIdentifier: identifier) {
                return asset
            }
        }

        guard let item = try? await loadItem(from: provider, typeIdentifier: UTType.image.identifier) else {
            return nil
        }
        let typeIdentifier = identifiers.first
        if let url = item as? URL, let data = try? Data(contentsOf: url) {
            return SharedImageAsset(data: data,
                                    typeIdentifier: typeIdentifier,
                                    suggestedFileExtension: url.pathExtension)
        }
        if let url = item as? NSURL, let data = try? Data(contentsOf: url as URL) {
            return SharedImageAsset(data: data,
                                    typeIdentifier: typeIdentifier,
                                    suggestedFileExtension: (url as URL).pathExtension)
        }
        if let data = item as? Data {
            return SharedImageAsset(data: data, typeIdentifier: typeIdentifier)
        }
        if let image = item as? UIImage, let data = image.pngData() {
            return SharedImageAsset(data: data, typeIdentifier: UTType.png.identifier)
        }
        return nil
    }

    private func loadDataRepresentation(from provider: NSItemProvider, typeIdentifier: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let error { continuation.resume(throwing: error) }
                else if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: ShareError.missingPayload) }
            }
        }
    }
}
