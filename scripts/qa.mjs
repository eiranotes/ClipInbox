import { mkdirSync } from "node:fs";

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
  process.env.EVIDENCE_DIR ?? ".superloopy/evidence/frontend/20260709-cta-token-polish";
const baseUrl = process.env.QA_URL ?? "http://127.0.0.1:4173";

mkdirSync(evidenceDir, { recursive: true });

const viewports = [
  { name: "mobile-390", width: 390, height: 844 },
  { name: "tablet-768", width: 768, height: 1024 },
  { name: "desktop-1280", width: 1280, height: 900 }
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
const page = await browser.newPage();
const findings = [];

for (const viewport of viewports) {
  await page.setViewportSize({ width: viewport.width, height: viewport.height });
  await page.goto(baseUrl, { waitUntil: "networkidle" });
  await page.screenshot({ path: `${evidenceDir}/${viewport.name}.png`, fullPage: true });
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth);
  findings.push({ viewport: viewport.name, horizontalOverflow: overflow });
  if (overflow) {
    throw new Error(`Horizontal overflow at ${viewport.name}`);
  }
}

await page.setViewportSize({ width: 390, height: 844 });
await page.goto(baseUrl, { waitUntil: "networkidle" });
await page.getByRole("button", { name: "필터" }).click();
await page.getByRole("heading", { name: "필터" }).waitFor();
await page.screenshot({ path: `${evidenceDir}/state-filter.png`, fullPage: true });
await page.getByRole("button", { name: "필터 적용" }).click();
await page.locator(".card-menu").first().click();
await page.getByRole("heading", { name: "카드 메뉴" }).waitFor();
await page.screenshot({ path: `${evidenceDir}/state-card-menu.png`, fullPage: true });
await page.getByRole("button", { name: "뒤로" }).click();
await page.locator("[data-nav='search']").click();
await page.getByRole("button", { name: "태그" }).click();
await page.getByPlaceholder("제목, 메모, 태그로 검색").fill("없는검색어");
await page.getByText("검색 결과 없음").waitFor();
await page.screenshot({ path: `${evidenceDir}/state-search-empty.png`, fullPage: true });
await page.locator("[data-nav='add']").click();
await page.locator(".select-row").click();
await page.getByRole("heading", { name: "저장 위치" }).waitFor();
await page.getByRole("button", { name: /디자인/ }).click();
await page.getByRole("button", { name: "선택 완료" }).click();
await page.getByRole("button", { name: "태그 추가" }).click();
await page.getByRole("heading", { name: "태그 편집" }).waitFor();
await page.getByRole("button", { name: "레퍼런스" }).click();
await page.getByRole("button", { name: "태그 적용" }).click();
await page.getByRole("button", { name: "디자인에 저장" }).click();
await page.getByRole("status").waitFor();
await page.screenshot({ path: `${evidenceDir}/state-add-saved.png`, fullPage: true });
await page.locator("[data-nav='inbox']").click();
await page.getByText("미니멀 거실 인테리어 참고").first().click();
await page.getByText("클립 상세").waitFor();
await page.screenshot({ path: `${evidenceDir}/state-detail.png`, fullPage: true });
await page.getByRole("button", { name: "북마크" }).click();
await page.getByRole("heading", { name: "북마크" }).waitFor();
await page.screenshot({ path: `${evidenceDir}/state-bookmark.png`, fullPage: true });
await page.getByRole("button", { name: "뒤로" }).click();
await page.getByRole("button", { name: "공유" }).click();
await page.getByRole("heading", { name: "공유", exact: true }).waitFor();
await page.getByRole("button", { name: /링크 복사/ }).click();
await page.screenshot({ path: `${evidenceDir}/state-share.png`, fullPage: true });
await page.getByRole("button", { name: "뒤로" }).click();
await page.getByRole("button", { name: "더보기" }).click();
await page.getByRole("heading", { name: "더보기" }).waitFor();
await page.screenshot({ path: `${evidenceDir}/state-more.png`, fullPage: true });
await page.getByRole("button", { name: "뒤로" }).click();
await page.getByRole("button", { name: "링크 열기" }).click();
await page.getByRole("heading", { name: "링크 열기" }).waitFor();
await page.screenshot({ path: `${evidenceDir}/state-external.png`, fullPage: true });
await page.getByRole("button", { name: "뒤로" }).click();
await page.getByRole("button", { name: "이동" }).click();
await page.getByRole("heading", { name: "폴더 이동" }).waitFor();
await page.screenshot({ path: `${evidenceDir}/state-move.png`, fullPage: true });
await page.getByRole("button", { name: "뒤로" }).click();
await page.getByRole("button", { name: "편집" }).click();
await page.getByRole("heading", { name: "클립 편집" }).waitFor();
await page.screenshot({ path: `${evidenceDir}/state-edit.png`, fullPage: true });
await page.getByRole("button", { name: "뒤로" }).click();
await page.getByRole("button", { name: "삭제" }).click();
await page.getByRole("heading", { name: "삭제 확인" }).waitFor();
await page.screenshot({ path: `${evidenceDir}/state-delete-detail.png`, fullPage: true });
await page.getByRole("button", { name: "취소" }).click();
await page.getByRole("button", { name: "뒤로" }).click();
await page.locator("[data-nav='folders']").click();
await page.getByRole("heading", { name: "폴더" }).waitFor();
await page.screenshot({ path: `${evidenceDir}/state-folders.png`, fullPage: true });
await page.getByRole("button", { name: "새 폴더" }).click();
await page.getByRole("heading", { name: "새 폴더" }).waitFor();
await page.screenshot({ path: `${evidenceDir}/state-folder-new.png`, fullPage: true });
await page.getByRole("button", { name: "폴더 만들기" }).click();
await page.getByRole("heading", { name: "새 폴더" }).waitFor();
await page.screenshot({ path: `${evidenceDir}/state-folder-detail.png`, fullPage: true });
await page.getByRole("button", { name: "뒤로" }).click();
await page.locator("[data-nav='settings']").click();
await page.getByRole("heading", { name: "설정" }).waitFor();
await page.screenshot({ path: `${evidenceDir}/state-settings.png`, fullPage: true });
await page.getByRole("button", { name: /앱 잠금/ }).click();
await page.getByRole("heading", { name: "앱 잠금" }).waitFor();
await page.screenshot({ path: `${evidenceDir}/state-setting-detail.png`, fullPage: true });
await page.getByRole("button", { name: "설정 완료" }).click();
await page.getByRole("button", { name: "모든 데이터 삭제" }).click();
await page.getByRole("heading", { name: "삭제 확인" }).waitFor();
await page.screenshot({ path: `${evidenceDir}/state-delete-settings.png`, fullPage: true });
await page.getByRole("button", { name: "취소" }).click();
await page.locator("[data-nav='inbox']").click();
await page.getByRole("button", { name: "정렬" }).click();
await page.getByText("분류하기").waitFor();
await page.getByRole("button", { name: "다음 항목" }).click();
await page.screenshot({ path: `${evidenceDir}/interaction-sort-later.png`, fullPage: true });

await browser.close();

console.log(JSON.stringify({ ok: true, baseUrl, findings }, null, 2));
