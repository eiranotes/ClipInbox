import { mkdirSync, readFileSync } from "node:fs";

async function loadChromium() {
  const candidates = [
    "playwright",
    "/Users/tofu/HermesWorkspace/project/open-design/node_modules/.pnpm/playwright@1.60.0/node_modules/playwright/index.js"
  ];
  for (const candidate of candidates) {
    try {
      const mod = await import(candidate);
      const chromium = mod.chromium ?? mod.default?.chromium;
      if (chromium) return chromium;
    } catch {
      // Try the next local Playwright source.
    }
  }
  throw new Error("Playwright is not available locally.");
}

const evidenceDir =
  process.env.EVIDENCE_DIR ?? ".superloopy/evidence/frontend/20260710-full-ui-functional-audit";
const baseUrl = process.env.QA_URL ?? "http://127.0.0.1:4173";

mkdirSync(evidenceDir, { recursive: true });

const viewports = [
  { name: "mobile-390", width: 390, height: 844, columns: 1, minimumShell: 390 },
  { name: "tablet-768", width: 768, height: 1024, columns: 2, minimumShell: 700 },
  { name: "desktop-1280", width: 1280, height: 900, columns: 2, minimumShell: 900 }
];

const chromium = await loadChromium();
let browser;
try {
  browser = await chromium.launch({ headless: true });
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  if (!message.includes("Executable doesn't exist")) throw error;
  browser = await chromium.launch({ channel: "chrome", headless: true });
}

const context = await browser.newContext({ permissions: ["clipboard-read", "clipboard-write"] });
const page = await context.newPage();
const findings = [];

async function assertVisible(locator, label) {
  await locator.waitFor({ state: "visible" });
  if ((await locator.count()) !== 1) throw new Error(`${label} is not unique`);
}

async function assertText(locator, expected, label) {
  await assertVisible(locator, label);
  const actual = (await locator.innerText()).trim();
  if (!actual.includes(expected)) throw new Error(`${label} expected "${expected}" but received "${actual}"`);
}

const actionSelector = (prefix, value) => `[data-action='${prefix}:${encodeURIComponent(value)}']`;

for (const viewport of viewports) {
  await page.setViewportSize({ width: viewport.width, height: viewport.height });
  await page.goto(`${baseUrl}/?qa=${viewport.name}`, { waitUntil: "networkidle" });
  await page.screenshot({ path: `${evidenceDir}/${viewport.name}.png`, fullPage: true });
  const layout = await page.evaluate(() => {
    const shell = document.querySelector(".app-shell").getBoundingClientRect();
    const cardStack = document.querySelector(".card-stack");
    const buttonHeights = [...document.querySelectorAll("button")]
      .filter((button) => button.getBoundingClientRect().height > 0)
      .map((button) => Math.round(button.getBoundingClientRect().height));
    return {
      horizontalOverflow: document.documentElement.scrollWidth > document.documentElement.clientWidth,
      shellWidth: Math.round(shell.width),
      columns: getComputedStyle(cardStack).gridTemplateColumns.split(" ").filter(Boolean).length,
      minimumButtonHeight: Math.min(...buttonHeights)
    };
  });
  findings.push({ viewport: viewport.name, ...layout });
  if (layout.horizontalOverflow) throw new Error(`Horizontal overflow at ${viewport.name}`);
  if (layout.shellWidth < viewport.minimumShell) throw new Error(`Shell is too narrow at ${viewport.name}`);
  if (layout.columns !== viewport.columns) throw new Error(`Unexpected card columns at ${viewport.name}`);
  if (layout.minimumButtonHeight < 40) throw new Error(`Interactive control below 40px at ${viewport.name}`);
}

await page.setViewportSize({ width: 390, height: 844 });
await page.goto(`${baseUrl}/?qa=functional`, { waitUntil: "networkidle" });

await page.locator("[data-action='open-filter']").click();
await assertText(page.locator(".screen-header h1"), "필터", "Filter heading");
await page.locator(".chip[data-action='filter:unsorted']").click();
await page.getByRole("button", { name: "필터 적용", exact: true }).click();
await assertText(page.locator(".list-head span"), "2개 클립", "Filtered inbox count");
await page.locator(".chip[data-action='filter:all']").click();

await page.locator("[data-action='card-actions:1']").click();
await assertText(page.locator(".screen-header h1"), "카드 메뉴", "Card menu heading");
await page.getByRole("button", { name: "뒤로", exact: true }).click();

await page.locator("[data-nav='search']").click();
await page.locator("[data-action='search-filter:태그']").click();
await page.getByPlaceholder("제목, 메모, 태그로 검색").fill("없는검색어");
await assertText(page.locator(".empty-state strong"), "검색 결과 없음", "Search empty state");
await page.screenshot({ path: `${evidenceDir}/state-search-empty.png`, fullPage: true });

await page.locator("[data-nav='add']").click();
await page.locator("[data-action='destination']").click();
await page.locator(actionSelector("destination", "디자인")).click();
await page.getByRole("button", { name: "선택 완료", exact: true }).click();
await page.locator("[data-action='add-tag-editor']").click();
await page.locator(actionSelector("add-tag", "레퍼런스")).click();
await page.getByRole("button", { name: "태그 적용", exact: true }).click();
await page.locator("[data-add-memo]").fill("기능 QA에서 저장한 메모");
await page.locator(".primary-box-button[data-action='save']").click();
await assertText(page.locator(".toast"), "디자인에 저장했습니다", "Save notice");
if (await page.locator(".primary-box-button[data-action='save']").isEnabled()) {
  throw new Error("Saved primary CTA is not disabled");
}
await page.screenshot({ path: `${evidenceDir}/state-add-saved.png`, fullPage: true });
await page.locator("[data-nav='inbox']").click();
await assertText(page.locator(".chip-strip .chip.is-active"), "전체 6", "Added clip count");
await page.reload({ waitUntil: "networkidle" });
await assertText(page.locator(".chip-strip .chip.is-active"), "전체 6", "Persisted clip count after reload");

await page.getByRole("button", { name: "미니멀 인테리어 아이디어 모음 50 상세 보기", exact: true }).click();
await page.locator("[data-action='bookmark']").click();
await assertText(page.locator(".state-panel span"), "북마크에 추가됨", "Bookmark state");
await page.screenshot({ path: `${evidenceDir}/state-bookmark.png`, fullPage: true });
await page.getByRole("button", { name: "뒤로", exact: true }).click();

await page.locator("[data-action='share']").click();
await page.locator("[data-action='share-copy-link']").click();
const copiedUrl = await page.evaluate(() => navigator.clipboard.readText());
if (copiedUrl !== "https://brunch.co.kr/") throw new Error("Share link was not copied");
await page.evaluate(() => Object.defineProperty(navigator, "share", { value: undefined, configurable: true }));
await page.locator("[data-action='share-system']").click();
const sharedFallback = await page.evaluate(() => navigator.clipboard.readText());
if (!sharedFallback.includes("미니멀 인테리어 아이디어 모음 50")) throw new Error("System share fallback was not copied");
const shareCardDownload = page.waitForEvent("download");
await page.locator("[data-action='share-card']").click();
const shareCard = await shareCardDownload;
await shareCard.saveAs(`${evidenceDir}/exported-share-card.png`);
await assertText(page.locator(".toast"), "이미지 카드를 저장했습니다", "Share card notice");
await page.screenshot({ path: `${evidenceDir}/state-share.png`, fullPage: true });
await page.getByRole("button", { name: "뒤로", exact: true }).click();

await page.locator("[data-action='external']").click();
await page.evaluate(() => {
  window.__qaOpenedUrl = "";
  window.open = (url) => {
    window.__qaOpenedUrl = url;
    return null;
  };
});
await page.locator("[data-action='external-opened']").click();
const openedUrl = await page.evaluate(() => window.__qaOpenedUrl);
if (openedUrl !== "https://brunch.co.kr/") throw new Error("External URL was not opened");
await page.getByRole("button", { name: "뒤로", exact: true }).click();

await page.locator("[data-action='move']").click();
await page.locator(actionSelector("move-folder", "업무")).click();
await page.locator("[data-action='move-complete']").click();
await assertText(page.locator(".organize-list"), "폴더 · 업무", "Moved folder");

await page.locator("[data-action='edit']").click();
await page.locator("[data-action='edit-tag-editor']").click();
await page.locator(actionSelector("remove-tag", "인테리어")).click();
await page.locator(actionSelector("add-tag", "아이디어")).click();
await page.getByRole("button", { name: "태그 적용", exact: true }).click();
await page.locator("[data-edit-title]").fill("");
await page.locator("[data-action='edit-save']").click();
await assertText(page.locator(".form-message"), "클립 제목을 입력하세요", "Blank edit validation");
await page.locator("[data-edit-title]").fill("기능 점검 클립");
await page.locator("[data-edit-memo]").fill("편집 후 실제로 반영된 메모");
await page.locator("[data-action='edit-save']").click();
await assertText(page.locator(".detail-card h2"), "기능 점검 클립", "Edited title");
await assertText(page.locator(".organize-list"), "아이디어", "Edited tags");
await page.screenshot({ path: `${evidenceDir}/state-edited-detail.png`, fullPage: true });
await page.getByRole("button", { name: "뒤로", exact: true }).click();

await page.locator("[data-nav='folders']").click();
await page.locator("[data-action='folder-new']").click();
await page.locator("[data-action='folder-create']").click();
await assertText(page.locator(".form-message"), "폴더 이름을 입력하세요", "Blank folder validation");
await page.locator("[data-folder-name]").fill("읽을거리");
await page.locator(actionSelector("folder-tag", "업무")).click();
await page.locator("[data-action='folder-create']").click();
await assertText(page.locator(".screen-header h1"), "읽을거리", "Created folder title");
await assertText(page.locator(".collection-empty strong"), "아직 클립이 없습니다", "New folder empty state");
await page.screenshot({ path: `${evidenceDir}/state-folder-created.png`, fullPage: true });
await page.getByRole("button", { name: "뒤로", exact: true }).click();

await page.locator("[data-nav='settings']").click();
await page.locator("[data-action='setting:theme']").click();
await page.getByRole("button", { name: "시스템 설정", exact: true }).click();
await page.locator("[data-action='setting-complete']").click();
await assertText(page.locator("[data-action='setting:theme']"), "시스템 설정", "Saved theme setting");

await page.locator("[data-action='setting:backup']").click();
const backupDownload = page.waitForEvent("download");
await page.locator("[data-action='export-data']").click();
const backup = await backupDownload;
const backupPath = `${evidenceDir}/clip-inbox-backup.json`;
await backup.saveAs(backupPath);
await page.getByRole("button", { name: "뒤로", exact: true }).click();

await page.locator("[data-action='confirm-delete:settings']").click();
await page.locator("[data-action='delete-confirmed']").click();
await assertText(page.locator(".toast"), "로컬 데이터를 삭제했습니다", "Delete all notice");
await page.locator("[data-nav='inbox']").click();
await assertText(page.locator(".chip-strip .chip.is-active"), "전체 0", "Deleted all count");

await page.locator("[data-nav='settings']").click();
await page.locator("[data-action='setting:import']").click();
await page.locator("[data-import-input]").setInputFiles({
  name: "clip-inbox-backup.json",
  mimeType: "application/json",
  buffer: readFileSync(backupPath)
});
await page.locator("[data-action='import-data']").click();
await page.locator(".toast, .form-message").waitFor({ state: "visible" });
if ((await page.locator(".form-message").count()) === 1) {
  throw new Error(`Import failed: ${(await page.locator(".form-message").innerText()).trim()}`);
}
await assertText(page.locator(".toast"), "백업을 가져왔습니다", "Import notice");
await page.locator("[data-nav='inbox']").click();
await assertText(page.locator(".chip-strip .chip.is-active"), "전체 6", "Restored clip count");

await page.locator("[data-nav='settings']").click();
await page.locator("[data-action='setting:contact']").click();
await page.locator("[data-action='copy-contact']").click();
const copiedContact = await page.evaluate(() => navigator.clipboard.readText());
if (copiedContact !== "eiradev000@gmail.com") throw new Error("Contact email was not copied");
await page.getByRole("button", { name: "뒤로", exact: true }).click();
await page.locator("[data-nav='inbox']").click();

await page.locator("[data-action='open-sort']").click();
while ((await page.locator("[data-action^='sort-apply:']").count()) === 1) {
  await page.locator("[data-action^='sort-apply:']").click();
}
await assertText(page.locator(".state-panel strong"), "미정리 클립을 모두 분류했습니다", "Sort complete state");
await page.getByRole("button", { name: "인박스로 돌아가기", exact: true }).click();

await page.getByRole("button", { name: "기능 점검 클립 상세 보기", exact: true }).click();
await page.locator("[data-action='confirm-delete:detail']").click();
await page.locator("[data-action='delete-confirmed']").click();
await assertText(page.locator(".chip-strip .chip.is-active"), "전체 5", "Single delete count");
await page.screenshot({ path: `${evidenceDir}/state-delete-complete.png`, fullPage: true });

await page.locator("[data-nav='settings']").click();
await page.locator("[data-action='setting:import']").click();
const hostileBackup = {
  version: 2,
  clips: [{
    id: 99,
    type: "custom-type",
    state: "unsafe-state",
    title: '<img src=x onerror="window.__injected=1">보안 점검',
    source: '"><svg onload="window.__injected=1">',
    url: "javascript:alert(1)",
    time: "방금 전",
    folder: "<b>보관함</b>",
    tags: ["<script>window.__injected=1</script>"],
    folderSuggestions: [],
    image: "https://example.com/tracker.png",
    description: "가져오기 경계 점검"
  }],
  folders: [
    { icon: "archive", label: "전체" },
    { icon: "inbox", label: "인박스" },
    { icon: "folder", label: "<b>보관함</b>" }
  ],
  preferences: { "default-folder": "존재하지 않음", theme: "unsafe" }
};
await page.locator("[data-import-input]").setInputFiles({
  name: "hostile-backup.json",
  mimeType: "application/json",
  buffer: Buffer.from(JSON.stringify(hostileBackup))
});
await page.locator("[data-action='import-data']").click();
await assertText(page.locator(".toast"), "백업을 가져왔습니다", "Hostile import notice");
await page.locator("[data-nav='inbox']").click();
await assertText(page.locator(".clip-card h3"), "<img src=x", "Escaped imported title");
if ((await page.locator(".clip-card h3 img, .clip-card script, .clip-card svg[onload]").count()) !== 0) {
  throw new Error("Imported markup executed as DOM");
}
await page.locator("[data-open-detail='99']").click();
if (await page.locator(".primary-box-button[data-action='external']").isEnabled()) {
  throw new Error("Unsafe imported URL remained executable");
}

await browser.close();

console.log(JSON.stringify({ ok: true, baseUrl, findings }, null, 2));
