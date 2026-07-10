# Decisions

## 2026-07-10: Responsive Workbench Instead of a Fixed Phone Preview

Decision: Keep the single-column 390px mobile layout, expand to a 736px two-column tablet shell at 768px, and cap the desktop workbench at 960px with two 456px card columns.

Why: The previous 430px maximum left most tablet and desktop space unused and made the interface look excessively small even though the product remains mobile-first. The new threshold only introduces two columns once each card can stay at least 340px wide.

Impact: Mobile hierarchy remains unchanged while wider screens gain scan speed and context retention. Secondary workflows retain a centered 720px reading measure.

## 2026-07-10: CTA Completion Means State Change or Browser Capability

Decision: A CTA is complete only when it navigates, mutates persisted local data, executes a supported browser capability, or is honestly disabled. Notices that only say an action is prepared are no longer accepted as completion.

Why: Edit, move, delete, folder, settings, share, export, and import screens existed but several actions did not change the visible model or execute their named operation.

Impact: Clips, folders, bookmarks, settings, and classifications persist in `localStorage`. Clipboard, new-tab, PNG download, JSON export/import, and delete-all flows use browser APIs. Native Face ID and iOS Share Extension behavior remain explicit platform boundaries.

## 2026-07-10: Clip Cards Use Independent Semantic Targets

Decision: Replace `article[role=button]` containing nested buttons with a full-card detail button plus independent menu and tag controls layered above it.

Why: Nested interactive semantics are invalid and create ambiguous keyboard and assistive-technology behavior.

Impact: The whole card remains easy to open, menu/tag quick actions stay independent, and every focus target receives a visible ring.

## 2026-07-10: Dynamic Counts Are the Prototype Source of Truth

Decision: Compute filter and folder counts from the current clip collection instead of displaying fixed marketing-sized sample numbers.

Why: Add, move, delete, import, and sorting made fixed counts drift from the actual visible items.

Impact: Counts and empty states now prove that CTA mutations landed correctly.

## 2026-07-10: Imported Data Is Untrusted

Decision: Normalize the JSON schema, allow only HTTP(S) external URLs and local `/public/images/` assets, whitelist clip types/states and preference values, escape every editable/imported text output, and encode dynamic action values.

Why: Once edit and import became real persistence features, previously static template strings became a stored-markup injection boundary.

Impact: Hostile titles, tags, folders, sources, URL schemes, image paths, and preferences are rendered as inert text or replaced by safe defaults. Browser QA imports a hostile fixture and proves that no markup executes.

## 2026-07-09: Inbox Cards Render Directly on the App Background

Decision: The inbox no longer wraps its clip cards in a bordered `board("INBOX", …)` panel. Cards stack directly on the app background under a lightweight, borderless list header.

Why: The uploaded reference shows inbox cards floating on the warm background, not nested inside a board. The board wrapper created a border-in-border look and its 16px padding narrowed the card text column to 139px, which forced Korean titles to wrap mid-word and truncated source hosts.

Impact: Cards gain ~36px of width (text column 139px to 183px), matching the reference and fixing the cramped layout. The `board()` component is still used for grouped form and detail sections.

## 2026-07-09: Clip Card Time Moves to the Top Row

Decision: The saved time is rendered in the card's top row beside the quick menu, and the source host gets its own full-width line.

Why: Sharing one line between host and time still truncated longer hosts (`m.blog.naver.com`) on a 375px screen even after widening the column. Separating them guarantees the host is never truncated regardless of title length.

Impact: Robust for long titles and long hosts. Detail screen keeps the combined host-plus-time meta line because it has full width there.

## 2026-07-09: Open Design Card Refinement Completed and Ported

Decision: Re-ran the Open Design MCP refinement (project `clip-inbox-cta-token-refinement`, Claude/Opus, `redesign-existing-projects` skill). It succeeded and produced `clip-card.html`; the layout technique (full-height thumbnail via `align-items:stretch`, two-line title clamp, non-truncating source, top-row badges plus menu) was ported into `src/app.js` and `src/styles.css` against the existing token variables and real image assets.

Why: The earlier attempt failed on a Fable 5 usage limit. The successful run confirmed the layout direction and was adapted rather than adopted wholesale so the app keeps its token system and real thumbnails.

Impact: The known-risk Open Design failure is resolved. The design source lives at `clip-inbox-cta-token-refinement/clip-card.html`.

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
