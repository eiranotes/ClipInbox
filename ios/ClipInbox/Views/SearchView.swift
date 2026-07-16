import SwiftUI

struct SearchView: View {
    @Environment(AppStore.self) private var store
    @Binding private var path: [Route]
    @State private var query = ""
    @State private var settledQuery = ""
    @State private var searchFilter: InboxFilter = .all
    @FocusState private var searchFieldFocused: Bool

    init(path: Binding<[Route]>) {
        _path = path
        #if DEBUG
        if ProcessInfo.processInfo.environment["CLIP_INBOX_ASO_CAPTURE"] == "1",
           let initialQuery = ProcessInfo.processInfo.environment["CLIP_INBOX_ASO_SEARCH_QUERY"] {
            _query = State(initialValue: initialQuery)
            _settledQuery = State(initialValue: initialQuery)
        }
        #endif
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Route.self) { route in
                    route.destination
                        .toolbar(.hidden, for: .navigationBar)
                        .swipeBackFromLeadingEdge()
                }
        }
    }

    private var content: some View {
        let results = store.searchResults(query: settledQuery, filter: searchFilter)
        return ScreenScaffold {
            ScreenHeader("검색")

            HStack(spacing: Tokens.rowGap) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Tokens.textSecondary)
                TextField("제목, 메모, 태그로 검색", text: $query)
                    .font(Tokens.body)
                    .submitLabel(.search)
                    .focused($searchFieldFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(recordCurrentSearch)
            }
            .padding(.horizontal, Tokens.cardPad)
            .frame(minHeight: Tokens.actionTarget)
            .tokenSurface(radius: Tokens.radiusInput)

            // 메인과 같은 정보 구조: 윗줄은 폴더, 아랫줄은 태그이며 각각 독립 스크롤한다.
            TwoRowHorizontalSelection(
                topRow: store.inboxFolderFilters.map { item in
                    (store.filterLabel(item), searchFilter == item, { searchFilter = item })
                },
                bottomRow: store.inboxTagFilters.map { item in
                    (store.filterLabel(item), searchFilter == item, { searchFilter = item })
                }
            )

            VStack(alignment: .leading, spacing: Tokens.rowGap) {
                Text("최근 검색")
                    .font(Tokens.sectionTitle)
                    .foregroundStyle(Tokens.textPrimary)
                VStack(spacing: 0) {
                    if store.recentSearches.isEmpty {
                        Text("아직 검색한 기록이 없습니다")
                            .font(Tokens.meta)
                            .foregroundStyle(Tokens.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: Tokens.actionTarget, alignment: .leading)
                            .overlay(alignment: .bottom) {
                                Tokens.borderSoft.frame(height: Tokens.borderChipWidth)
                            }
                    } else {
                        ForEach(store.recentSearches, id: \.self) { label in
                            PlainSelectionRow(label: label, isSelected: query == label) {
                                query = label
                                settledQuery = label
                                store.recordSearch(label)
                            }
                        }
                    }
                }
            }

            BoardSection(title: "검색 결과", count: results.count) {
                if results.isEmpty {
                    EmptyStateView(systemImage: "magnifyingglass",
                                   title: "검색 결과 없음",
                                   message: "제목, URL, 메모, 태그를 바꿔 다시 찾아보세요.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(results) { clip in
                            CompactResultRow(clip: clip) {
                                recordCurrentSearch()
                            }
                        }
                    }
                }
            }

        }
        .task(id: query) {
            guard query != settledQuery else { return }
            try? await Task.sleep(for: Tokens.searchDebounceDelay)
            guard !Task.isCancelled else { return }
            settledQuery = query
        }
        .onDisappear {
            searchFieldFocused = false
        }
    }

    private func recordCurrentSearch() {
        settledQuery = query
        store.recordSearch(query)
    }
}
