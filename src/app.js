const clips = [
  {
    id: 1,
    type: "link",
    state: "unsorted",
    title: "미니멀 거실 인테리어 참고",
    source: "m.blog.naver.com",
    time: "2시간 전",
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
    time: "5시간 전",
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
    time: "어제",
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
    time: "어제",
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
    source: "domain fallback",
    time: "3일 전",
    tags: ["스크린샷", "확인필요"],
    folderSuggestions: ["쇼핑", "나중에"],
    description: "미리보기 이미지를 못 받았지만 저장 자체는 완료된 상태."
  }
];

const folders = [
  ["archive", "전체", 128],
  ["inbox", "인박스", 12, true],
  ["folder", "디자인", 24],
  ["bookmark", "자기계발", 18],
  ["folder", "업무", 16],
  ["globe", "여행", 14],
  ["file", "맛집", 9],
  ["note", "아이디어", 8]
];

const settingsGroups = [
  [
    ["lock", "앱 잠금", "켬", "app-lock"],
    ["palette", "테마", "라이트", "theme"],
    ["language", "언어", "한국어", "language"],
    ["folder", "기본 폴더", "인박스", "default-folder"]
  ],
  [
    ["upload", "백업 및 내보내기", "JSON", "backup"],
    ["download", "가져오기", "JSON", "import"]
  ],
  [
    ["info", "앱 정보", "Clip Inbox", "about"],
    ["help", "문의하기", "", "contact"]
  ]
];

const settingDetails = {
  "app-lock": {
    title: "앱 잠금",
    summary: "앱을 다시 열 때 Face ID 또는 기기 암호로 인박스를 보호합니다.",
    options: ["Face ID 사용", "즉시 잠금", "잠금 화면에서 미리보기 숨김"]
  },
  theme: {
    title: "테마",
    summary: "현재 프로토타입은 라이트 테마 기준으로 토큰을 고정합니다.",
    options: ["라이트", "시스템 설정 따르기"]
  },
  language: {
    title: "언어",
    summary: "앱 표시 언어를 선택합니다.",
    options: ["한국어", "English"]
  },
  "default-folder": {
    title: "기본 폴더",
    summary: "공유 시트에서 저장 버튼을 누르면 먼저 들어갈 폴더입니다.",
    options: ["인박스", "디자인", "업무", "나중에"]
  },
  backup: {
    title: "백업 및 내보내기",
    summary: "클립, 태그, 폴더 목록을 로컬 JSON 파일로 내보낼 준비 화면입니다.",
    options: ["전체 내보내기", "선택한 폴더만 내보내기"]
  },
  import: {
    title: "가져오기",
    summary: "기존 JSON 백업을 가져오기 전에 중복 클립을 확인합니다.",
    options: ["파일 선택", "중복 미리보기"]
  },
  about: {
    title: "앱 정보",
    summary: "Clip Inbox 0.1.0 정적 프로토타입입니다.",
    options: ["버전 0.1.0", "개인 로컬 보관"]
  },
  contact: {
    title: "문의하기",
    summary: "문제 상황과 저장하려던 URL을 함께 남길 수 있는 문의 준비 화면입니다.",
    options: ["메일 작성", "진단 정보 첨부"]
  }
};

const typeLabels = {
  link: "링크",
  image: "이미지",
  memo: "메모",
  screenshot: "스크린샷",
  saved: "저장됨"
};

const filterLabels = {
  all: "전체 84",
  unsorted: "미정리 12",
  link: "링크 48",
  image: "이미지 9",
  memo: "메모 5"
};

const state = {
  screen: "inbox",
  filter: "all",
  searchFilter: "전체",
  selectedId: 1,
  query: "",
  saved: false,
  bookmarked: false,
  sortIndex: 0,
  sortChoice: "디자인",
  activeFolder: "인박스",
  destination: "인박스",
  addTags: ["인테리어", "거실"],
  selectedSetting: "app-lock",
  deleteContext: "detail",
  actionNotice: ""
};

const root = document.getElementById("root");

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
      <h1>${title}</h1>
      <div class="header-actions">${right}</div>
    </header>
  `;
}

function iconButton(label, iconName, action) {
  return `<button class="utility-button" type="button" aria-label="${label}" title="${label}" data-action="${action}">${icon(iconName)}</button>`;
}

function iconTextButton(label, iconName, action) {
  return `<button class="icon-text-button" type="button" aria-label="${label}" title="${label}" data-action="${action}">${icon(iconName)}</button>`;
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
      ${Object.entries(filterLabels).map(([key, label]) => chip(label, state.filter === key, `filter:${key}`)).join("")}
    </div>
    ${board("INBOX", list.length, `<div class="card-stack">${list.map(clipCard).join("")}</div>`)}
  `;
}

function filterScreen() {
  return `
    ${header("필터", {
      left: iconTextButton("뒤로", "left", "inbox")
    })}
    ${board("보이는 클립", null, `
      <div class="chip-wrap spacious">
        ${Object.entries(filterLabels).map(([key, label]) => chip(label, state.filter === key, `filter:${key}`)).join("")}
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
      <img src="/public/images/clip-living-room.png" alt="">
      <div>
        ${badge("링크", "link")}
        <h2>미니멀 인테리어 아이디어 모음 50</h2>
        <span>brunch.co.kr</span>
        <p>미리보기 생성 중</p>
      </div>
    </article>
    ${board("저장 위치", null, `
      <button class="select-row" type="button" data-action="destination">
        <span class="row-icon yellow">${icon("inbox")}</span>
        <span>${state.destination}</span>
        ${icon("down")}
      </button>
    `)}
    ${board("태그", null, `
      <div class="chip-wrap compact">${state.addTags.map((tag) => tagChip(tag)).join("")}</div>
      <button class="inline-input" type="button" data-action="tag-editor"><span>태그 추가</span>${icon("plus")}</button>
    `)}
    ${board("메모", null, `<label class="memo-box"><span class="sr-only">메모</span><textarea placeholder="메모를 입력하세요"></textarea></label>`)}
    <button class="primary-box-button" type="button" data-action="save" ${state.saved ? "disabled" : ""}>${state.saved ? `${state.destination}에 저장됨` : `${state.destination}에 저장`}</button>
  `;
}

function destinationScreen() {
  return `
    ${header("저장 위치", {
      left: iconTextButton("뒤로", "left", "add")
    })}
    ${board("폴더 선택", null, `
      <div class="choice-stack">
        ${folders.slice(1).map(([, label, count]) => actionRow("folder", label, `${count}개 클립`, `destination:${label}`, state.destination === label ? "is-selected" : "")).join("")}
      </div>
    `)}
    <button class="primary-box-button" type="button" data-action="add">${icon("check")}선택 완료</button>
  `;
}

function tagEditorScreen() {
  const suggestions = ["인테리어", "거실", "미니멀", "레퍼런스", "아이디어", "나중에"];
  return `
    ${header("태그 편집", {
      left: iconTextButton("뒤로", "left", "add")
    })}
    ${board("현재 태그", state.addTags.length, `
      <div class="chip-wrap spacious">
        ${state.addTags.map((tag) => chip(`${tag} 삭제`, false, `remove-tag:${tag}`)).join("")}
      </div>
    `)}
    ${board("추천 태그", null, `
      <div class="chip-wrap spacious">
        ${suggestions.map((tag) => chip(tag, state.addTags.includes(tag), `add-tag:${tag}`)).join("")}
      </div>
    `)}
    <button class="primary-box-button" type="button" data-action="add">${icon("check")}태그 적용</button>
  `;
}

function detailScreen() {
  const clip = selectedClip();
  return `
    ${header("클립 상세", {
      left: iconTextButton("뒤로", "left", "inbox"),
      right: `${iconButton("북마크", "bookmark", "bookmark")}${iconButton("공유", "share", "share")}${iconButton("더보기", "more", "more")}`
    })}
    <article class="detail-card">
      ${badge(typeLabels[clip.type], clip.type)}
      <h2>${clip.title}</h2>
      ${metaLine(clip)}
      ${clip.image ? `<img class="detail-image" src="${clip.image}" alt="">` : fallbackDomain(clip.source)}
      <p>${clip.description}</p>
    </article>
    ${board("NOTE", null, `<p class="body-copy">${clip.memo ?? "필요한 맥락을 짧게 적어두면 나중에 정리하기 쉽습니다."}</p>`)}
    ${board("ORGANIZE", null, `<div class="organize-list"><span>Folder: Inbox</span><span>Tags: ${clip.tags.join(", ")}</span></div>`)}
    <div class="button-stack">
      <button class="primary-box-button" type="button" data-action="external">${icon("external")}링크 열기</button>
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
        <strong>${clip.title}</strong>
        <span>${state.bookmarked ? "북마크에 추가됨" : "북마크에서 해제됨"}</span>
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
        ${clip.image ? `<img src="${clip.image}" alt="">` : fallbackDomain(clip.source, true)}
        <div>
          <strong>${clip.title}</strong>
          <span>${clip.source}</span>
        </div>
      </div>
    `)}
    ${board("공유 방식", null, `
      <div class="choice-stack">
        ${actionRow("share", "링크 복사", "URL을 클립보드에 준비", "share-complete:링크 복사 준비됨")}
        ${actionRow("note", "메시지로 공유", "제목과 메모를 함께 전송", "share-complete:공유 시트 준비됨")}
        ${actionRow("image", "이미지 카드 저장", "썸네일 포함 카드 생성", "share-complete:이미지 카드 준비됨")}
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
        <strong>${clip.title}</strong>
        <span>${clip.source}</span>
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
        ${folders.slice(1).map(([, label, count]) => actionRow("folder", label, `${count}개 클립`, `move-folder:${label}`, state.activeFolder === label ? "is-selected" : "")).join("")}
      </div>
    `)}
    <button class="primary-box-button" type="button" data-action="detail">${icon("check")}이동 완료</button>
  `;
}

function editScreen() {
  const clip = selectedClip();
  return `
    ${header("클립 편집", {
      left: iconTextButton("뒤로", "left", "detail")
    })}
    ${board("제목", null, `<label class="edit-field"><span class="sr-only">제목</span><input value="${escapeAttr(clip.title)}"></label>`)}
    ${board("태그", null, `<div class="chip-wrap compact">${clip.tags.map((tag) => tagChip(tag)).join("")}</div>`)}
    ${board("메모", null, `<label class="memo-box"><span class="sr-only">메모</span><textarea>${clip.memo ?? clip.description}</textarea></label>`)}
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
        <strong>${title}</strong>
        <span>이 프로토타입에서는 삭제 전 확인 화면까지만 표시합니다.</span>
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
      ${folders.map(([iconName, label, count, active]) => `
        <button class="folder-row ${active ? "is-active" : ""}" type="button" data-action="open-folder:${label}">
          <span class="folder-row-icon">${icon(iconName)}</span>
          <span>${label}</span>
          <strong>${count}</strong>
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
    ${board("폴더 이름", null, `<label class="edit-field"><span class="sr-only">폴더 이름</span><input value="새 폴더"></label>`)}
    ${board("기본 태그", null, `
      <div class="chip-wrap spacious">
        ${["업무", "디자인", "나중에", "아이디어"].map((tag) => chip(tag, tag === "디자인", `folder-tag:${tag}`)).join("")}
      </div>
    `)}
    <button class="primary-box-button" type="button" data-action="folder-create">${icon("plus")}폴더 만들기</button>
  `;
}

function folderDetailScreen() {
  const count = folders.find(([, label]) => label === state.activeFolder)?.[2] ?? clips.length;
  return `
    ${header(state.activeFolder, {
      left: iconTextButton("뒤로", "left", "folders"),
      right: iconButton("새 폴더", "plus", "folder-new")
    })}
    ${board("폴더 정보", null, `
      <div class="state-panel">
        ${icon("folder")}
        <strong>${state.activeFolder}</strong>
        <span>${count}개 클립을 보관 중</span>
      </div>
    `)}
    ${board("클립", clips.length, `<div class="compact-stack">${clips.slice(0, 4).map(compactResult).join("")}</div>`)}
  `;
}

function searchScreen() {
  const term = state.query.trim().toLowerCase();
  const baseResults = term
    ? clips.filter((clip) => [clip.title, clip.source, clip.tags.join(" "), clip.description].join(" ").toLowerCase().includes(term))
    : clips.slice(0, 3);
  const results = state.searchFilter === "전체"
    ? baseResults
    : baseResults.filter((clip) => typeLabels[clip.type] === state.searchFilter || clip.tags.includes(state.searchFilter));
  return `
    ${header("검색")}
    <label class="search-box">
      ${icon("search")}
      <span class="sr-only">검색어</span>
      <input value="${escapeAttr(state.query)}" placeholder="제목, 메모, 태그로 검색" data-search-input>
    </label>
    <div class="chip-strip">
      ${["전체", "링크", "메모", "이미지", "태그"].map((label) => chip(label, state.searchFilter === label, `search-filter:${label}`)).join("")}
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
  const clip = unsorted[state.sortIndex % unsorted.length] ?? clips[0];
  const choices = ["디자인", "인테리어", "아이디어", "기타"];
  return `
    ${header("분류하기", {
      left: iconTextButton("뒤로", "left", "inbox"),
      right: `<span class="counter">${state.sortIndex + 1}/12</span>`
    })}
    <div class="sort-preview">
      ${clip.image ? `<img src="${clip.image}" alt="">` : fallbackDomain(clip.source)}
      <div>
        <h2>${clip.title}</h2>
        <span>${clip.source}</span>
      </div>
    </div>
    <section class="choice-section">
      <h2>추천 분류</h2>
      <div class="choice-stack">
        ${choices.map((choice) => `
          <button class="choice-row ${state.sortChoice === choice ? "is-selected" : ""}" type="button" data-action="choice:${choice}">
            <span>${choice}</span>
            ${state.sortChoice === choice ? icon("check") : ""}
          </button>
        `).join("")}
      </div>
    </section>
    <button class="primary-box-button" type="button" data-action="sort-next">다음 항목</button>
  `;
}

function settingsScreen() {
  return `
    ${header("설정")}
    ${settingsGroup(settingsGroups[0])}
    <section class="settings-section">
      <h2>데이터</h2>
      ${settingsGroup(settingsGroups[1])}
    </section>
    <section class="settings-section">
      <h2>기타</h2>
      ${settingsGroup(settingsGroups[2])}
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
  return `
    ${header(detail.title, {
      left: iconTextButton("뒤로", "left", "settings")
    })}
    ${board("설정 설명", null, `
      <div class="state-panel">
        ${icon("settings")}
        <strong>${detail.title}</strong>
        <span>${detail.summary}</span>
      </div>
    `)}
    ${board("옵션", null, `
      <div class="choice-stack">
        ${detail.options.map((option, index) => `
          <button class="choice-row ${index === 0 ? "is-selected" : ""}" type="button" data-action="setting-apply">
            <span>${option}</span>
            ${index === 0 ? icon("check") : ""}
          </button>
        `).join("")}
      </div>
    `)}
    <button class="primary-box-button" type="button" data-action="settings">${icon("check")}설정 완료</button>
  `;
}

function settingsGroup(rows) {
  return `
    <div class="settings-group">
      ${rows.map(([iconName, label, value, key]) => `
        <button class="settings-row" type="button" data-action="setting:${key}">
          <span class="settings-row-icon">${icon(iconName)}</span>
          <strong>${label}</strong>
          <span>${value}</span>
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
        <h2>${title}</h2>
        ${Number.isFinite(count) ? `<span>${count}</span>` : ""}
      </div>
      ${content}
    </section>
  `;
}

function actionRow(iconName, label, value, action, className = "") {
  return `
    <button class="action-row ${className}" type="button" data-action="${action}">
      <span class="settings-row-icon">${icon(iconName)}</span>
      <strong>${label}</strong>
      <span>${value}</span>
      ${icon(className.includes("is-selected") ? "check" : "right")}
    </button>
  `;
}

function actionMenu() {
  return `
    ${board("클립 작업", null, `
      <div class="choice-stack">
        ${actionRow("external", "링크 열기", "원본 페이지 확인", "external")}
        ${actionRow("bookmark", "북마크", state.bookmarked ? "이미 추가됨" : "빠른 보관", "bookmark")}
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
        <strong>${clip.title}</strong>
        <span>${clip.source}</span>
      </div>
    `)}
    ${actionMenu()}
  `;
}

function clipCard(clip) {
  const stateBadge = clip.state
    ? badge(clip.state === "unsorted" ? "미정리" : clip.state === "new" ? "신규" : "저장됨", null, clip.state)
    : "";
  return `
    <article class="clip-card" role="button" tabindex="0" data-open-detail="${clip.id}">
      <div class="clip-content">
        <div class="badge-row">${badge(typeLabels[clip.type], clip.type)}${stateBadge}</div>
        <h3>${clip.title}</h3>
        ${metaLine(clip)}
        <div class="chip-wrap compact">${clip.tags.slice(0, 3).map((tag) => tagChip(tag)).join("")}</div>
      </div>
      <div class="clip-media">${clip.image ? `<img src="${clip.image}" alt="">` : fallbackDomain(clip.source, true)}</div>
      <button class="card-menu" type="button" aria-label="${clip.title} 메뉴" data-action="card-actions:${clip.id}">${icon("more")}</button>
    </article>
  `;
}

function compactResult(clip) {
  return `
    <button class="compact-result" type="button" data-open-detail="${clip.id}">
      ${clip.image ? `<img src="${clip.image}" alt="">` : fallbackDomain(clip.source, true)}
      <span>
        <strong>${clip.title}</strong>
        <small>${clip.source}</small>
      </span>
      ${badge(typeLabels[clip.type], clip.type)}
      <em>${clip.time}</em>
    </button>
  `;
}

function badge(label, type, tone) {
  const className = type ? `badge type-${type}` : tone ? `badge tone-${tone}` : "badge";
  return `<span class="${className}">${label}</span>`;
}

function chip(label, active = false, action = "") {
  return `<button class="chip ${active ? "is-active" : ""}" type="button" ${action ? `data-action="${action}"` : ""}>${label}</button>`;
}

function tagChip(label) {
  return chip(label, false, `query:${label}`);
}

function toast(message) {
  return `<div class="toast" role="status">${icon("saved")}${message}</div>`;
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
      <span>${icon("globe")}${clip.source}</span>
      <time>${clip.time}</time>
    </div>
  `;
}

function fallbackDomain(source, compact = false) {
  return `<div class="fallback-domain ${compact ? "is-compact" : ""}">${icon("globe")}<span>${source}</span></div>`;
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
        <button class="${state.screen === key ? "is-active" : ""}" data-nav="${key}" type="button">
          ${icon(iconName)}
          <span>${label}</span>
        </button>
      `).join("")}
    </nav>
  `;
}

function selectedClip() {
  return clips.find((clip) => clip.id === state.selectedId) ?? clips[0];
}

function escapeAttr(value) {
  return value.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");
}

function bindEvents() {
  root.querySelectorAll("[data-nav]").forEach((button) => {
    button.addEventListener("click", () => {
      state.actionNotice = "";
      state.screen = button.dataset.nav;
      render();
    });
  });

  root.querySelectorAll("[data-action]").forEach((button) => {
    button.addEventListener("click", () => handleAction(button.dataset.action));
  });

  root.querySelectorAll("[data-open-detail]").forEach((card) => {
    card.addEventListener("click", (event) => {
      if (event.target.closest(".card-menu")) return;
      state.actionNotice = "";
      state.selectedId = Number(card.dataset.openDetail);
      state.screen = "detail";
      render();
    });
    card.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        state.actionNotice = "";
        state.selectedId = Number(card.dataset.openDetail);
        state.screen = "detail";
        render();
      }
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
}

function handleAction(action) {
  if (!action) return;
  state.actionNotice = "";
  if (["inbox", "folders", "add", "search", "settings", "detail"].includes(action)) {
    state.screen = action;
  } else if (action === "open-filter") {
    state.screen = "filter";
  } else if (action === "open-sort") {
    state.screen = "sort";
  } else if (action === "destination") {
    state.screen = "destination";
  } else if (action === "tag-editor") {
    state.screen = "tag-editor";
  } else if (action === "bookmark") {
    state.bookmarked = true;
    state.screen = "bookmark";
  } else if (action === "share") {
    state.screen = "share";
  } else if (action === "more") {
    state.screen = "more";
  } else if (action === "external") {
    state.screen = "external";
  } else if (action === "external-opened") {
    state.actionNotice = "브라우저 열기 준비됨";
  } else if (action === "move") {
    state.screen = "move";
  } else if (action === "edit") {
    state.screen = "edit";
  } else if (action === "edit-save") {
    state.actionNotice = "변경 저장됨";
    state.screen = "detail";
  } else if (action === "folder-new") {
    state.screen = "folder-new";
  } else if (action === "folder-create") {
    state.activeFolder = "새 폴더";
    state.actionNotice = "새 폴더가 준비됨";
    state.screen = "folder-detail";
  } else if (action === "setting-apply") {
    state.actionNotice = "설정 선택됨";
  } else if (action === "save") {
    state.saved = true;
    state.actionNotice = "저장됨";
  } else if (action === "sort-next") {
    state.sortIndex += 1;
    state.sortChoice = "디자인";
  } else if (action.startsWith("choice:")) {
    state.sortChoice = action.slice("choice:".length);
  } else if (action.startsWith("filter:")) {
    state.filter = action.slice("filter:".length);
  } else if (action.startsWith("search-filter:")) {
    state.searchFilter = action.slice("search-filter:".length);
  } else if (action.startsWith("query:")) {
    state.query = action.slice("query:".length);
    state.screen = "search";
  } else if (action.startsWith("destination:")) {
    state.destination = action.slice("destination:".length);
  } else if (action.startsWith("add-tag:")) {
    const tag = action.slice("add-tag:".length);
    if (!state.addTags.includes(tag)) state.addTags.push(tag);
  } else if (action.startsWith("remove-tag:")) {
    const tag = action.slice("remove-tag:".length);
    state.addTags = state.addTags.filter((item) => item !== tag);
  } else if (action.startsWith("open-folder:")) {
    state.activeFolder = action.slice("open-folder:".length);
    state.screen = "folder-detail";
  } else if (action.startsWith("folder-tag:")) {
    state.actionNotice = `${action.slice("folder-tag:".length)} 태그 선택됨`;
  } else if (action.startsWith("setting:")) {
    state.selectedSetting = action.slice("setting:".length);
    state.screen = "setting-detail";
  } else if (action.startsWith("share-complete:")) {
    state.actionNotice = action.slice("share-complete:".length);
  } else if (action.startsWith("move-folder:")) {
    state.activeFolder = action.slice("move-folder:".length);
    state.actionNotice = `${state.activeFolder}로 이동 준비됨`;
  } else if (action.startsWith("confirm-delete:")) {
    state.deleteContext = action.slice("confirm-delete:".length);
    state.screen = "delete";
  } else if (action === "delete-confirmed") {
    state.actionNotice = state.deleteContext === "settings" ? "삭제 확인됨" : "클립 삭제 확인됨";
    state.screen = state.deleteContext === "settings" ? "settings" : "inbox";
  } else if (action.startsWith("card-actions:")) {
    state.selectedId = Number(action.slice("card-actions:".length));
    state.screen = "card-actions";
  }
  render();
}

render();
