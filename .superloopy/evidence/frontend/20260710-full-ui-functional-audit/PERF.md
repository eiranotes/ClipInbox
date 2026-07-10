# Performance and compliance

Status: PASS with documented mobile build-pipeline optimization remainder.

## Design-system compliance

Command:

`node /Users/tofu/.codex-shared/state/plugins/cache/personal/superloopy/0.7.2+codex.20260702112448/skills/superloopy-frontend/scripts/ds-compliance.mjs DESIGN.md src/styles.css src/app.js`

Result: 12 declared colors, zero violations, 4px base scale.

## Static and functional verification

- `npm run build`: PASS, 9 required files and 20 required screens.
- `npm run qa`: PASS across responsive layout and complete mutation/browser-capability flows.
- Hostile-import regression: PASS for stored markup escaping, URL scheme rejection, image-path restriction, and invalid preference normalization.
- `git diff --check`: PASS.

## Lighthouse

Production artifact note: this repository is a dependency-free static source deliverable, so the verified source is served directly. It has no bundler-generated `dist` variant.

| Form factor | Performance runs | Median performance | Accessibility | Best Practices | SEO |
|---|---|---:|---:|---:|---:|
| Mobile | 99, 99, 99 | 99 | 100 | 100 | 100 |
| Desktop | 100, 100, 100 | 100 | 100 | 100 | 100 |

Median mobile metrics: FCP 1.4s, LCP 2.2s, TBT 0ms, CLS 0, Speed Index 1.4s.

Artifacts: `lighthouse-mobile-1.json` through `lighthouse-mobile-3.json`, and `lighthouse-desktop-1.json` through `lighthouse-desktop-3.json`.

## Improvements made

- Added preload and high fetch priority for the first real thumbnail.
- Added intrinsic image dimensions and async decoding.
- Lazy-loaded non-primary card and result thumbnails.
- Preserved the actual imagery and complete interaction model rather than weakening UX for a score.

## Remaining measured opportunity

The mobile median is 99 rather than 100. Lighthouse still identifies source minification, unused initial-screen CSS/JavaScript, Python static-server cache headers, and alternate thumbnail encoding as opportunities. The largest estimates are 41 KiB unused JavaScript, 18 KiB unused CSS, 299 KiB cache lifetime, and 183 KiB image delivery. These are build/serving-pipeline improvements; no user-facing function or import hardening was removed to chase the final point.

React Doctor was not applicable because the project is plain HTML, CSS, and JavaScript.

SUPERLOOPY_EVIDENCE: `.superloopy/evidence/frontend/20260710-full-ui-functional-audit/PERF.md`
