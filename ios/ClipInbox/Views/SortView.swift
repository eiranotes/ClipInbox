import SwiftUI

/// Sort Later 분류 플로우: 미정리 클립을 하나씩 추천 폴더로 정리한다.
struct SortView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var total = 0
    @State private var completed = 0
    @State private var choice = ""

    var body: some View {
        let unsorted = store.unsortedClips
        ScreenScaffold {
            ScreenHeader("분류하기", onBack: { dismiss() }) {
                Text("\(min(completed + (unsorted.isEmpty ? 0 : 1), max(total, 1)))/\(max(total, 1))")
                    .font(Tokens.chip)
                    .foregroundStyle(Tokens.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .tokenSurface(fill: Tokens.bgCardMuted, radius: Tokens.radiusChip,
                                  border: Tokens.borderSoft, borderWidth: Tokens.borderChipWidth)
            }

            if let clip = unsorted.first {
                sortCard(clip: clip)
            } else {
                BoardSection(title: "분류 완료") {
                    StatePanel(systemImage: "checkmark.circle",
                               title: "미정리 클립을 모두 분류했습니다",
                               message: "선택한 폴더에서 바로 확인할 수 있습니다.")
                }
                Button {
                    dismiss()
                } label: {
                    Label("인박스로 돌아가기", systemImage: "tray")
                }
                .buttonStyle(PrimaryBoxButtonStyle())
            }
        }
        .onAppear {
            total = store.unsortedClips.count
            completed = 0
            syncChoice()
        }
    }

    @ViewBuilder
    private func sortCard(clip: Clip) -> some View {
        let choices = sortChoices(for: clip)
        let selected = choices.contains(choice) ? choice : (choices.first ?? "기타")

        VStack(alignment: .leading, spacing: Tokens.detailGap) {
            if clip.hasImageReference {
                ClipThumbnail(clip: clip)
                    .frame(maxWidth: .infinity)
                    .frame(height: Tokens.detailImageHeight)
            }
            Text(clip.title)
                .font(Tokens.sectionTitle)
                .foregroundStyle(Tokens.textPrimary)
                .lineSpacing(Tokens.titleLineSpacing)
            Text(clip.source)
                .font(Tokens.meta)
                .foregroundStyle(Tokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        BoardSection(title: "추천 분류") {
            VStack(spacing: 0) {
                ForEach(choices, id: \.self) { option in
                    ActionRow(systemImage: "folder", label: option,
                              isSelected: selected == option) {
                        choice = option
                    }
                }
            }
        }

        Button {
            store.applySort(to: selected)
            completed += 1
            syncChoice()
        } label: {
            Text("\(selected.withRoParticle) 분류하고 다음")
        }
        .buttonStyle(PrimaryBoxButtonStyle())
    }

    private func sortChoices(for clip: Clip) -> [String] {
        var seen = Set<String>()
        var choices: [String] = []
        for suggestion in clip.folderSuggestions + ["기타"] {
            guard suggestion != "전체", !seen.contains(suggestion) else { continue }
            seen.insert(suggestion)
            choices.append(suggestion)
        }
        return Array(choices.prefix(4))
    }

    private func syncChoice() {
        choice = store.unsortedClips.first?.folderSuggestions.first ?? "디자인"
    }
}
