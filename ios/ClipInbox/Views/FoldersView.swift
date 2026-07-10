import SwiftUI

struct FoldersView: View {
    @Environment(AppStore.self) private var store
    @State private var showNewFolder = false

    var body: some View {
        ScreenScaffold {
            ScreenHeader("폴더", trailing: {
                UtilityIconButton(label: "새 폴더", systemImage: "plus") {
                    showNewFolder = true
                }
            })

            VStack(spacing: 0) {
                ForEach(store.folders) { folder in
                    NavigationLink(value: Route.folderDetail(folder.label)) {
                        HStack(spacing: Tokens.cardGap) {
                            Image(systemName: folder.systemImage)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Tokens.textPrimary)
                                .frame(width: Tokens.iconColumn, height: Tokens.chipTarget - Tokens.space1 / 2)
                            Text(folder.label)
                                .font(Tokens.bodySemibold)
                                .foregroundStyle(Tokens.textPrimary)
                            Spacer()
                            Text("\(store.folderCount(folder.label))")
                                .font(Tokens.meta)
                                .foregroundStyle(Tokens.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Tokens.textTertiary)
                        }
                        .padding(.horizontal, Tokens.space1)
                        .frame(minHeight: Tokens.actionTarget)
                        .contentShape(Rectangle())
                        .overlay(alignment: .bottom) {
                            Tokens.borderSoft.frame(height: Tokens.borderChipWidth)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: Tokens.bottomSafe - Tokens.sectionGap * 2)
        }
        .sheet(isPresented: $showNewFolder) {
            NewFolderSheet().workflowSheet()
        }
    }
}

// MARK: - 새 폴더

struct NewFolderSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var defaultTag = "디자인"
    @State private var errorMessage: String?

    private let tagOptions = DefaultData.suggestedTags

    var body: some View {
        ScreenScaffold {
            ScreenHeader("새 폴더", onBack: { dismiss() })

            BoardSection(title: "폴더 이름") {
                TextField("예: 읽을거리", text: $name)
                    .font(Tokens.body)
                    .padding(.horizontal, Tokens.cardPad)
                    .frame(minHeight: Tokens.actionTarget)
                    .tokenSurface(radius: Tokens.radiusInput)
                    .onChange(of: name) { errorMessage = nil }
            }

            BoardSection(title: "기본 태그") {
                TwoRowHorizontalSelection(items: tagOptions.map { tag in
                    (tag, defaultTag == tag, { defaultTag = tag })
                })
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(Tokens.metaBold)
                    .foregroundStyle(Tokens.danger)
            }

            Button {
                do {
                    _ = try store.createFolder(name: name, defaultTag: defaultTag)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
            } label: {
                Label("폴더 만들기", systemImage: "plus")
            }
            .buttonStyle(PrimaryBoxButtonStyle())
        }
    }
}

// MARK: - 폴더 상세

struct FolderDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let label: String
    @State private var showNewFolder = false

    var body: some View {
        let matches = store.folderClips(label)
        ScreenScaffold {
            ScreenHeader(label, onBack: { dismiss() }, trailing: {
                UtilityIconButton(label: "새 폴더", systemImage: "plus") {
                    showNewFolder = true
                }
            })

            BoardSection(title: "폴더 정보") {
                StatePanel(systemImage: "folder", title: label,
                           message: "\(matches.count)개 클립을 보관 중")
            }

            BoardSection(title: "클립", count: matches.count) {
                if matches.isEmpty {
                    EmptyStateView(title: "아직 클립이 없습니다",
                                   message: "클립을 이 폴더로 이동하면 여기에 표시됩니다.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(matches) { clip in
                            CompactResultRow(clip: clip)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showNewFolder) {
            NewFolderSheet().workflowSheet()
        }
    }
}
