const defaultClips = [
  {
    id: 1,
    type: "link",
    state: "unsorted",
    title: "미니멀 거실 인테리어 참고",
    source: "m.blog.naver.com",
    url: "https://m.blog.naver.com",
    time: "2시간 전",
    folder: "디자인",
    tags: ["인테리어", "거실", "미니멀"],
    folderSuggestions: ["디자인", "인테리어", "나중에"],
    image: "/public/images/clip-living-room.png",
    description: "밝은 거실 레이아웃과 제품 상세 페이지에 맞는 무드 참고.",
    memo: "썸네일 비율과 여백이 좋아서 홈 섹션 이미지 참고로 보관."
  },
  {
    id: 2,
    type: "image",
    title: "모바일 대시보드 UI 레퍼런스",
    source: "Pinterest",
    url: "https://www.pinterest.com",
    time: "5시간 전",
    folder: "디자인",
    tags: ["UI/UX", "대시보드", "레퍼런스"],
    folderSuggestions: ["디자인", "UI", "업무"],
    image: "/public/images/clip-dashboard.png",
    description: "카드 밀도와 차트 영역 구성을 보기 위한 이미지 저장."
  },
  {
    id: 3,
    type: "memo",
    state: "new",
    title: "신규 제품 소개 문구 아이디어",
    source: "나의 메모",
    url: "",
    time: "어제",
    folder: "아이디어",
    tags: ["카피라이팅", "제품소개", "아이디어"],
    folderSuggestions: ["업무", "아이디어"],
    image: "/public/images/clip-lightbulb.png",
    description: "짧은 첫 문장, 보관 이유, 다음 행동을 한 카드에 담기."
  },
  {
    id: 4,
    type: "link",
    title: "주말 강릉 여행 코스",
    source: "visitgangneung.net",
    url: "https://www.gn.go.kr/tour",
    time: "어제",
    folder: "여행",
    tags: ["여행", "강릉", "코스"],
    folderSuggestions: ["여행", "나중에"],
    image: "/public/images/clip-beach.png",
    description: "친구에게 공유할 후보 일정. 나중에 폴더에서 정리."
  },
  {
    id: 5,
    type: "screenshot",
    state: "unsorted",
    title: "메타데이터 없는 상품 이미지",
    source: "product-store.co.kr",
    url: "https://product-store.co.kr",
    time: "3일 전",
    folder: "인박스",
    tags: ["스크린샷", "확인필요"],
    folderSuggestions: ["쇼핑", "나중에"],
    description: "미리보기 이미지를 못 받았지만 저장 자체는 완료된 상태."
  }
];

const STORAGE_KEY = "clip-inbox-prototype-v2";

const defaultFolders = [
  { icon: "archive", label: "전체" },
  { icon: "inbox", label: "인박스" },
  { icon: "folder", label: "디자인" },
  { icon: "bookmark", label: "자기계발" },
  { icon: "folder", label: "업무" },
  { icon: "globe", label: "여행" },
  { icon: "file", label: "맛집" },
  { icon: "note", label: "아이디어" }
];

const defaultPreferences = {
  "app-lock": "켬",
  theme: "라이트",
  language: "한국어",
  "default-folder": "인박스"
};

let { clips, folders, preferences } = loadData();

const settingDetails = {
  "app-lock": {
    title: "앱 잠금",
    summary: "네이티브 앱 잠금에 사용할 선택값을 이 프로토타입의 로컬 설정에 보관합니다.",
    kind: "choice",
    options: ["켬", "끔"]
  },
  theme: {
    title: "테마",
    summary: "선택값은 로컬 설정에 저장되며 현재 프로토타입 화면 토큰은 라이트를 유지합니다.",
    kind: "choice",
    options: ["라이트", "시스템 설정"]
  },
  language: {
    title: "언어",
    summary: "앱 표시 언어를 선택합니다.",
    kind: "choice",
    options: ["한국어", "English"]
  },
  "default-folder": {
    title: "기본 폴더",
    summary: "공유 시트에서 저장 버튼을 누르면 먼저 들어갈 폴더입니다.",
    kind: "choice",
    options: () => folders.filter((folder) => folder.label !== "전체").map((folder) => folder.label)
  },
  backup: {
    title: "백업 및 내보내기",
    summary: "클립, 태그, 폴더, 설정을 로컬 JSON 파일로 내보냅니다.",
    kind: "export"
  },
  import: {
    title: "가져오기",
    summary: "Clip Inbox에서 내보낸 JSON 백업을 검증한 뒤 현재 로컬 데이터로 복원합니다.",
    kind: "import"
  },
  about: {
    title: "앱 정보",
    summary: "Clip Inbox 0.2.0 기능형 정적 프로토타입입니다.",
    kind: "about"
  },
  contact: {
    title: "문의하기",
    summary: "문제 상황과 저장하려던 URL을 함께 남길 수 있도록 문의 이메일을 복사합니다.",
    kind: "contact"
  }
};

const typeLabels = {
  link: "링크",
  image: "이미지",
  memo: "메모",
  screenshot: "스크린샷",
  saved: "저장됨"
};

function filterLabels() {
  const count = (predicate) => clips.filter(predicate).length;
  return {
    all: `전체 ${clips.length}`,
    unsorted: `미정리 ${count((clip) => clip.state === "unsorted")}`,
    link: `링크 ${count((clip) => clip.type === "link")}`,
    image: `이미지 ${count((clip) => clip.type === "image")}`,
    memo: `메모 ${count((clip) => clip.type === "memo")}`,
    screenshot: `스크린샷 ${count((clip) => clip.type === "screenshot")}`
  };
}

const state = {
  screen: "inbox",
  filter: "all",
  searchFilter: "전체",
  selectedId: clips[0]?.id ?? null,
  query: "",
  saved: false,
  sortIndex: 0,
  sortTotal: clips.filter((clip) => clip.state === "unsorted").length,
  sortCompleted: 0,
  sortChoice: "디자인",
  activeFolder: "인박스",
  destination: preferences["default-folder"] ?? "인박스",
  moveDestination: "인박스",
  folderTag: "디자인",
  newFolderName: "",
  addTags: ["인테리어", "거실"],
  editTags: [],
  tagContext: "add",
  selectedSetting: "app-lock",
  pendingSetting: preferences["app-lock"] ?? "켬",
  deleteContext: "detail",
  actionNotice: "",
  formError: ""
};

const root = document.getElementById("root");

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function defaultData() {
  return {
    version: 2,
    clips: clone(defaultClips),
    folders: clone(defaultFolders),
    preferences: clone(defaultPreferences)
  };
}

function cleanText(value, fallback = "", maxLength = 200) {
  if (typeof value !== "string") return fallback;
  return value.trim().slice(0, maxLength) || fallback;
}

function safeExternalUrl(value) {
  try {
    const url = new URL(value);
    return ["http:", "https:"].includes(url.protocol) ? url.href : "";
  } catch {
    return "";
  }
}

function safeImagePath(value) {
  return typeof value === "string" && /^\/public\/images\/[a-z0-9_-]+\.(png|jpe?g|webp|avif)$/i.test(value) ? value : undefined;
}

function normalizeData(input) {
  if (!input || !Array.isArray(input.clips) || !Array.isArray(input.folders)) {
    throw new Error("지원하지 않는 백업 형식입니다.");
  }
  const seenClipIds = new Set();
  const safeClips = input.clips
    .filter((clip) => clip && Number.isFinite(Number(clip.id)) && typeof clip.title === "string")
    .map((clip) => ({
      ...clip,
      id: Number(clip.id),
      type: ["link", "image", "memo", "screenshot"].includes(clip.type) ? clip.type : "link",
      ...(clip.state && ["unsorted", "new", "saved"].includes(clip.state) ? { state: clip.state } : { state: undefined }),
      title: cleanText(clip.title, "제목 없는 클립"),
      source: cleanText(clip.source, "출처 없음", 120),
      url: safeExternalUrl(clip.url),
      folder: cleanText(clip.folder, "인박스", 40),
      time: cleanText(clip.time, "저장됨", 40),
      description: cleanText(clip.description, "", 500),
      memo: cleanText(clip.memo, "", 1000),
      image: safeImagePath(clip.image),
      tags: Array.isArray(clip.tags) ? clip.tags.map((tag) => cleanText(tag, "", 50)).filter(Boolean).slice(0, 12) : [],
      folderSuggestions: Array.isArray(clip.folderSuggestions) ? clip.folderSuggestions.map((folder) => cleanText(folder, "", 40)).filter(Boolean).slice(0, 8) : [],
      bookmarked: Boolean(clip.bookmarked)
    }))
    .filter((clip) => {
      if (seenClipIds.has(clip.id)) return false;
      seenClipIds.add(clip.id);
      return true;
    });
  const seenFolderLabels = new Set();
  const safeFolders = input.folders
    .filter((folder) => folder && typeof folder.label === "string" && folder.label.trim())
    .map((folder) => ({
      icon: cleanText(folder.icon, "folder", 30),
      label: cleanText(folder.label, "", 40),
      ...(folder.defaultTag ? { defaultTag: cleanText(folder.defaultTag, "", 50) } : {})
    }))
    .filter((folder) => {
      const key = folder.label.toLowerCase();
      if (!folder.label || seenFolderLabels.has(key)) return false;
      seenFolderLabels.add(key);
      return true;
    });
  if (!safeFolders.some((folder) => folder.label === "전체")) {
    safeFolders.unshift({ icon: "archive", label: "전체" });
  }
  if (!safeFolders.some((folder) => folder.label === "인박스")) {
    safeFolders.splice(1, 0, { icon: "inbox", label: "인박스" });
  }
  for (const clip of safeClips) {
    if (clip.folder === "전체") clip.folder = "인박스";
    const matchingFolder = safeFolders.find((folder) => folder.label.toLowerCase() === clip.folder.toLowerCase());
    if (matchingFolder) {
      clip.folder = matchingFolder.label;
    } else {
      safeFolders.push({ icon: "folder", label: clip.folder });
    }
  }
  const importedPreferences = input.preferences ?? {};
  const safePreferences = {
    "app-lock": ["켬", "끔"].includes(importedPreferences["app-lock"]) ? importedPreferences["app-lock"] : defaultPreferences["app-lock"],
    theme: ["라이트", "시스템 설정"].includes(importedPreferences.theme) ? importedPreferences.theme : defaultPreferences.theme,
    language: ["한국어", "English"].includes(importedPreferences.language) ? importedPreferences.language : defaultPreferences.language,
    "default-folder": safeFolders.some((folder) => folder.label !== "전체" && folder.label === importedPreferences["default-folder"])
      ? importedPreferences["default-folder"]
      : defaultPreferences["default-folder"]
  };
  return {
    clips: safeClips,
    folders: safeFolders,
    preferences: safePreferences
  };
}

function loadData() {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    return stored ? normalizeData(JSON.parse(stored)) : defaultData();
  } catch {
    return defaultData();
  }
}

function dataSnapshot() {
  return { version: 2, clips, folders, preferences };
}

function persistData() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(dataSnapshot()));
  } catch {
    throw new Error("로컬 저장 공간을 사용할 수 없습니다.");
  }
}

function folderCount(label) {
  return label === "전체" ? clips.length : clips.filter((clip) => clip.folder === label).length;
}

function folderClips(label) {
  return label === "전체" ? clips : clips.filter((clip) => clip.folder === label);
}

function settingsRows() {
  return [
    [
      ["lock", "앱 잠금", preferences["app-lock"], "app-lock"],
      ["palette", "테마", preferences.theme, "theme"],
      ["language", "언어", preferences.language, "language"],
      ["folder", "기본 폴더", preferences["default-folder"], "default-folder"]
    ],
    [
      ["upload", "백업 및 내보내기", "JSON", "backup"],
      ["download", "가져오기", "JSON", "import"]
    ],
    [
      ["info", "앱 정보", "0.2.0", "about"],
      ["help", "문의하기", "", "contact"]
    ]
  ];
}

function settingOptions(detail) {
  return typeof detail.options === "function" ? detail.options() : detail.options ?? [];
}

function resetAddDraft() {
  state.saved = false;
  state.destination = preferences["default-folder"] ?? "인박스";
  state.addTags = ["인테리어", "거실"];
  state.actionNotice = "";
  state.formError = "";
}

function icon(name) {
  const paths = {
    archive: '<path d="M4 7h16v12H4z"/><path d="M8 7V5h8v2"/><path d="M9 13h6"/>',
    inbox: '<path d="M4 7h16l-2 12H6z"/><path d="M8 14h2l2 2 2-2h2"/>',
    folder: '<path d="M3 6h7l2 2h9v11H3z"/>',
    plus: '<path d="M12 5v14"/><path d="M5 12h14"/>',
    search: '<circle cx="11" cy="11" r="6"/><path d="m16 16 4 4"/>',
    settings: '<circle cx="12" cy="12" r="3"/><path d="M12 3v3"/><path d="M12 18v3"/><path d="M3 12h3"/><path d="M18 12h3"/><path d="m5 5 2 2"/><path d="m17 17 2 2"/><path d="m19 5-2 2"/><path d="m7 17-2 2"/>',
    filter: '<path d="M4 5h16l-6 7v6l-4 2v-8z"/>',
    sort: '<path d="M7 5h10"/><path d="M7 10h7"/><path d="M7 15h4"/><path d="m16 14 3 3 3-3"/><path d="M19 7v10"/>',
    more: '<circle cx="6" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="18" cy="12" r="1"/>',
    globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18"/><path d="M12 3c3 4 3 14 0 18"/><path d="M12 3c-3 4-3 14 0 18"/>',
    x: '<path d="M6 6l12 12"/><path d="M18 6 6 18"/>',
    down: '<path d="m7 10 5 5 5-5"/>',
    right: '<path d="m9 6 6 6-6 6"/>',
    left: '<path d="m15 6-6 6 6 6"/>',
    bookmark: '<path d="M7 4h10v16l-5-3-5 3z"/>',
    share: '<path d="M12 4v10"/><path d="m8 8 4-4 4 4"/><path d="M5 13v7h14v-7"/>',
    external: '<path d="M8 8h8v8"/><path d="m8 16 8-8"/><path d="M5 5h6"/><path d="M5 5v14h14v-6"/>',
    edit: '<path d="M5 19h4l10-10-4-4L5 15z"/><path d="m14 6 4 4"/>',
    trash: '<path d="M5 7h14"/><path d="M9 7V5h6v2"/><path d="M8 7l1 13h6l1-13"/>',
    lock: '<rect x="5" y="10" width="14" height="10" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>',
    palette: '<path d="M12 4a8 8 0 0 0 0 16h2a2 2 0 0 0 0-4h-1a1 1 0 0 1 0-2h2a5 5 0 0 0-3-10z"/><circle cx="8" cy="11" r="1"/><circle cx="10" cy="8" r="1"/><circle cx="14" cy="8" r="1"/>',
    language: '<path d="M4 5h9"/><path d="M8 5c0 5-2 8-5 10"/><path d="M6 10c2 3 4 5 7 6"/><path d="M15 19l4-9 4 9"/><path d="M17 15h4"/>',
    upload: '<path d="M12 16V4"/><path d="m8 8 4-4 4 4"/><path d="M5 16v4h14v-4"/>',
    download: '<path d="M12 4v12"/><path d="m8 12 4 4 4-4"/><path d="M5 20h14"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 10v6"/><path d="M12 7h.01"/>',
    help: '<circle cx="12" cy="12" r="9"/><path d="M9 9a3 3 0 1 1 4 3c-1 1-1 1-1 2"/><path d="M12 17h.01"/>',
    check: '<path d="m5 12 4 4L19 6"/>',
    saved: '<circle cx="12" cy="12" r="9"/><path d="m8 12 3 3 5-6"/>',
    camera: '<path d="M5 8h4l2-2h2l2 2h4v11H5z"/><circle cx="12" cy="13" r="3"/>',
    image: '<rect x="4" y="5" width="16" height="14" rx="2"/><path d="m4 16 5-5 4 4 2-2 5 5"/>',
    note: '<path d="M6 4h9l3 3v13H6z"/><path d="M14 4v4h4"/><path d="M9 13h6"/><path d="M9 17h4"/>',
    file: '<path d="M6 4h9l3 3v13H6z"/><path d="M14 4v4h4"/>'
  };
  return `<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${paths[name] ?? paths.file}</svg>`;
}

function clipImage(src, alt, { className = "", priority = false } = {}) {
  const loading = priority ? 'fetchpriority="high"' : 'loading="lazy"';
  return `<img${className ? ` class="${className}"` : ""} src="${escapeAttr(src)}" alt="${escapeAttr(alt)}" width="282" height="188" decoding="async" ${loading}>`;
}

function render() {
  root.innerHTML = `
    <div class="app-shell">
      ${statusBar()}
      <main class="screen" data-screen="${state.screen}">
        ${screenMarkup()}
        ${state.actionNotice ? toast(state.actionNotice) : ""}
      </main>
      ${["inbox", "folders", "add", "search", "settings"].includes(state.screen) ? bottomNav() : ""}
    </div>
  `;
  bindEvents();
}

function statusBar() {
  return `
    <div class="status-bar" aria-hidden="true">
      <span>9:41</span>
      <span class="status-icons">
        <span class="signal-bars"><i></i><i></i><i></i></span>
        <span class="wifi-mark"></span>
        <span class="battery-mark"></span>
      </span>
    </div>
  `;
}

function screenMarkup() {
  if (state.screen === "inbox") return inboxScreen();
  if (state.screen === "folders") return folderScreen();
  if (state.screen === "add") return addScreen();
  if (state.screen === "search") return searchScreen();
  if (state.screen === "settings") return settingsScreen();
  if (state.screen === "detail") return detailScreen();
  if (state.screen === "filter") return filterScreen();
  if (state.screen === "destination") return destinationScreen();
  if (state.screen === "tag-editor") return tagEditorScreen();
  if (state.screen === "bookmark") return bookmarkScreen();
  if (state.screen === "share") return shareScreen();
  if (state.screen === "more") return moreScreen();
  if (state.screen === "external") return externalScreen();
  if (state.screen === "move") return moveScreen();
  if (state.screen === "edit") return editScreen();
  if (state.screen === "delete") return deleteScreen();
  if (state.screen === "folder-new") return newFolderScreen();
  if (state.screen === "folder-detail") return folderDetailScreen();
  if (state.screen === "setting-detail") return settingDetailScreen();
  if (state.screen === "card-actions") return cardActionsScreen();
  return sortScreen();
}

function header(title, { left = "", right = "" } = {}) {
  return `
    <header class="screen-header">
      <div class="header-side">${left}</div>
      <h1>${escapeHtml(title)}</h1>
      <div class="header-actions">${right}</div>
    </header>
  `;
}

function iconButton(label, iconName, action, active) {
  const toggle = active === undefined ? "" : ` aria-pressed="${active}"`;
  return `<button class="utility-button${active ? " is-on" : ""}" type="button" aria-label="${escapeAttr(label)}" title="${escapeAttr(label)}"${toggle} data-action="${escapeAttr(action)}">${icon(iconName)}</button>`;
}

function iconTextButton(label, iconName, action) {
  return `<button class="icon-text-button" type="button" aria-label="${escapeAttr(label)}" title="${escapeAttr(label)}" data-action="${escapeAttr(action)}">${icon(iconName)}</button>`;
}

function inboxScreen() {
  const list = clips.filter((clip) => {
    if (state.filter === "unsorted") return clip.state === "unsorted";
    if (state.filter === "all") return true;
    return clip.type === state.filter;
  });
  return `
    ${header("클립 인박스", {
      right: `${iconButton("필터", "filter", "open-filter")}${iconButton("정렬", "sort", "open-sort")}${iconButton("설정", "settings", "settings")}`
    })}
    <div class="chip-strip" aria-label="인박스 필터">
      ${Object.entries(filterLabels()).map(([key, label]) => chip(label, state.filter === key, `filter:${key}`)).join("")}
    </div>
    <div class="list-head">
      <h2>인박스</h2>
      <span>${list.length}개 클립</span>
    </div>
    <div class="card-stack">${list.length ? list.map(clipCard).join("") : collectionEmpty("표시할 클립이 없습니다", "필터를 바꾸거나 새 클립을 추가해 보세요.")}</div>
  `;
}

function filterScreen() {
  return `
    ${header("필터", {
      left: iconTextButton("뒤로", "left", "inbox")
    })}
    ${board("보이는 클립", null, `
      <div class="chip-wrap spacious">
        ${Object.entries(filterLabels()).map(([key, label]) => chip(label, state.filter === key, `filter:${key}`)).join("")}
      </div>
    `)}
    ${board("정리 상태", null, `
      <div class="choice-stack">
        ${actionRow("inbox", "전체 인박스", "모든 저장 항목", "filter:all", state.filter === "all" ? "is-selected" : "")}
        ${actionRow("sort", "미정리만", "분류가 필요한 항목", "filter:unsorted", state.filter === "unsorted" ? "is-selected" : "")}
      </div>
    `)}
    <button class="primary-box-button" type="button" data-action="inbox">${icon("check")}필터 적용</button>
  `;
}

function addScreen() {
  return `
    ${header("저장 옵션", {
      left: iconTextButton("닫기", "x", "inbox"),
      right: `<button class="text-action" data-action="save">${state.saved ? "저장됨" : "저장"}</button>`
    })}
    <article class="preview-panel">
      ${clipImage("/public/images/clip-living-room.png", "미니멀 인테리어 미리보기", { priority: true })}
      <div>
        ${badge("링크", "link")}
        <h2>미니멀 인테리어 아이디어 모음 50</h2>
        <span>brunch.co.kr</span>
        <p role="status">미리보기 생성 중에도 바로 저장할 수 있습니다</p>
      </div>
    </article>
    ${board("저장 위치", null, `
      <button class="select-row" type="button" data-action="destination">
        <span class="row-icon yellow">${icon("inbox")}</span>
        <span>${escapeHtml(state.destination)}</span>
        ${icon("down")}
      </button>
    `)}
    ${board("태그", null, `
      <div class="chip-wrap compact">${state.addTags.map((tag) => tagChip(tag, false)).join("")}</div>
      <button class="inline-input" type="button" data-action="add-tag-editor"><span>태그 추가</span>${icon("plus")}</button>
    `)}
    ${board("메모", null, `<label class="memo-box"><span class="sr-only">메모</span><textarea placeholder="메모를 입력하세요" data-add-memo></textarea></label>`)}
    ${state.formError ? `<p class="form-message is-error" role="alert">${escapeHtml(state.formError)}</p>` : ""}
    <button class="primary-box-button" type="button" data-action="save" ${state.saved ? "disabled" : ""}>${state.saved ? `${escapeHtml(state.destination)}에 저장됨` : `${escapeHtml(state.destination)}에 저장`}</button>
  `;
}

function destinationScreen() {
  return `
    ${header("저장 위치", {
      left: iconTextButton("뒤로", "left", "add")
    })}
    ${board("폴더 선택", null, `
      <div class="choice-stack">
        ${folders.filter((folder) => folder.label !== "전체").map(({ label }) => actionRow("folder", label, `${folderCount(label)}개 클립`, `destination:${encodeURIComponent(label)}`, state.destination === label ? "is-selected" : "")).join("")}
      </div>
    `)}
    <button class="primary-box-button" type="button" data-action="add">${icon("check")}선택 완료</button>
  `;
}

function tagEditorScreen() {
  const suggestions = ["인테리어", "거실", "미니멀", "레퍼런스", "아이디어", "나중에"];
  const editingClip = state.tagContext === "edit";
  const tags = editingClip ? state.editTags : state.addTags;
  const returnAction = editingClip ? "edit-return" : "add";
  return `
    ${header("태그 편집", {
      left: iconTextButton("뒤로", "left", returnAction)
    })}
    ${board("현재 태그", tags.length, `
      <div class="chip-wrap spacious">
        ${tags.map((tag) => chip(`${tag} 삭제`, false, `remove-tag:${encodeURIComponent(tag)}`)).join("")}
      </div>
    `)}
    ${board("추천 태그", null, `
      <div class="chip-wrap spacious">
        ${suggestions.map((tag) => chip(tag, tags.includes(tag), `add-tag:${encodeURIComponent(tag)}`)).join("")}
      </div>
    `)}
    <button class="primary-box-button" type="button" data-action="${returnAction}">${icon("check")}태그 적용</button>
  `;
}

function detailScreen() {
  const clip = selectedClip();
  return `
    ${header("클립 상세", {
      left: iconTextButton("뒤로", "left", "inbox"),
      right: `${iconButton("북마크", "bookmark", "bookmark", Boolean(clip.bookmarked))}${iconButton("공유", "share", "share")}${iconButton("더보기", "more", "more")}`
    })}
    <article class="detail-card">
      ${badge(typeLabels[clip.type], clip.type)}
      <h2>${escapeHtml(clip.title)}</h2>
      ${metaLine(clip)}
      ${clip.image ? clipImage(clip.image, `${clip.title} 미리보기`, { className: "detail-image", priority: true }) : fallbackDomain(clip.source)}
      <p>${escapeHtml(clip.description)}</p>
    </article>
    ${board("노트", null, `<p class="body-copy">${escapeHtml(clip.memo || "필요한 맥락을 짧게 적어두면 나중에 정리하기 쉽습니다.")}</p>`)}
    ${board("정리", null, `<div class="organize-list"><span>폴더 · ${escapeHtml(clip.folder)}</span><span>태그 · ${escapeHtml(clip.tags.join(", ") || "없음")}</span></div>`)}
    <div class="button-stack">
      <button class="primary-box-button" type="button" data-action="external" ${clip.url ? "" : "disabled"}>${icon("external")}${clip.url ? "링크 열기" : "열 수 있는 링크 없음"}</button>
      <div class="button-grid">
        <button class="secondary-box-button" type="button" data-action="move">${icon("folder")}이동</button>
        <button class="secondary-box-button" type="button" data-action="edit">${icon("edit")}편집</button>
        <button class="secondary-box-button is-danger" type="button" data-action="confirm-delete:detail">${icon("trash")}삭제</button>
      </div>
    </div>
  `;
}

function bookmarkScreen() {
  const clip = selectedClip();
  return `
    ${header("북마크", {
      left: iconTextButton("뒤로", "left", "detail")
    })}
    ${board("저장 상태", null, `
      <div class="state-panel">
        ${icon("bookmark")}
        <strong>${escapeHtml(clip.title)}</strong>
        <span>${clip.bookmarked ? "북마크에 추가됨" : "북마크에서 해제됨"}</span>
      </div>
    `)}
    <button class="primary-box-button" type="button" data-action="detail">${icon("check")}상세로 돌아가기</button>
  `;
}

function shareScreen() {
  const clip = selectedClip();
  return `
    ${header("공유", {
      left: iconTextButton("뒤로", "left", "detail")
    })}
    ${board("공유할 클립", null, `
      <div class="share-summary">
        ${clip.image ? clipImage(clip.image, "", { priority: true }) : fallbackDomain(clip.source, true)}
        <div>
          <strong>${escapeHtml(clip.title)}</strong>
          <span>${escapeHtml(clip.source)}</span>
        </div>
      </div>
    `)}
    ${board("공유 방식", null, `
      <div class="choice-stack">
        ${actionRow("share", clip.url ? "링크 복사" : "클립 정보 복사", clip.url ? "URL을 클립보드에 복사" : "제목을 클립보드에 복사", "share-copy-link")}
        ${actionRow("note", "시스템 공유", "제목과 메모를 공유 시트로 전송", "share-system")}
        ${actionRow("image", "이미지 카드 저장", "썸네일 포함 PNG 다운로드", "share-card")}
      </div>
    `)}
    <button class="primary-box-button" type="button" data-action="detail">${icon("check")}완료</button>
  `;
}

function moreScreen() {
  return `
    ${header("더보기", {
      left: iconTextButton("뒤로", "left", "detail")
    })}
    ${actionMenu()}
  `;
}

function externalScreen() {
  const clip = selectedClip();
  return `
    ${header("링크 열기", {
      left: iconTextButton("뒤로", "left", "detail")
    })}
    ${board("열기 전 확인", null, `
      <div class="state-panel">
        ${icon("external")}
        <strong>${escapeHtml(clip.title)}</strong>
        <span>${escapeHtml(clip.source)}</span>
      </div>
    `)}
    <div class="button-stack">
      <button class="primary-box-button" type="button" data-action="external-opened">${icon("external")}브라우저에서 열기</button>
      <button class="secondary-box-button" type="button" data-action="detail">상세로 돌아가기</button>
    </div>
  `;
}

function moveScreen() {
  return `
    ${header("폴더 이동", {
      left: iconTextButton("뒤로", "left", "detail")
    })}
    ${board("이동할 폴더", null, `
      <div class="choice-stack">
        ${folders.filter((folder) => folder.label !== "전체").map(({ label }) => actionRow("folder", label, `${folderCount(label)}개 클립`, `move-folder:${encodeURIComponent(label)}`, state.moveDestination === label ? "is-selected" : "")).join("")}
      </div>
    `)}
    <button class="primary-box-button" type="button" data-action="move-complete">${icon("check")}${escapeHtml(state.moveDestination)}로 이동</button>
  `;
}

function editScreen() {
  const clip = selectedClip();
  return `
    ${header("클립 편집", {
      left: iconTextButton("뒤로", "left", "detail")
    })}
    ${board("제목", null, `<label class="edit-field"><span class="sr-only">제목</span><input value="${escapeAttr(clip.title)}" data-edit-title></label>`)}
    ${board("태그", null, `<div class="chip-wrap compact">${state.editTags.map((tag) => tagChip(tag, false)).join("")}</div><button class="inline-input" type="button" data-action="edit-tag-editor"><span>태그 편집</span>${icon("edit")}</button>`)}
    ${board("메모", null, `<label class="memo-box"><span class="sr-only">메모</span><textarea data-edit-memo>${escapeHtml(clip.memo || clip.description)}</textarea></label>`)}
    ${state.formError ? `<p class="form-message is-error" role="alert">${escapeHtml(state.formError)}</p>` : ""}
    <button class="primary-box-button" type="button" data-action="edit-save">${icon("check")}변경 저장</button>
  `;
}

function deleteScreen() {
  const title = state.deleteContext === "settings" ? "모든 데이터 삭제" : selectedClip().title;
  return `
    ${header("삭제 확인", {
      left: iconTextButton("뒤로", "left", state.deleteContext === "settings" ? "settings" : "detail")
    })}
    ${board("삭제 대상", null, `
      <div class="state-panel is-danger">
        ${icon("trash")}
        <strong>${escapeHtml(title)}</strong>
        <span>${state.deleteContext === "settings" ? "로컬에 저장된 클립, 폴더, 설정을 기본값으로 되돌립니다." : "이 클립은 인박스와 폴더에서 즉시 제거됩니다."}</span>
      </div>
    `)}
    <div class="button-stack">
      <button class="primary-box-button is-danger" type="button" data-action="delete-confirmed">${icon("trash")}삭제 확인</button>
      <button class="secondary-box-button" type="button" data-action="${state.deleteContext === "settings" ? "settings" : "detail"}">취소</button>
    </div>
  `;
}

function folderScreen() {
  return `
    ${header("폴더", { right: iconButton("새 폴더", "plus", "folder-new") })}
    <div class="folder-list">
      ${folders.map(({ icon: iconName, label }) => `
        <button class="folder-row ${state.activeFolder === label ? "is-active" : ""}" type="button" data-action="open-folder:${encodeURIComponent(label)}">
          <span class="folder-row-icon">${icon(iconName)}</span>
          <span>${escapeHtml(label)}</span>
          <strong>${folderCount(label)}</strong>
        </button>
      `).join("")}
    </div>
  `;
}

function newFolderScreen() {
  return `
    ${header("새 폴더", {
      left: iconTextButton("뒤로", "left", "folders")
    })}
    ${board("폴더 이름", null, `<label class="edit-field"><span class="sr-only">폴더 이름</span><input value="${escapeAttr(state.newFolderName)}" placeholder="예: 읽을거리" data-folder-name></label>`)}
    ${board("기본 태그", null, `
      <div class="chip-wrap spacious">
        ${["업무", "디자인", "나중에", "아이디어"].map((tag) => chip(tag, state.folderTag === tag, `folder-tag:${encodeURIComponent(tag)}`)).join("")}
      </div>
    `)}
    ${state.formError ? `<p class="form-message is-error" role="alert">${escapeHtml(state.formError)}</p>` : ""}
    <button class="primary-box-button" type="button" data-action="folder-create">${icon("plus")}폴더 만들기</button>
  `;
}

function folderDetailScreen() {
  const matches = folderClips(state.activeFolder);
  const count = matches.length;
  return `
    ${header(state.activeFolder, {
      left: iconTextButton("뒤로", "left", "folders"),
      right: iconButton("새 폴더", "plus", "folder-new")
    })}
    ${board("폴더 정보", null, `
      <div class="state-panel">
        ${icon("folder")}
        <strong>${escapeHtml(state.activeFolder)}</strong>
        <span>${count}개 클립을 보관 중</span>
      </div>
    `)}
    ${board("클립", count, matches.length ? `<div class="compact-stack">${matches.map(compactResult).join("")}</div>` : collectionEmpty("아직 클립이 없습니다", "클립을 이 폴더로 이동하면 여기에 표시됩니다."))}
  `;
}

function searchScreen() {
  const term = state.query.trim().toLowerCase();
  const baseResults = term
    ? clips.filter((clip) => [clip.title, clip.source, clip.tags.join(" "), clip.description, clip.memo ?? ""].join(" ").toLowerCase().includes(term))
    : clips.slice(0, 3);
  const results = state.searchFilter === "전체"
    ? baseResults
    : state.searchFilter === "태그"
      ? (term ? baseResults.filter((clip) => clip.tags.join(" ").toLowerCase().includes(term)) : baseResults)
    : baseResults.filter((clip) => typeLabels[clip.type] === state.searchFilter || clip.tags.includes(state.searchFilter));
  return `
    ${header("검색")}
    <label class="search-box">
      ${icon("search")}
      <span class="sr-only">검색어</span>
      <input value="${escapeAttr(state.query)}" placeholder="제목, 메모, 태그로 검색" data-search-input>
    </label>
    <div class="chip-strip">
      ${["전체", "링크", "메모", "이미지", "스크린샷", "태그"].map((label) => chip(label, state.searchFilter === label, `search-filter:${label}`)).join("")}
    </div>
    <section class="recent-searches" aria-label="최근 검색">
      <h2>최근 검색</h2>
      <div class="chip-wrap">
        ${["미니멀 인테리어", "습관", "여행"].map((label) => chip(label, false, `query:${label}`)).join("")}
      </div>
    </section>
    ${board("검색 결과", results.length, results.length ? `<div class="compact-stack">${results.map(compactResult).join("")}</div>` : emptyState())}
  `;
}

function sortScreen() {
  const unsorted = clips.filter((clip) => clip.state === "unsorted");
  if (!unsorted.length) {
    return `
      ${header("분류하기", {
        left: iconTextButton("뒤로", "left", "inbox"),
        right: `<span class="counter">${state.sortCompleted}/${state.sortTotal}</span>`
      })}
      ${board("분류 완료", null, `
        <div class="state-panel">
          ${icon("check")}
          <strong>미정리 클립을 모두 분류했습니다</strong>
          <span>선택한 폴더에서 바로 확인할 수 있습니다.</span>
        </div>
      `)}
      <button class="primary-box-button" type="button" data-action="inbox">${icon("inbox")}인박스로 돌아가기</button>
    `;
  }
  const clip = unsorted[0];
  const choices = [...new Set([...(clip.folderSuggestions ?? []), "기타"])].filter((choice) => choice !== "전체").slice(0, 4);
  const selectedChoice = choices.includes(state.sortChoice) ? state.sortChoice : choices[0];
  return `
    ${header("분류하기", {
      left: iconTextButton("뒤로", "left", "inbox"),
      right: `<span class="counter">${state.sortCompleted + 1}/${state.sortTotal}</span>`
    })}
    <div class="sort-preview">
      ${clip.image ? clipImage(clip.image, `${clip.title} 미리보기`, { priority: true }) : fallbackDomain(clip.source)}
      <div>
        <h2>${escapeHtml(clip.title)}</h2>
        <span>${escapeHtml(clip.source)}</span>
      </div>
    </div>
    <section class="choice-section">
      <h2>추천 분류</h2>
      <div class="choice-stack">
        ${choices.map((choice) => `
          <button class="choice-row ${selectedChoice === choice ? "is-selected" : ""}" type="button" data-action="choice:${encodeURIComponent(choice)}" aria-pressed="${selectedChoice === choice}">
            <span>${escapeHtml(choice)}</span>
            ${selectedChoice === choice ? icon("check") : ""}
          </button>
        `).join("")}
      </div>
    </section>
    <button class="primary-box-button" type="button" data-action="sort-apply:${encodeURIComponent(selectedChoice)}">${escapeHtml(selectedChoice)}로 분류하고 다음</button>
  `;
}

function settingsScreen() {
  const groups = settingsRows();
  return `
    ${header("설정")}
    ${settingsGroup(groups[0])}
    <section class="settings-section">
      <h2>데이터</h2>
      ${settingsGroup(groups[1])}
    </section>
    <section class="settings-section">
      <h2>기타</h2>
      ${settingsGroup(groups[2])}
    </section>
    ${board("앱 아이콘", null, `
      <div class="icon-preview-row">
        <div class="app-icon-preview" aria-label="Clip Inbox 앱 아이콘 미리보기">
          <span class="icon-card icon-card-back"></span>
          <span class="icon-card icon-card-front"></span>
          <span class="icon-tray"></span>
        </div>
        <div>
          <strong>Clip Inbox</strong>
          <span>기본 아이콘</span>
        </div>
      </div>
    `)}
    <button class="delete-card" type="button" data-action="confirm-delete:settings">모든 데이터 삭제</button>
  `;
}

function settingDetailScreen() {
  const detail = settingDetails[state.selectedSetting] ?? settingDetails["app-lock"];
  const options = settingOptions(detail);
  let controls = "";
  if (detail.kind === "choice") {
    controls = board("옵션", null, `
      <div class="choice-stack">
        ${options.map((option) => `
          <button class="choice-row ${state.pendingSetting === option ? "is-selected" : ""}" type="button" data-action="setting-option:${encodeURIComponent(option)}" aria-pressed="${state.pendingSetting === option}">
            <span>${escapeHtml(option)}</span>
            ${state.pendingSetting === option ? icon("check") : ""}
          </button>
        `).join("")}
      </div>
    `) + `<button class="primary-box-button" type="button" data-action="setting-complete">${icon("check")}설정 저장</button>`;
  } else if (detail.kind === "export") {
    controls = board("내보낼 항목", clips.length, `<p class="body-copy">클립 ${clips.length}개와 폴더 ${folders.length - 1}개, 현재 설정을 하나의 JSON 파일로 저장합니다.</p>`) +
      `<button class="primary-box-button" type="button" data-action="export-data">${icon("upload")}JSON 내보내기</button>`;
  } else if (detail.kind === "import") {
    controls = board("백업 파일", null, `
      <label class="file-picker">
        ${icon("download")}
        <span><strong>JSON 파일 선택</strong><small>Clip Inbox 백업만 지원합니다</small></span>
        <input type="file" accept="application/json,.json" data-import-input>
      </label>
    `) + `<button class="primary-box-button" type="button" data-action="import-data">${icon("download")}선택한 백업 가져오기</button>`;
  } else if (detail.kind === "contact") {
    controls = `<button class="primary-box-button" type="button" data-action="copy-contact">${icon("help")}문의 이메일 복사</button>`;
  } else {
    controls = board("버전", null, `<div class="organize-list"><span>Clip Inbox · 0.2.0</span><span>저장 위치 · 이 브라우저의 로컬 저장소</span></div>`);
  }
  return `
    ${header(detail.title, {
      left: iconTextButton("뒤로", "left", "settings")
    })}
    ${board("설정 설명", null, `
      <div class="state-panel">
        ${icon("settings")}
        <strong>${escapeHtml(detail.title)}</strong>
        <span>${escapeHtml(detail.summary)}</span>
      </div>
    `)}
    ${controls}
    ${state.formError ? `<p class="form-message is-error" role="alert">${escapeHtml(state.formError)}</p>` : ""}
  `;
}

function settingsGroup(rows) {
  return `
    <div class="settings-group">
      ${rows.map(([iconName, label, value, key]) => `
        <button class="settings-row" type="button" data-action="setting:${key}">
          <span class="settings-row-icon">${icon(iconName)}</span>
          <strong>${escapeHtml(label)}</strong>
          <span>${escapeHtml(value)}</span>
          ${icon("right")}
        </button>
      `).join("")}
    </div>
  `;
}

function board(title, count, content) {
  return `
    <section class="board-section">
      <div class="board-title">
        <h2>${escapeHtml(title)}</h2>
        ${Number.isFinite(count) ? `<span>${count}</span>` : ""}
      </div>
      ${content}
    </section>
  `;
}

function actionRow(iconName, label, value, action, className = "") {
  return `
    <button class="action-row ${escapeAttr(className)}" type="button" data-action="${escapeAttr(action)}">
      <span class="settings-row-icon">${icon(iconName)}</span>
      <strong>${escapeHtml(label)}</strong>
      <span>${escapeHtml(value)}</span>
      ${icon(className.includes("is-selected") ? "check" : "right")}
    </button>
  `;
}

function actionMenu() {
  const clip = selectedClip();
  return `
    ${board("클립 작업", null, `
      <div class="choice-stack">
        ${clip?.url ? actionRow("external", "링크 열기", "원본 페이지 확인", "external") : ""}
        ${actionRow("bookmark", "북마크", clip?.bookmarked ? "이미 추가됨" : "빠른 보관", "bookmark")}
        ${actionRow("share", "공유", "링크 또는 이미지 카드", "share")}
        ${actionRow("folder", "이동", "폴더 변경", "move")}
        ${actionRow("edit", "편집", "제목, 태그, 메모 수정", "edit")}
        ${actionRow("trash", "삭제", "삭제 전 확인", "confirm-delete:detail", "is-danger")}
      </div>
    `)}
  `;
}

function cardActionsScreen() {
  const clip = selectedClip();
  return `
    ${header("카드 메뉴", {
      left: iconTextButton("뒤로", "left", "inbox")
    })}
    ${board("선택한 클립", null, `
      <div class="state-panel">
        ${icon(typeIcon(clip.type))}
        <strong>${escapeHtml(clip.title)}</strong>
        <span>${escapeHtml(clip.source)}</span>
      </div>
    `)}
    ${actionMenu()}
  `;
}

function clipCard(clip, index = 0) {
  const stateBadge = clip.state
    ? badge(clip.state === "unsorted" ? "미정리" : clip.state === "new" ? "신규" : "저장됨", null, clip.state)
    : "";
  const visibleTags = clip.tags.slice(0, 3).map((tag) => tagChip(tag)).join("");
  const overflow = clip.tags.length > 3 ? `<span class="chip chip-count">+${clip.tags.length - 3}</span>` : "";
  return `
    <article class="clip-card">
      <button class="clip-card-hit" type="button" data-open-detail="${clip.id}" aria-label="${escapeAttr(clip.title)} 상세 보기"><span class="sr-only">${escapeHtml(clip.title)} 상세 보기</span></button>
      <div class="clip-top">
        <div class="badge-row">${badge(typeLabels[clip.type], clip.type)}${stateBadge}</div>
        <div class="clip-top-end">
          <time class="clip-time">${escapeHtml(clip.time)}</time>
          <button class="card-menu" type="button" aria-label="${escapeAttr(clip.title)} 메뉴" data-action="card-actions:${clip.id}">${icon("more")}</button>
        </div>
      </div>
      <div class="clip-body">
        <div class="clip-col">
          <h3>${escapeHtml(clip.title)}</h3>
          <div class="meta-line"><span>${icon("globe")}${escapeHtml(clip.source)}</span></div>
          <div class="chip-wrap compact">${visibleTags}${overflow}</div>
        </div>
        <div class="clip-media">${clip.image ? clipImage(clip.image, "", { priority: index === 0 }) : fallbackDomain(clip.source, true)}</div>
      </div>
    </article>
  `;
}

function compactResult(clip) {
  return `
    <button class="compact-result" type="button" data-open-detail="${clip.id}">
      ${clip.image ? clipImage(clip.image, "") : fallbackDomain(clip.source, true)}
      <span>
        <strong>${escapeHtml(clip.title)}</strong>
        <small>${escapeHtml(clip.source)}</small>
      </span>
      ${badge(typeLabels[clip.type], clip.type)}
      <em>${escapeHtml(clip.time)}</em>
    </button>
  `;
}

function badge(label, type, tone) {
  const className = type ? `badge type-${type}` : tone ? `badge tone-${tone}` : "badge";
  return `<span class="${escapeAttr(className)}">${escapeHtml(label)}</span>`;
}

function chip(label, active = false, action = "") {
  return `<button class="chip ${active ? "is-active" : ""}" type="button" ${action ? `data-action="${escapeAttr(action)}"` : ""}>${escapeHtml(label)}</button>`;
}

function tagChip(label, interactive = true) {
  return interactive ? chip(label, false, `query:${encodeURIComponent(label)}`) : `<span class="chip is-static">${escapeHtml(label)}</span>`;
}

function toast(message) {
  return `<div class="toast" role="status" aria-live="polite">${icon("saved")}${escapeHtml(message)}</div>`;
}

function typeIcon(type) {
  if (type === "image") return "image";
  if (type === "memo") return "note";
  if (type === "screenshot") return "camera";
  return "external";
}

function metaLine(clip) {
  return `
    <div class="meta-line">
      <span>${icon("globe")}${escapeHtml(clip.source)}</span>
      <time>${escapeHtml(clip.time)}</time>
    </div>
  `;
}

function fallbackDomain(source, compact = false) {
  return `<div class="fallback-domain ${compact ? "is-compact" : ""}">${icon("globe")}<span>${escapeHtml(source)}</span></div>`;
}

function emptyState() {
  return `
    <div class="empty-state">
      ${icon("search")}
      <strong>검색 결과 없음</strong>
      <span>제목, URL, 메모, 태그를 바꿔 다시 찾아보세요.</span>
    </div>
  `;
}

function collectionEmpty(title, message) {
  return `
    <div class="empty-state collection-empty">
      ${icon("inbox")}
      <strong>${escapeHtml(title)}</strong>
      <span>${escapeHtml(message)}</span>
    </div>
  `;
}

function bottomNav() {
  const items = [
    ["inbox", "인박스", "inbox"],
    ["folders", "폴더", "folder"],
    ["add", "추가", "plus"],
    ["search", "검색", "search"],
    ["settings", "설정", "settings"]
  ];
  return `
    <nav class="bottom-nav" aria-label="주요 화면">
      ${items.map(([key, label, iconName]) => `
        <button class="${state.screen === key ? "is-active" : ""}" data-nav="${key}" type="button" ${state.screen === key ? `aria-current="page"` : ""}>
          ${icon(iconName)}
          <span>${escapeHtml(label)}</span>
        </button>
      `).join("")}
    </nav>
  `;
}

function selectedClip() {
  return clips.find((clip) => clip.id === state.selectedId) ?? clips[0];
}

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;"
  })[character]);
}

function escapeAttr(value) {
  return escapeHtml(value);
}

function bindEvents() {
  root.querySelectorAll("[data-nav]").forEach((button) => {
    button.addEventListener("click", () => {
      if (button.dataset.nav === "add" && state.screen !== "add") resetAddDraft();
      state.actionNotice = "";
      state.formError = "";
      state.screen = button.dataset.nav;
      render();
    });
  });

  root.querySelectorAll("[data-action]").forEach((button) => {
    button.addEventListener("click", () => void handleAction(button.dataset.action));
  });

  root.querySelectorAll("[data-open-detail]").forEach((card) => {
    card.addEventListener("click", () => {
      state.actionNotice = "";
      state.formError = "";
      state.selectedId = Number(card.dataset.openDetail);
      state.screen = "detail";
      render();
    });
  });

  const searchInput = root.querySelector("[data-search-input]");
  if (searchInput) {
    searchInput.addEventListener("input", (event) => {
      state.query = event.target.value;
      render();
      root.querySelector("[data-search-input]")?.focus();
    });
    searchInput.setSelectionRange(searchInput.value.length, searchInput.value.length);
  }

  const folderNameInput = root.querySelector("[data-folder-name]");
  if (folderNameInput) {
    folderNameInput.addEventListener("input", (event) => {
      state.newFolderName = event.target.value;
      state.formError = "";
    });
  }
}

async function writeClipboard(text) {
  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(text);
    return;
  }
  const field = document.createElement("textarea");
  field.value = text;
  field.setAttribute("readonly", "");
  field.style.position = "fixed";
  field.style.opacity = "0";
  document.body.append(field);
  field.select();
  const copied = document.execCommand("copy");
  field.remove();
  if (!copied) throw new Error("클립보드 복사를 지원하지 않는 브라우저입니다.");
}

function downloadBlob(blob, fileName) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = fileName;
  document.body.append(link);
  link.click();
  link.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 0);
}

function exportData() {
  const blob = new Blob([JSON.stringify(dataSnapshot(), null, 2)], { type: "application/json" });
  downloadBlob(blob, "clip-inbox-backup.json");
}

async function importData() {
  const file = root.querySelector("[data-import-input]")?.files?.[0];
  if (!file) throw new Error("가져올 JSON 파일을 먼저 선택하세요.");
  if (file.size > 5_000_000) throw new Error("백업 파일은 5MB 이하여야 합니다.");
  const restored = normalizeData(JSON.parse(await file.text()));
  clips = restored.clips;
  folders = restored.folders;
  preferences = restored.preferences;
  state.selectedId = clips[0]?.id ?? null;
  state.destination = preferences["default-folder"] ?? "인박스";
  persistData();
}

function loadCanvasImage(src) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error("공유 카드 이미지를 불러오지 못했습니다."));
    image.src = src;
  });
}

function drawCover(context, image, x, y, width, height) {
  const scale = Math.max(width / image.width, height / image.height);
  const sourceWidth = width / scale;
  const sourceHeight = height / scale;
  const sourceX = (image.width - sourceWidth) / 2;
  const sourceY = (image.height - sourceHeight) / 2;
  context.drawImage(image, sourceX, sourceY, sourceWidth, sourceHeight, x, y, width, height);
}

function wrapCanvasText(context, text, x, y, maxWidth, lineHeight, maxLines) {
  const words = text.split(" ");
  const lines = [];
  let line = "";
  for (const word of words) {
    const next = line ? `${line} ${word}` : word;
    if (context.measureText(next).width > maxWidth && line) {
      lines.push(line);
      line = word;
    } else {
      line = next;
    }
  }
  if (line) lines.push(line);
  lines.slice(0, maxLines).forEach((item, index) => context.fillText(item, x, y + lineHeight * index));
}

async function downloadShareCard(clip) {
  const styles = getComputedStyle(document.documentElement);
  const token = (name) => styles.getPropertyValue(name).trim();
  const canvas = document.createElement("canvas");
  canvas.width = 1200;
  canvas.height = 630;
  const context = canvas.getContext("2d");
  context.fillStyle = token("--color-bg-app");
  context.fillRect(0, 0, canvas.width, canvas.height);
  context.fillStyle = token("--color-bg-card");
  context.strokeStyle = token("--color-border-strong");
  context.lineWidth = 8;
  context.beginPath();
  context.roundRect(56, 56, 1088, 518, 36);
  context.fill();
  context.stroke();

  context.fillStyle = token("--color-accent-yellow");
  context.beginPath();
  context.roundRect(96, 96, 176, 56, 28);
  context.fill();
  context.fillStyle = token("--color-text-primary");
  context.font = '800 28px -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", sans-serif';
  context.fillText(typeLabels[clip.type] ?? "클립", 128, 134);
  context.font = '800 56px -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", sans-serif';
  wrapCanvasText(context, clip.title, 96, 232, 552, 72, 3);
  context.fillStyle = token("--color-text-secondary");
  context.font = '600 28px -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", sans-serif';
  context.fillText(clip.source, 96, 496);

  if (clip.image) {
    const image = await loadCanvasImage(clip.image);
    context.save();
    context.beginPath();
    context.roundRect(720, 96, 368, 422, 24);
    context.clip();
    drawCover(context, image, 720, 96, 368, 422);
    context.restore();
    context.strokeStyle = token("--color-border-soft");
    context.lineWidth = 4;
    context.beginPath();
    context.roundRect(720, 96, 368, 422, 24);
    context.stroke();
  }

  const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/png"));
  if (!blob) throw new Error("공유 카드를 만들지 못했습니다.");
  downloadBlob(blob, `clip-${clip.id}.png`);
}

async function handleAction(action) {
  if (!action) return;
  state.actionNotice = "";
  state.formError = "";
  try {
    if (["inbox", "folders", "add", "search", "settings", "detail"].includes(action)) {
      state.screen = action;
    } else if (action === "edit-return") {
      state.screen = "edit";
    } else if (action === "open-filter") {
      state.screen = "filter";
    } else if (action === "open-sort") {
      state.sortTotal = clips.filter((clip) => clip.state === "unsorted").length;
      state.sortCompleted = 0;
      state.sortChoice = clips.find((clip) => clip.state === "unsorted")?.folderSuggestions?.[0] ?? "디자인";
      state.screen = "sort";
    } else if (action === "destination") {
      state.screen = "destination";
    } else if (action === "add-tag-editor") {
      state.tagContext = "add";
      state.screen = "tag-editor";
    } else if (action === "edit-tag-editor") {
      state.tagContext = "edit";
      state.screen = "tag-editor";
    } else if (action === "bookmark") {
      selectedClip().bookmarked = !selectedClip().bookmarked;
      persistData();
      state.screen = "bookmark";
    } else if (action === "share") {
      state.screen = "share";
    } else if (action === "share-copy-link") {
      await writeClipboard(selectedClip().url || selectedClip().title);
      state.actionNotice = "링크를 복사했습니다";
    } else if (action === "share-system") {
      const clip = selectedClip();
      if (navigator.share) {
        await navigator.share({ title: clip.title, text: clip.memo ?? clip.description, url: clip.url || undefined });
        state.actionNotice = "공유를 완료했습니다";
      } else {
        await writeClipboard([clip.title, clip.url].filter(Boolean).join("\n"));
        state.actionNotice = "공유 내용을 복사했습니다";
      }
    } else if (action === "share-card") {
      await downloadShareCard(selectedClip());
      state.actionNotice = "이미지 카드를 저장했습니다";
    } else if (action === "more") {
      state.screen = "more";
    } else if (action === "external") {
      state.screen = "external";
    } else if (action === "external-opened") {
      window.open(selectedClip().url, "_blank", "noopener,noreferrer");
      state.actionNotice = "새 탭에서 원본 열기를 요청했습니다";
    } else if (action === "move") {
      state.moveDestination = selectedClip().folder;
      state.screen = "move";
    } else if (action === "move-complete") {
      selectedClip().folder = state.moveDestination;
      persistData();
      state.actionNotice = `${state.moveDestination}로 이동했습니다`;
      state.screen = "detail";
    } else if (action === "edit") {
      state.editTags = [...selectedClip().tags];
      state.screen = "edit";
    } else if (action === "edit-save") {
      const title = cleanText(root.querySelector("[data-edit-title]")?.value, "", 200);
      const memo = cleanText(root.querySelector("[data-edit-memo]")?.value, "", 1000);
      if (!title) throw new Error("클립 제목을 입력하세요.");
      Object.assign(selectedClip(), { title, memo, tags: [...state.editTags] });
      persistData();
      state.actionNotice = "변경 내용을 저장했습니다";
      state.screen = "detail";
    } else if (action === "folder-new") {
      state.newFolderName = "";
      state.folderTag = "디자인";
      state.screen = "folder-new";
    } else if (action === "folder-create") {
      const name = cleanText(root.querySelector("[data-folder-name]")?.value ?? state.newFolderName, "", 40);
      if (!name) throw new Error("폴더 이름을 입력하세요.");
      if (folders.some((folder) => folder.label.toLowerCase() === name.toLowerCase())) throw new Error("같은 이름의 폴더가 이미 있습니다.");
      folders.push({ icon: "folder", label: name, defaultTag: state.folderTag });
      state.activeFolder = name;
      state.newFolderName = "";
      persistData();
      state.actionNotice = `${name} 폴더를 만들었습니다`;
      state.screen = "folder-detail";
    } else if (action === "save") {
      if (!state.saved) {
        const id = clips.reduce((max, clip) => Math.max(max, Number(clip.id) || 0), 0) + 1;
        clips.unshift({
          id,
          type: "link",
          state: "new",
          title: "미니멀 인테리어 아이디어 모음 50",
          source: "brunch.co.kr",
          url: "https://brunch.co.kr",
          time: "방금 전",
          folder: state.destination,
          tags: [...state.addTags],
          folderSuggestions: [state.destination, "디자인", "나중에"],
          image: "/public/images/clip-living-room.png",
          description: "공유 화면에서 방금 저장한 클립입니다.",
          memo: cleanText(root.querySelector("[data-add-memo]")?.value, "", 1000)
        });
        state.selectedId = id;
        state.saved = true;
        persistData();
      }
      state.actionNotice = `${state.destination}에 저장했습니다`;
    } else if (action.startsWith("sort-apply:")) {
      const clip = clips.find((item) => item.state === "unsorted");
      if (clip) {
        const destination = decodeURIComponent(action.slice("sort-apply:".length));
        clip.folder = destination;
        if (!folders.some((folder) => folder.label === destination)) folders.push({ icon: "folder", label: destination });
        delete clip.state;
        state.sortCompleted += 1;
        state.sortChoice = clips.find((item) => item.state === "unsorted")?.folderSuggestions?.[0] ?? "디자인";
        persistData();
      }
    } else if (action.startsWith("choice:")) {
      state.sortChoice = decodeURIComponent(action.slice("choice:".length));
    } else if (action.startsWith("filter:")) {
      state.filter = action.slice("filter:".length);
    } else if (action.startsWith("search-filter:")) {
      state.searchFilter = action.slice("search-filter:".length);
    } else if (action.startsWith("query:")) {
      state.query = decodeURIComponent(action.slice("query:".length));
      state.screen = "search";
    } else if (action.startsWith("destination:")) {
      state.destination = decodeURIComponent(action.slice("destination:".length));
    } else if (action.startsWith("add-tag:")) {
      const tag = decodeURIComponent(action.slice("add-tag:".length));
      const target = state.tagContext === "edit" ? state.editTags : state.addTags;
      if (!target.includes(tag)) target.push(tag);
    } else if (action.startsWith("remove-tag:")) {
      const tag = decodeURIComponent(action.slice("remove-tag:".length));
      if (state.tagContext === "edit") state.editTags = state.editTags.filter((item) => item !== tag);
      else state.addTags = state.addTags.filter((item) => item !== tag);
    } else if (action.startsWith("open-folder:")) {
      state.activeFolder = decodeURIComponent(action.slice("open-folder:".length));
      state.screen = "folder-detail";
    } else if (action.startsWith("folder-tag:")) {
      state.folderTag = decodeURIComponent(action.slice("folder-tag:".length));
    } else if (action.startsWith("setting:")) {
      state.selectedSetting = action.slice("setting:".length);
      state.pendingSetting = preferences[state.selectedSetting] ?? "";
      state.screen = "setting-detail";
    } else if (action.startsWith("setting-option:")) {
      state.pendingSetting = decodeURIComponent(action.slice("setting-option:".length));
    } else if (action === "setting-complete") {
      preferences[state.selectedSetting] = state.pendingSetting;
      if (state.selectedSetting === "default-folder") state.destination = state.pendingSetting;
      persistData();
      state.actionNotice = "설정을 저장했습니다";
      state.screen = "settings";
    } else if (action === "export-data") {
      exportData();
      state.actionNotice = "JSON 백업을 저장했습니다";
    } else if (action === "import-data") {
      await importData();
      state.actionNotice = "백업을 가져왔습니다";
      state.screen = "settings";
    } else if (action === "copy-contact") {
      await writeClipboard("support@clipinbox.local");
      state.actionNotice = "문의 이메일을 복사했습니다";
    } else if (action.startsWith("move-folder:")) {
      state.moveDestination = decodeURIComponent(action.slice("move-folder:".length));
    } else if (action.startsWith("confirm-delete:")) {
      state.deleteContext = action.slice("confirm-delete:".length);
      state.screen = "delete";
    } else if (action === "delete-confirmed") {
      if (state.deleteContext === "settings") {
        clips = [];
        folders = clone(defaultFolders);
        preferences = clone(defaultPreferences);
        state.selectedId = null;
        state.destination = preferences["default-folder"];
        state.actionNotice = "로컬 데이터를 삭제했습니다";
        state.screen = "settings";
      } else {
        clips = clips.filter((clip) => clip.id !== state.selectedId);
        state.selectedId = clips[0]?.id ?? null;
        state.actionNotice = "클립을 삭제했습니다";
        state.screen = "inbox";
      }
      persistData();
    } else if (action.startsWith("card-actions:")) {
      state.selectedId = Number(action.slice("card-actions:".length));
      state.screen = "card-actions";
    }
  } catch (error) {
    if (error?.name === "AbortError") state.actionNotice = "공유를 취소했습니다";
    else state.formError = error instanceof Error ? error.message : "작업을 완료하지 못했습니다.";
  }
  render();
}

render();
