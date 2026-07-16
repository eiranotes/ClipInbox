import Foundation
import Observation

extension PresentationLanguage {
    /// SwiftUI locale 환경값을 표시 언어로 변환한다.
    static func presentation(for locale: Locale) -> PresentationLanguage {
        switch locale.language.languageCode?.identifier {
        case "en": return .english
        case "ja": return .japanese
        default: return .korean
        }
    }
}

@MainActor
@Observable
final class URLMetadataCoordinator {
    private(set) var results: [Int: LinkMetadataResult] = [:]
    private(set) var activeClipIDs: Set<Int> = []
    private(set) var lastError: String?

    @ObservationIgnored private let sidecar: LinkMetadataSidecarStore
    @ObservationIgnored private let configuration: MetadataConfiguration
    @ObservationIgnored private let engine: URLMetadataEngine
    @ObservationIgnored private var loaded = false
    @ObservationIgnored private var synchronizationTask: Task<Void, Never>?

    init(
        configuration: MetadataConfiguration = .default,
        sidecar: LinkMetadataSidecarStore = LinkMetadataSidecarStore()
    ) {
        self.sidecar = sidecar
        self.configuration = configuration
        let cacheURL = LinkMetadataSidecarStore.defaultDirectory().appendingPathComponent("canonical-cache-v1.json")
        self.engine = URLMetadataEngine(
            configuration: configuration,
            normalizer: URLNormalizer(),
            inspector: URLSessionHTTPInspector(),
            cache: DiskMetadataCache(fileURL: cacheURL),
            renderer: WKWebViewMetadataRenderer(),
            registry: PlatformRegistry()
        )
    }

    func result(for clipID: Int) -> LinkMetadataResult? {
        results[clipID]
    }

    func isAnalyzing(_ clipID: Int) -> Bool {
        activeClipIDs.contains(clipID)
    }

    func cardPresentation(for clip: Clip, locale: Locale = Locale(identifier: "ko")) -> MainCardPresentation? {
        guard let result = results[clip.id] else { return nil }
        var card = PresentationBuilder(language: .presentation(for: locale)).mainCard(from: result)
        if let repository = AppStore.githubRepositoryTitle(for: clip.url) {
            card.title = repository
        } else if !AppStore.isMetadataPlaceholderTitle(clip.title, url: clip.url) {
            card.title = clip.title
        }
        return card
    }

    func cardTitle(for clip: Clip, locale: Locale = Locale(identifier: "ko")) -> String {
        cardPresentation(for: clip, locale: locale)?.title ?? clip.presentationTitle
    }

    /// 메인 카드 보조 줄: 결정적 짧은 요약을 우선하고, 없으면 카드 부제로 대체한다.
    func cardSummary(for clip: Clip, locale: Locale = Locale(identifier: "ko")) -> String? {
        guard let result = results[clip.id] else { return nil }
        if let summary = result.summaryShort?.value, !summary.isEmpty { return summary }
        let subtitle = PresentationBuilder(language: .presentation(for: locale)).mainCard(from: result).subtitle
        return subtitle.isEmpty ? nil : subtitle
    }

    func synchronize(store: AppStore) {
        guard synchronizationTask == nil else { return }
        synchronizationTask = Task { @MainActor [weak self, weak store] in
            guard let self, let store else { return }
            defer { self.synchronizationTask = nil }
            await self.loadSidecarIfNeeded(validClipIDs: Set(store.clips.map(\.id)))
            let clips = store.clips.filter { $0.type == .link && !$0.url.isEmpty && $0.deletedAt == nil }
            for clip in clips where !Task.isCancelled {
                if await self.needsAnalysis(clip) {
                    await self.analyze(clip: clip, store: store, forceRefresh: false)
                }
            }
        }
    }

    func analyze(clip: Clip, store: AppStore, forceRefresh: Bool) async {
        guard clip.type == .link,
              let url = URL(string: clip.url),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        guard !activeClipIDs.contains(clip.id) else { return }

        activeClipIDs.insert(clip.id)
        defer { activeClipIDs.remove(clip.id) }
        let result = await engine.analyze(clip.url, forceRefresh: forceRefresh)
        results[clip.id] = result
        do {
            try await sidecar.store(result, clipID: clip.id, sourceURL: clip.url)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        store.applyExtractedMetadata(result, to: clip.id)
    }

    /// 설정 화면이나 마이그레이션 도구에서 호출할 수 있는 명시적 backfill 진입점.
    func backfillAll(store: AppStore, forceRefresh: Bool = false) async {
        await loadSidecarIfNeeded(validClipIDs: Set(store.clips.map(\.id)))
        for clip in store.clips where clip.type == .link && !clip.url.isEmpty && clip.deletedAt == nil {
            await analyze(clip: clip, store: store, forceRefresh: forceRefresh)
        }
    }

    func removeMetadata(for clipID: Int) async {
        results[clipID] = nil
        try? await sidecar.remove(clipID: clipID)
    }

    private func loadSidecarIfNeeded(validClipIDs: Set<Int>) async {
        guard !loaded else { return }
        loaded = true
        results = await sidecar.all()
        do {
            try await sidecar.prune(validClipIDs: validClipIDs)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func needsAnalysis(_ clip: Clip) async -> Bool {
        guard let entry = await sidecar.entry(for: clip.id) else { return true }
        guard entry.sourceURL == clip.url else { return true }
        let age = Date().timeIntervalSince(entry.updatedAt)
        return age > configuration.cacheTTL
    }
}
