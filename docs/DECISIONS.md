# Decisions

## 2026-07-10: Native SwiftUI Is the Product Source of Truth

Decision: All future Clip Inbox product logic and UI implementation will be made in the native iOS code under `ios/`. The root `src/` web application remains a historical design prototype and is changed only when web work is explicitly requested.

Why: The app is now built, installed, and exercised through Xcode with a native Share Extension, App Group storage, LocalAuthentication, and SwiftUI navigation. Mirroring new behavior in two runtimes would create drift and make it unclear which implementation is releaseable.

Impact: Feature work targets Swift models, stores, views, shared queue code, and `ios/project.yml`. XcodeGen regeneration plus a simulator build of both `ClipInbox` and `ClipInboxShare` is the required verification path.

## 2026-07-10: Filters and Tags Use One Direct Two-Row Selector

Decision: Remove the separate inbox filter modal. Inbox, search, tag editing, and new-folder tag selection use one shared control with five equal-width cells per row across two visible rows; the active value uses a 2pt yellow underline and options beyond ten continue horizontally in the same two-row grid.

Why: A visible filter plus a second filter modal duplicated the same action. Equal-width underline cells satisfy predictable scan alignment without recreating rounded pills, and a 0.72 minimum text scale handles longer Korean labels without changing control width.

Impact: Filtering applies as soon as a label is tapped. The first ten options are always a 5x2 matrix on phone and larger widths, every touch target stays 44pt, and custom tags can continue horizontally without introducing a third row. Inbox tags remain detail-only.

## 2026-07-10: Clip Rows Reserve Independent Navigation, Media, and Menu Space

Decision: Inbox rows place the navigation label and the 44pt menu button as sibling controls instead of overlaying the menu above card content. Inbox content is fixed at 68pt and compact search/folder content at 48pt, whether or not a thumbnail exists.

Why: Overlay composition made text, image, reserved menu space, and the menu itself compete at narrow widths. Intrinsic content height also allowed image and no-image rows to drift.

Impact: Text and thumbnails cannot overlap the menu, image/no-image rows align to the same divider rhythm, and the full content region still opens detail while the menu remains independently accessible.

## 2026-07-10: Recent Search History Records Real User Searches Separately

Decision: Remove hardcoded recent-search examples. Record a query only when Search is submitted or a result is opened, normalize and deduplicate it case-insensitively, keep the newest five, and persist the list in app `UserDefaults` outside the version-2 clip backup schema. Search requests default focus and repeats it after an 80ms next-runloop handoff.

Why: Static examples misrepresented history, while adding UI-only history to the cross-platform clip backup would change its compatibility contract. A first-responder handoff prevents the tab transition from swallowing the initial focus request.

Impact: Recent searches reflect actual behavior, survive app restart, and do not alter JSON import/export. Entering Search presents an active caret immediately; on devices without a connected hardware keyboard this also presents the software keyboard.

## 2026-07-10: Pretendard Is Bundled, Not Fetched at Runtime

Decision: Use the official Pretendard v1.3.9 release as the product typeface. The app registers Regular, SemiBold, and Bold OTF faces, the Share Extension registers Regular, and the web prototype self-hosts the official variable WOFF2. The SIL OFL 1.1 license is shipped beside each asset set.

Why: Pretendard gives Korean labels a more consistent compact rhythm across the app and web reference. Bundling avoids a network dependency in the native app and during the brief Share Extension lifecycle.

Impact: SwiftUI typography tokens now use exact Pretendard PostScript names, inherited body text defaults to Pretendard, and only SF Symbols retain system font metrics. The font files add about 4.7MB to the main simulator app and 1.5MB to the extension.

## 2026-07-10: Share Selection Is the Save Confirmation

Decision: Selecting Clip Inbox in the iOS share sheet immediately parses and queues the item, then completes the extension request. A compact saving state is shown only while work is in progress; a button appears only when an error needs dismissal.

Why: The user's intent is already explicit when they choose the app from the system share sheet. Requiring a second Save/OK step slowed the highest-frequency capture flow.

Impact: Safari and Photos return to their host as soon as the atomic App Group write completes. The containing app imports the payload on appearance or activation. Folder/tag/memo adjustments remain available after capture inside Clip Inbox.

## 2026-07-10: Native UI Uses a List-First Productive-Minimal Surface

Decision: Apply the supplied `reference-driven-ui-builder` skill as a structured adaptation, using a quiet editorial/productive-minimal native iOS mode. The app uses one warm ivory canvas, hairline-separated content rows, small-radius controls, regular-weight metadata, and yellow only for selection or a primary action. Outer cards, decorative pills, and hard shadows are not used for primary content hierarchy.

Why: The prior translation repeated rounded cards, tags, menus, and nested panels at every level. That reduced scan speed, made yellow/black labels appear doubled when combined with hard shadows, and caused important actions in detail screens to compete with the bottom navigation.

Impact: Inbox clips, folders, search results, Sort Later, settings, share actions, and detail organization now share a flat row grammar. Whole clip rows navigate to detail; workflow sheets open at 68% and can expand to large; detail notes edit in place; missing-media clips stay text-only; and a generated fallback is shown only when an explicit image reference cannot be decoded.

## 2026-07-10: Share Extension Uses an App Group File Queue

Decision: Embed a `com.apple.share-services` extension (`ClipInboxShare.appex`) and pass each URL, text, or image capture to the containing app as one atomic JSON file under `group.app.clipinbox.ClipInbox`. Shared Photos images are normalized to bounded JPEGs in the same App Group and referenced by a validated UUID filename.

Why: The extension and app run in separate processes and private containers. Per-item atomic files avoid a shared mutable JSON database, allow the extension to finish while the app is closed, and prevent concurrent writers from corrupting the existing version-2 app snapshot.

Impact: The app drains the queue whenever it appears or becomes active, normalizes each payload through the existing safety rules, persists before deleting queue files, renders shared-image thumbnails directly from the App Group, and removes their files when the clip is deleted. Physical-device distribution requires matching App Group provisioning on both targets.

## 2026-07-10: Native Port Lives in `ios/` and Is Generated With XcodeGen

Decision: The SwiftUI port is a sibling `ios/` directory with a committed `project.yml`; `ClipInbox.xcodeproj` is regenerated with `xcodegen generate` rather than hand-maintained.

Why: The web prototype remains the reviewable spec artifact, and a declarative project file keeps the Xcode project reproducible and diff-friendly on this shared volume. XcodeGen was already installed; Tuist was not.

Impact: Adding Swift files only requires re-running `xcodegen generate`. Build verification on this external volume needs DerivedData on the local disk plus `COMPILER_INDEX_STORE_ENABLE=NO`, because the volume's rename semantics break the compiler index store.

## 2026-07-10: Native Persistence Reuses the Web Version-2 Backup Schema

Decision: The Swift `Clip`/`Folder`/`Preferences` Codable models encode exactly the web prototype's version-2 JSON (including the `app-lock`/`default-folder` keys and `/public/images/...` asset paths, mapped to asset-catalog names), and the same normalization rules run on load and import.

Why: One schema means a backup exported from the web prototype restores in the native app and vice versa, and the hardened import validation did not have to be redesigned.

Impact: Verified by seeding a web-format JSON into the simulator app container and watching it load through the normal startup path. Future schema changes must update both implementations together.

## 2026-07-10: CTA Screens Map to Native Idioms, Not One-to-One Web Screens

Decision: Web CTA "destination screens" become native patterns: direct inline filtering, sheets for share/move/edit/tag editor/destination/card menu, alerts and confirmation dialogs for delete and external-link confirmation, pushed views for detail/folder detail/setting detail, and a direct toggle plus toast instead of the bookmark confirmation screen.

Why: The web prototype rendered every flow as a full screen because it had no navigation containers; SwiftUI has purpose-built containers, and replicating web screens would fight platform conventions the spec itself calls "iOS utility rhythm."

Impact: All CTA capabilities survive (persisted mutations, clipboard, system share via ShareLink, share-card image via ImageRenderer, JSON export/import via file dialogs, app lock via LocalAuthentication) while navigation feels native.

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
