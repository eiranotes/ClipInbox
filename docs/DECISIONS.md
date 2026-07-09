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

## 2026-07-09: CTA Buttons Must Resolve to Screens or States

Decision: Every button template must include `data-action`, `data-nav`, or `data-open-detail`, and `noop` actions are rejected by static validation.

Why: The prototype now needs CTA-reachable flows to render concrete screens instead of dead controls.

Impact: Filter, card menu, bookmark, share, more, external link, move, edit, delete, save destination, tag editor, folder, and settings actions are all represented by static prototype screens or state feedback.

## 2026-07-09: Limit Tag and Badge State Colors

Decision: Tags and badges use a four-color state set: yellow, blue, green, and danger.

Why: The previous per-content pastel palette made the interface look noisy and less refined.

Impact: Content types share an informational blue marker, unsorted/new uses yellow, saved uses green, destructive actions use danger, and regular tags stay neutral.

## 2026-07-09: Open Design MCP Attempt Is Recorded Separately From Implementation

Decision: Create a Clip refinement project in Open Design MCP and record the agent-run failure, but keep implementation moving from local repo evidence.

Why: The Open Design run failed with a Fable 5 usage-limit error before producing output.

Impact: Open Design context exists at `clip-inbox-cta-token-refinement`, and the remaining OD refinement is deferred until model usage is available.
