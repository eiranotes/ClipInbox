# Performance Evidence

## Commands

Static validation:

```sh
npm run build
```

Design-system compliance:

```sh
node /Users/tofu/.codex-shared/state/plugins/cache/personal/superloopy/0.7.2+codex.20260702112448/skills/superloopy-frontend/scripts/ds-compliance.mjs DESIGN.md src/styles.css src/app.js
```

Browser QA:

```sh
npm run qa
```

Lighthouse:

```sh
npx --yes lighthouse http://127.0.0.1:4173 --output=json --output-path=.superloopy/evidence/frontend/20260709-204729-clip-inbox-trello-token/lighthouse-mobile.json --only-categories=performance,accessibility,best-practices,seo --chrome-flags='--headless --no-sandbox'
npx --yes lighthouse http://127.0.0.1:4173 --preset=desktop --output=json --output-path=.superloopy/evidence/frontend/20260709-204729-clip-inbox-trello-token/lighthouse-desktop.json --only-categories=performance,accessibility,best-practices,seo --chrome-flags='--headless --no-sandbox'
```

## Results

- Static validation: pass.
- Design-system compliance: pass, no undeclared colors and no off-scale spacing violations.
- Browser QA: pass, no horizontal overflow at 390, 768, or 1280 px.
- Lighthouse mobile: Performance 100, Accessibility 100, Best Practices 100, SEO 100.
- Lighthouse desktop: Performance 100, Accessibility 100, Best Practices 100, SEO 100.

## Residual Notes

Lighthouse still reports advisory opportunities such as minifying CSS/JS, cache lifetimes, and image delivery. These are expected for the zero-build static server path and do not reduce category scores.
