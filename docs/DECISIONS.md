# Decisions

## 2026-07-09: Build a Web Prototype for the UI Spec

Decision: Implement the v1.5 UI direction as a dependency-free static web prototype.

Why: The folder contains a UI/token spec and image references but no existing native app source. The initial Vite/React direction was blocked by package-manager install/linking problems on the external volume. A static prototype lets the full screen set, visual tokens, states, Lighthouse, and browser QA be completed without local package dependencies.

Impact: The result is reviewable and interactive, but it is not a compiled SwiftUI app.

## 2026-07-09: Written Spec Overrides Softer References

Decision: Follow the v1.5 written token spec when it differs from the screenshots.

Why: The screenshots have softer iOS panels, while v1.5 explicitly asks for thick black outlines, Trello-like cards, yellow action accents, and no sports/ranking UI.

Impact: The prototype keeps the reference composition and Korean mobile rhythm, but cards, boards, chips, and buttons use stronger black borders.

## 2026-07-09: Use Real Cropped Reference Thumbnails

Decision: Crop thumbnails from the provided reference images for clip preview assets.

Why: The real-asset requirement is better served by actual images than CSS placeholder blocks.

Impact: The prototype has realistic card media while remaining fully local.

## 2026-07-09: Keep Classification UI Score-Free

Decision: Sort Later uses selected chips and rows only, with no percentages or confidence indicators.

Why: The spec excludes AI tagging, prediction, and gamified scoring.

Impact: Suggested folders feel lightweight and local-rule-based.

## 2026-07-09: Keep the Prototype Dependency-Free

Decision: Use plain HTML, CSS, and JavaScript instead of bundling React or Vite.

Why: `npm install` and `pnpm install` both stalled during `node_modules` linking on `/Volumes/AI/Clip`. The static implementation avoids that operational risk and still supports browser QA and Lighthouse.

Impact: The app can be served with `python3 -m http.server` and validated with `npm run build` without installing dependencies.
