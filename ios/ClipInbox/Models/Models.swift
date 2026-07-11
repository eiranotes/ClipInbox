import Foundation

// 웹 프로토타입의 version 2 JSON 백업과 키·값이 그대로 호환되어야 한다.
// 필드를 추가/변경할 때는 scripts/qa.mjs 쪽 normalizeData와 함께 맞춘다.

enum ClipType: String, Codable, CaseIterable {
    case link, image, memo, screenshot

    var label: String {
        switch self {
        case .link: return "링크"
        case .image: return "이미지"
        case .memo: return "메모"
        case .screenshot: return "스크린샷"
        }
    }

    var systemImage: String {
        switch self {
        case .link: return "arrow.up.right.square"
        case .image: return "photo"
        case .memo: return "note.text"
        case .screenshot: return "camera"
        }
    }
}

enum ClipState: String, Codable {
    case unsorted, new, saved

    var label: String {
        switch self {
        case .unsorted: return "미정리"
        case .new: return "신규"
        case .saved: return "저장됨"
        }
    }
}

struct Clip: Identifiable, Codable, Equatable {
    var id: Int
    var type: ClipType
    var state: ClipState?
    var title: String
    var source: String
    var url: String
    var time: String
    var folder: String
    var tags: [String]
    var folderSuggestions: [String]
    var image: String?
    var sharedImageName: String?
    var description: String
    var memo: String?
    var bookmarked: Bool

    init(id: Int, type: ClipType, state: ClipState? = nil, title: String, source: String,
         url: String, time: String, folder: String, tags: [String] = [],
         folderSuggestions: [String] = [], image: String? = nil, sharedImageName: String? = nil,
         description: String = "",
         memo: String? = nil, bookmarked: Bool = false) {
        self.id = id
        self.type = type
        self.state = state
        self.title = title
        self.source = source
        self.url = url
        self.time = time
        self.folder = folder
        self.tags = tags
        self.folderSuggestions = folderSuggestions
        self.image = image
        self.sharedImageName = sharedImageName
        self.description = description
        self.memo = memo
        self.bookmarked = bookmarked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        type = (try? container.decode(ClipType.self, forKey: .type)) ?? .link
        state = try? container.decodeIfPresent(ClipState.self, forKey: .state)
        title = (try? container.decode(String.self, forKey: .title)) ?? "제목 없는 클립"
        source = (try? container.decodeIfPresent(String.self, forKey: .source)) ?? "출처 없음"
        url = (try? container.decodeIfPresent(String.self, forKey: .url)) ?? ""
        time = (try? container.decodeIfPresent(String.self, forKey: .time)) ?? "저장됨"
        folder = (try? container.decodeIfPresent(String.self, forKey: .folder)) ?? "기본 폴더"
        tags = (try? container.decodeIfPresent([String].self, forKey: .tags)) ?? []
        folderSuggestions = (try? container.decodeIfPresent([String].self, forKey: .folderSuggestions)) ?? []
        image = try? container.decodeIfPresent(String.self, forKey: .image)
        sharedImageName = try? container.decodeIfPresent(String.self, forKey: .sharedImageName)
        description = (try? container.decodeIfPresent(String.self, forKey: .description)) ?? ""
        memo = try? container.decodeIfPresent(String.self, forKey: .memo)
        bookmarked = (try? container.decodeIfPresent(Bool.self, forKey: .bookmarked)) ?? false
    }

    /// 웹 백업의 "/public/images/clip-beach.png" 경로를 에셋 카탈로그 이름으로 매핑한다.
    var imageAssetName: String? {
        guard let image, !image.isEmpty else { return nil }
        let base = (image as NSString).lastPathComponent
        let name = (base as NSString).deletingPathExtension
        return name.isEmpty ? nil : name
    }

    var sharedImageURL: URL? {
        guard let sharedImageName else { return nil }
        return SharedClipQueue.imageURL(named: sharedImageName)
    }

    var hasImageReference: Bool {
        image?.isEmpty == false || sharedImageName?.isEmpty == false
    }
}

struct Folder: Identifiable, Codable, Equatable {
    var icon: String
    var label: String
    var defaultTag: String?

    var id: String { label }

    var systemImage: String {
        switch icon {
        case "archive": return "archivebox"
        case "inbox": return "tray"
        case "bookmark": return "bookmark"
        case "globe": return "globe"
        case "file": return "doc"
        case "note": return "note.text"
        default: return "folder"
        }
    }
}

/// 웹 프로토타입과 동일한 키("app-lock", "default-folder")로 인코딩된다.
struct Preferences: Codable, Equatable {
    var appLock: String
    var theme: String
    var language: String
    var defaultFolder: String
    var shareMode: String

    enum CodingKeys: String, CodingKey {
        case appLock = "app-lock"
        case theme
        case language
        case defaultFolder = "default-folder"
        case shareMode = "share-mode"
    }

    static let standard = Preferences(appLock: "끔", theme: "라이트", language: "한국어",
                                      defaultFolder: "기본 폴더", shareMode: SharedSaveMode.quick.rawValue)

    init(appLock: String, theme: String, language: String, defaultFolder: String,
         shareMode: String = SharedSaveMode.quick.rawValue) {
        self.appLock = appLock
        self.theme = theme
        self.language = language
        self.defaultFolder = defaultFolder
        self.shareMode = shareMode
    }

    init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        appLock = (try? container?.decodeIfPresent(String.self, forKey: .appLock)) ?? Self.standard.appLock
        theme = (try? container?.decodeIfPresent(String.self, forKey: .theme)) ?? Self.standard.theme
        language = (try? container?.decodeIfPresent(String.self, forKey: .language)) ?? Self.standard.language
        defaultFolder = (try? container?.decodeIfPresent(String.self, forKey: .defaultFolder)) ?? Self.standard.defaultFolder
        shareMode = (try? container?.decodeIfPresent(String.self, forKey: .shareMode)) ?? Self.standard.shareMode
    }
}

struct DataSnapshot: Codable {
    var version: Int
    var clips: [Clip]
    var folders: [Folder]
    var preferences: Preferences
}

extension String {
    /// 마지막 글자의 받침 유무에 맞는 "로/으로" 조사를 붙인다.
    /// 받침이 없거나 ㄹ 받침이면 "로", 그 외 받침은 "으로", 한글이 아니면 "로"를 쓴다.
    var withRoParticle: String {
        guard let scalar = unicodeScalars.last?.value, (0xAC00...0xD7A3).contains(scalar) else {
            return self + "로"
        }
        let finalConsonant = (scalar - 0xAC00) % 28
        return self + ((finalConsonant == 0 || finalConsonant == 8) ? "로" : "으로")
    }
}

enum DefaultData {
    static let filterTags = ["인테리어", "레퍼런스", "아이디어", "여행"]
    static let suggestedTags = [
        "인테리어", "거실", "미니멀", "레퍼런스", "아이디어",
        "나중에", "UI/UX", "업무", "여행", "읽을거리"
    ]

    static let clips: [Clip] = [
        Clip(id: 1, type: .link, state: .unsorted,
             title: "미니멀 거실 인테리어 참고", source: "m.blog.naver.com", url: "https://m.blog.naver.com",
             time: "2시간 전", folder: "폴더 2", tags: ["인테리어", "거실", "미니멀"],
             folderSuggestions: ["폴더 2", "폴더 3", "나중에"], image: "/public/images/clip-living-room.png",
             description: "밝은 거실 레이아웃과 제품 상세 페이지에 맞는 무드 참고.",
             memo: "썸네일 비율과 여백이 좋아서 홈 섹션 이미지 참고로 보관."),
        Clip(id: 2, type: .image,
             title: "모바일 대시보드 UI 레퍼런스", source: "Pinterest", url: "https://www.pinterest.com",
             time: "5시간 전", folder: "폴더 3", tags: ["UI/UX", "대시보드", "레퍼런스"],
             folderSuggestions: ["폴더 3", "폴더 2", "폴더 4"], image: "/public/images/clip-dashboard.png",
             description: "카드 밀도와 차트 영역 구성을 보기 위한 이미지 저장."),
        Clip(id: 3, type: .memo, state: .new,
             title: "신규 제품 소개 문구 아이디어", source: "나의 메모", url: "",
             time: "어제", folder: "폴더 4", tags: ["카피라이팅", "제품소개", "아이디어"],
             folderSuggestions: ["폴더 4", "폴더 3"], image: "/public/images/clip-lightbulb.png",
             description: "짧은 첫 문장, 보관 이유, 다음 행동을 한 카드에 담기."),
        Clip(id: 4, type: .link,
             title: "주말 강릉 여행 코스", source: "visitgangneung.net", url: "https://www.gn.go.kr/tour",
             time: "어제", folder: "폴더 5", tags: ["여행", "강릉", "코스"],
             folderSuggestions: ["폴더 5", "나중에"], image: "/public/images/clip-beach.png",
             description: "친구에게 공유할 후보 일정. 나중에 폴더에서 정리."),
        Clip(id: 5, type: .screenshot, state: .unsorted,
             title: "메타데이터 없는 상품 이미지", source: "product-store.co.kr", url: "https://product-store.co.kr",
             time: "3일 전", folder: "폴더 1", tags: ["스크린샷", "확인필요"],
             folderSuggestions: ["폴더 1", "나중에"],
             description: "미리보기 이미지를 못 받았지만 저장 자체는 완료된 상태.")
    ]

    static let folders: [Folder] = [
        Folder(icon: "archive", label: "전체"),
        Folder(icon: "inbox", label: "기본 폴더"),
        Folder(icon: "folder", label: "폴더 1"),
        Folder(icon: "folder", label: "폴더 2"),
        Folder(icon: "folder", label: "폴더 3"),
        Folder(icon: "folder", label: "폴더 4"),
        Folder(icon: "folder", label: "폴더 5")
    ]
}
