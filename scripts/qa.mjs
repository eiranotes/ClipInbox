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
  process.env.EVIDENCE_DIR ?? ".superloopy/evidence/frontend/20260709-204729-clip-inbox-trello-token";
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
await page.locator("[data-nav='search']").click();
await page.getByPlaceholder("제목, 메모, 태그로 검색").fill("없는검색어");
await page.getByText("검색 결과 없음").waitFor();
await page.screenshot({ path: `${evidenceDir}/state-search-empty.png`, fullPage: true });
await page.locator("[data-nav='add']").click();
await page.getByRole("button", { name: "인박스에 저장" }).click();
await page.getByRole("status").waitFor();
await page.screenshot({ path: `${evidenceDir}/state-add-saved.png`, fullPage: true });
await page.locator("[data-nav='inbox']").click();
await page.getByText("미니멀 거실 인테리어 참고").first().click();
await page.getByText("클립 상세").waitFor();
await page.screenshot({ path: `${evidenceDir}/state-detail.png`, fullPage: true });
await page.getByRole("button", { name: "뒤로" }).click();
await page.locator("[data-nav='folders']").click();
await page.getByRole("heading", { name: "폴더" }).waitFor();
await page.screenshot({ path: `${evidenceDir}/state-folders.png`, fullPage: true });
await page.locator("[data-nav='settings']").click();
await page.getByRole("heading", { name: "설정" }).waitFor();
await page.screenshot({ path: `${evidenceDir}/state-settings.png`, fullPage: true });
await page.locator("[data-nav='inbox']").click();
await page.getByRole("button", { name: "정렬" }).click();
await page.getByText("분류하기").waitFor();
await page.getByRole("button", { name: "다음 항목" }).click();
await page.screenshot({ path: `${evidenceDir}/interaction-sort-later.png`, fullPage: true });

await browser.close();

console.log(JSON.stringify({ ok: true, baseUrl, findings }, null, 2));
