import SwiftUI

/// 공유 확장 저장 플로우의 인앱 재현: 미리보기, 저장 위치, 태그, 메모, 저장.
struct AddClipView: View {
    @Environment(AppStore.self) private var store

    @State private var destination = ""
    @State private var tags = ["인테리어", "거실"]
    @State private var memo = ""
    @State private var saved = false
    @State private var saveError: String?
    @State private var showDestination = false
    @State private var showTagEditor = false

    var body: some View {
        ScreenScaffold {
            ScreenHeader("추가")

            VStack(alignment: .leading, spacing: Tokens.cardGap) {
                Image("clip-living-room")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: Tokens.detailImageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.radiusThumbnail, style: .continuous))
                TokenBadge(tone: .type(.link))
                Text("미니멀 인테리어 아이디어 모음 50")
                    .font(Tokens.cardTitle)
                    .foregroundStyle(Tokens.textPrimary)
                Text("brunch.co.kr")
                    .font(Tokens.meta)
                    .foregroundStyle(Tokens.textSecondary)
                Text("미리보기 생성 중에도 바로 저장할 수 있습니다")
                    .font(Tokens.meta)
                    .foregroundStyle(Tokens.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            BoardSection(title: "저장 위치") {
                Button {
                    showDestination = true
                } label: {
                    HStack(spacing: Tokens.rowGap + 4) {
                        Image(systemName: "tray")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Tokens.textPrimary)
                            .frame(width: Tokens.destinationIcon, height: Tokens.destinationIcon)
                            .tokenSurface(fill: Tokens.accentYellow, radius: Tokens.radiusButton)
                        Text(destination)
                            .font(Tokens.bodyBold)
                            .foregroundStyle(Tokens.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Tokens.textSecondary)
                    }
                    .padding(.horizontal, Tokens.cardPad)
                    .frame(minHeight: Tokens.actionTarget)
                    .tokenSurface(radius: Tokens.radiusInput)
                }
                .buttonStyle(.plain)
            }

            BoardSection(title: "태그") {
                ActionRow(systemImage: "tag", label: "선택한 태그",
                          value: tags.isEmpty ? "없음" : tags.joined(separator: " · ")) {
                    showTagEditor = true
                }
            }

            BoardSection(title: "메모") {
                TextEditor(text: $memo)
                    .font(Tokens.body)
                    .lineSpacing(Tokens.bodyLineSpacing)
                    .scrollContentBackground(.hidden)
                    .padding(Tokens.rowGap)
                    .frame(minHeight: 100)
                    .tokenSurface(radius: Tokens.radiusInput)
                    .overlay(alignment: .topLeading) {
                        if memo.isEmpty {
                            Text("메모를 입력하세요")
                                .font(Tokens.body)
                                .foregroundStyle(Tokens.textTertiary)
                                .padding(.top, Tokens.rowGap + 8)
                                .padding(.leading, Tokens.rowGap + 5)
                                .allowsHitTesting(false)
                        }
                    }
            }

            Button {
                guard !saved else { return }
                do {
                    _ = try store.saveNewClip(destination: destination, tags: tags, memo: memo)
                    saveError = nil
                    saved = true
                } catch {
                    saveError = error.localizedDescription
                }
            } label: {
                Text(saved
                     ? L10n.format("format.saved_in_folder", L10n.text(destination))
                     : L10n.format("format.save_to_folder", L10n.text(destination)))
            }
            .buttonStyle(PrimaryBoxButtonStyle())
            .disabled(saved)
            .opacity(saved ? 0.5 : 1)

            if let saveError {
                StatePanel(systemImage: "externaldrive.badge.exclamationmark",
                           title: "저장할 수 없습니다", message: saveError, isDanger: true)
            }

            if saved {
                Button {
                    resetDraft()
                } label: {
                    Text("새로 저장하기")
                }
                .buttonStyle(SecondaryBoxButtonStyle())
            }

            Spacer(minLength: Tokens.bottomSafe - Tokens.sectionGap * 2)
        }
        .onAppear {
            if destination.isEmpty { destination = store.preferences.defaultFolder }
        }
        .sheet(isPresented: $showDestination) {
            DestinationSheet(destination: $destination).workflowSheet(.expanded)
        }
        .sheet(isPresented: $showTagEditor) {
            TagEditorSheet(tags: $tags).workflowSheet(.standard)
        }
    }

    private func resetDraft() {
        saved = false
        destination = store.preferences.defaultFolder
        tags = ["인테리어", "거실"]
        memo = ""
        saveError = nil
    }
}

// MARK: - 저장 위치 선택

struct DestinationSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var destination: String

    var body: some View {
        ScreenScaffold {
            ScreenHeader("저장 위치", onBack: { dismiss() })

            BoardSection(title: "폴더 선택") {
                VStack(spacing: 0) {
                    ForEach(store.destinationFolders) { folder in
                        ActionRow(systemImage: folder.systemImage, label: folder.label,
                                  value: L10n.format("format.folder_clip_count", store.folderCount(folder.label)),
                                  isSelected: destination == folder.label) {
                            destination = folder.label
                        }
                    }
                }
            }

            Button {
                dismiss()
            } label: {
                Label("선택 완료", systemImage: "checkmark")
            }
            .buttonStyle(PrimaryBoxButtonStyle())
        }
    }
}

// MARK: - 태그 편집

struct TagEditorSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var tags: [String]
    @State private var newTag = ""

    private var tagOptions: [String] {
        var seen = Set<String>()
        return (tags + store.availableTags).filter { seen.insert($0).inserted }
    }

    var body: some View {
        ScreenScaffold(dismissKeyboardOnBackgroundTap: false) {
            ScreenHeader("태그 편집", onBack: { dismiss() })

            BoardSection(title: "태그 선택", count: tags.count) {
                TwoRowHorizontalSelection(items: tagOptions.map { tag in
                    (tag, tags.contains(tag), {
                            if tags.contains(tag) {
                                tags.removeAll { $0 == tag }
                            } else if tags.count < 12 {
                                tags.append(tag)
                            }
                    })
                })
            }

            BoardSection(title: "직접 입력") {
                HStack(spacing: Tokens.rowGap) {
                    TextField("새 태그", text: $newTag)
                        .font(Tokens.body)
                        .padding(.horizontal, Tokens.cardPad)
                        .frame(minHeight: Tokens.chipTarget + 4)
                        .tokenSurface(radius: Tokens.radiusInput)
                        .onSubmit(addNewTag)
                    Button(action: addNewTag) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Tokens.textPrimary)
                            .frame(width: Tokens.touchTarget, height: Tokens.touchTarget)
                            .tokenSurface(fill: Tokens.accentYellow, radius: Tokens.radiusButton)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("태그 추가")
                }
            }

            Button {
                dismiss()
            } label: {
                Label("태그 적용", systemImage: "checkmark")
            }
            .buttonStyle(PrimaryBoxButtonStyle())
        }
    }

    private func addNewTag() {
        let tag = AppStore.cleanText(newTag, maxLength: 50)
        guard !tag.isEmpty, tags.count < 12 else { return }
        let canonical = store.availableTags.first {
            $0.caseInsensitiveCompare(tag) == .orderedSame
        } ?? (try? store.addTag(tag))
        guard let canonical, !tags.contains(canonical) else { return }
        tags.append(canonical)
        newTag = ""
    }
}
