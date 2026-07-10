import { readFileSync, statSync } from "node:fs";

const required = [
  "index.html",
  "src/app.js",
  "src/styles.css",
  "DESIGN.md",
  "docs/PROJECT_STATUS.md",
  "docs/TASKS.md",
  "docs/DECISIONS.md",
  "docs/CHANGELOG.md",
  "docs/CODE_REVIEW.md"
];

const visibleRequired = [
  "클립 인박스",
  "저장 옵션",
  "클립 상세",
  "폴더",
  "검색",
  "분류하기",
  "설정",
  "필터",
  "태그 편집",
  "저장 위치",
  "북마크",
  "공유",
  "더보기",
  "링크 열기",
  "폴더 이동",
  "클립 편집",
  "삭제 확인",
  "새 폴더",
  "검색 결과 없음",
  "저장됨"
];

for (const file of required) {
  statSync(file);
}

const app = readFileSync("src/app.js", "utf8");
const css = readFileSync("src/styles.css", "utf8");
const design = readFileSync("DESIGN.md", "utf8");

for (const text of visibleRequired) {
  if (!app.includes(text)) {
    throw new Error(`Missing required UI text: ${text}`);
  }
}

if (/[—–]/.test(app)) {
  throw new Error("Visible app source contains em dash or en dash characters.");
}

if (/\bnoop\b/.test(app)) {
  throw new Error("CTA source still contains noop actions.");
}

const buttonPattern = /<button\b(?=[\s\S]*?>)([\s\S]*?)>/g;
for (const match of app.matchAll(buttonPattern)) {
  const tag = match[0];
  if (!/(data-action|data-nav|data-open-detail)=/.test(tag)) {
    throw new Error(`Button is missing navigation/action wiring: ${tag}`);
  }
}

const designHexes = new Set([...design.matchAll(/#[0-9A-Fa-f]{6}\b/g)].map((match) => match[0].toLowerCase()));
const cssHexes = [...css.matchAll(/#[0-9A-Fa-f]{6}\b/g)].map((match) => match[0].toLowerCase());
const undeclared = cssHexes.filter((hex) => !designHexes.has(hex));
if (undeclared.length) {
  throw new Error(`CSS contains undeclared colors: ${[...new Set(undeclared)].join(", ")}`);
}

for (const token of ["color-accent-purple", "color-accent-pink", "color-accent-orange"]) {
  if (css.includes(token) || design.includes(token)) {
    throw new Error(`Removed accent token is still present: ${token}`);
  }
}

console.log(JSON.stringify({
  ok: true,
  files: required.length,
  screens: visibleRequired.length,
  declaredColors: designHexes.size
}, null, 2));
