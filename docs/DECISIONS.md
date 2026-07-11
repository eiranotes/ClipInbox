# Decisions

## 2026-07-11: Adopt the Audit Through a Data-Safe, Product-Bounded Sequence

Decision: Apply the A-to-Z audit in the order documented by `docs/AUDIT_ADOPTION_PLAN.md`, beginning with test fixtures and the data trust boundary. Keep the native Share-to-Inbox product, five-tab shell, direct 5x2 selectors, normal-size one-viewport detail, original image preservation, and local-only/no-account positioning.

Why: The audit correctly identifies corruption, false-success, demo Add, Share image memory, App Lock, accessibility, and release risks. Its broader Library, database, encrypted-vault, OCR, sync, and platform-expansion recommendations would enlarge the product before its core storage contract is trustworthy.

Impact: Repository/recovery/transaction work precedes Capture and Lock work; trust UX and accessibility follow; release automation and external signing close the sequence. Large architectural migrations and power-user features require later measurement or product evidence.

## 2026-07-11: Version-2 Snapshots Use Current, Previous, and Quarantine Files

Decision: Keep the version-2 JSON format, but place file access behind `ClipRepository`. A successful write atomically replaces the current snapshot after retaining one validated previous snapshot. An unreadable current file is copied to `ClipInboxRecovery`; the app opens only a validated previous snapshot or a blocking recovery state. Future snapshot versions are never normalized or overwritten automatically.

Why: The existing direct `try?` load could silently replace user data with samples, while mutation callers often showed success after a failed write. A small repository boundary solves the trust problem without introducing a database migration or duplicate model layer.

Impact: Fresh installs begin empty. Main-data mutations commit transactionally and roll memory state back on failure. Users may explicitly start a new empty library after an unrecoverable file is preserved, while unsupported future versions require an app update.

## 2026-07-11: Share Capture Is File-First, Bounded, and Idempotent

Decision: Preserve supported source image bytes, but prefer `NSItemProvider` file representations and reject captures above 50 MB or 100 megapixels. Every provider request has a 10-second deadline with cancellation. Pending payloads sort by `createdAt`, quarantine corrupt/expired entries, cap at 200 items and 250 MB for 30 days, and store the payload UUID on the imported clip.

Why: Original-byte preservation is part of the product contract, but loading an unbounded source into extension memory or allowing an unbounded queue makes capture unreliable. Persisting the payload identity inside the main snapshot closes the crash/removal window without replacing the version-2 model or introducing a shared database.

Impact: Quick Share only confirms after image and payload files are durable, returns after 650 ms, and cannot duplicate an already committed payload. Items outside limits remain explicit failures rather than silent recompression or data loss; quarantine/storage visibility follows in Phase 3.

## 2026-07-11: App Lock Is a Fail-Closed Screen Barrier

Decision: App Lock can be enabled only when device-owner authentication is available. Capability errors, cancellation, and authentication failure keep the app locked. The app overlays an opaque token-based privacy view whenever the scene is inactive and expires the authenticated session on background.

Why: A user who enables a privacy barrier must never see content merely because biometrics or the device passcode is unavailable. The app-switcher snapshot is a separate disclosure surface and needs protection even when App Lock is off.

Impact: Lock copy describes screen access protection rather than storage encryption. Automated tests cover unavailable, failure, and success states; enrolled-device Face ID/passcode behavior remains a release-matrix gate.

## 2026-07-11: Add Is a Real Manual Capture Surface

Decision: Keep the center Add tab, but replace its demo card with Link, Text, Photo, and Memo capture. Link input normalizes http/https URLs and shows exact canonical duplicates; Photo uses PhotosPicker and the same original-file limits; all types use existing folder/tag controls and the repository transaction.

Why: A primary navigation action that creates a hardcoded brunch sample breaks product trust and App Review minimum functionality. Manual capture complements, rather than replaces, the Share Extension.

Impact: No production action creates sample clips. Exact URL duplicates are disclosed and may be saved separately; fuzzy or perceptual duplicate merging remains intentionally deferred.

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

## 2026-07-11: Keyboard Is Raised Only by Direct User Taps

Decision: No screen or workflow sheet requests text-field focus programmatically. The keyboard opens only when the user taps the search field or an editor, is prewarmed once right after launch with a zero-frame responder, and is dismissed by outside taps in search and by every bottom-tab switch.

Why: Programmatic focus raced view attachment, producing the `containerToPush is nil` input-assistant warning, unpredictable keyboard pop-ups when entering tabs or sheets, and a laggy-feeling first presentation. Tap-only focus plus a one-time prewarm makes every keyboard appearance user-initiated and immediate.

Impact: `sheetFocusDelay` was removed from the token contract, Search/new-folder/rename flows no longer auto-focus, the warning is absent from captured simulator logs, and DESIGN.md's motion section documents the policy.

## 2026-07-11: Detail Reads as One Viewport

Decision: The clip-detail read flow — badges through the 링크 열기 action — must fit a 6.3" screen without scrolling. Preview media is capped at 140pt and the note editor opens at a 72pt minimum; whitespace keeps the 16pt rhythm instead of growing media.

Why: At 220pt of media plus a 104pt editor the primary action fell below the fold, and the requested fix was explicitly to shrink media rather than tighten breathing room.

Impact: `size.detailImageHeight` changed to 140px, `size.noteEditorMinHeight` was added, and Sort Later/Add previews share the same compact height. Fill-mode thumbnails are now clipped at their real frame (overlay-on-proposal composition), which the smaller viewport exposed as an overflow bug.

## 2026-07-11: Selected App Language Is the Runtime Locale

Decision: Persist Korean, English, or Japanese in the existing preferences model, inject the matching SwiftUI locale, and resolve shared-extension copy from the same App Group configuration.

Why: The previous language row was decorative. One persisted selection now controls app UI, accessibility labels, default sample content, errors, toasts, Face ID purpose text, and Share Extension copy without maintaining duplicate state sources.

Impact: Language changes apply immediately, old backups fall back safely, and the app and extension remain consistent even when the containing app is closed.

## 2026-07-11: Share Capture Has Quick and Review Modes

Decision: Store a `quick` or `review` Share mode in App Group preferences. Quick mode queues immediately and displays one compact success card; review mode allows folder and memo changes before queueing.

Why: Users need both a low-friction capture path and an intentional organization path, chosen once in Settings rather than decided through a second confirmation on every quick save.

Impact: Fresh installs default to quick save. The system-owned extension sheet remains under iOS control, while the extension opts out of full-screen presentation and limits its own content to either the compact status card or focused review form.

## 2026-07-11: Release Metadata Describes a Local-Only Product

Decision: Ship privacy manifests for the app and extension, declare only the required UserDefaults reasons used by the current implementation, and prepare ASO/privacy copy around local capture and organization rather than unimplemented cloud features.

Why: Store metadata, privacy declarations, and review notes must match the binary. Inventing support URLs, contact details, or remote services would make the submission inaccurate.

Impact: Repository-owned release material is ready under `docs/app-store/`; owned HTTPS support/privacy URLs, a monitored email, App Store Connect answers, signing, physical-device verification, and upload remain explicit external gates.

## 2026-07-11: Keyboard Chrome Does Not Move With Input

Decision: Keep tap-only focus and launch prewarming, install one non-cancelling outside-tap dismiss recognizer per SwiftUI host, and hide the bottom navigation for the lifetime of the software keyboard. The existing tag-selection sheet intentionally opts out of the new outside-tap policy.

Why: Letting `safeAreaInset` react to the keyboard lifted all five bottom tabs and made first input presentation feel heavier. Ignoring the keyboard safe area globally prevented text editors from scrolling above the keyboard, so hiding only the navigation preserves normal iOS input avoidance.

Impact: Add, search, detail note, folder naming, clip editing, settings tag management, and Share review inputs dismiss on non-input taps. Text inputs still scroll into view, while the bottom menu never appears above the keyboard.

## 2026-07-11: Tag Catalog Persists Beside the Version-2 Snapshot

Decision: Persist the reusable tag catalog in app `UserDefaults`, while clip tag assignments and folder default-tag references remain in the existing version-2 JSON snapshot. Global rename/delete mutates every reference before persisting both stores.

Why: A first-class catalog is required for managing names and deletions, but changing the backup schema would break the documented web/native version-2 compatibility contract. This follows the existing recent-search precedent for local UI state outside the backup.

Impact: Settings can add, rename, and delete tags. Imported/edited clip tags merge into the catalog, delete-all restores suggested defaults, and twelve XCTest regressions cover reference propagation and reload behavior.

## 2026-07-11: Dark Mode Uses Adaptive Warm-Neutral Tokens

Decision: Every production color token resolves to a light and dark value, and Settings offers Light, Dark, or System. Dark mode uses warm near-black surfaces, warm off-white text, tonal dividers, and the same single yellow accent; Share Extension configuration receives the selected theme through the App Group.

Why: A color-scheme override without adaptive tokens would only invert system chrome and leave app surfaces unreadable. A paired token contract keeps contrast and the existing productive-minimal identity consistent.

Impact: The app updates immediately when the preference is saved, old backups still normalize to Light, and the Share Extension adopts the app choice when it launches.

## 2026-07-11: Default Folders Teach Renaming Instead of Prescribing Categories

Decision: Fresh and reset data shows `전체`, `기본 폴더`, then `폴더 1` through `폴더 5`. Existing user-created folder names are not destructively migrated.

Why: Preset category names such as screenshots, interiors, references, ideas, or travel imply a fixed taxonomy. Generic numbered folders make the rename affordance and user ownership explicit while preserving the aggregate and incoming destinations.

Impact: `기본 폴더` is always the second row and the default Share destination. Sample clips distribute across the five numbered folders; existing persisted installations keep their chosen names until reset or manual rename.

## 2026-07-11: Shared Images Preserve Their Original Representation

Decision: If a Share payload exposes any image provider, classify it as an image before inspecting URL/text providers. Copy the provider's supported PNG, JPEG, HEIC, HEIF, TIFF, GIF, or WebP representation unchanged into the App Group and retain its UUID filename extension.

Why: Photos and image-oriented share sources can expose both a file URL and image data. URL-first parsing saved those captures as links, while the previous 1600px JPEG 0.82 normalization discarded pixels and introduced compression loss.

Impact: Image shares have an empty external URL, render from the local file in rows/detail/full-screen zoom, and preserve source bytes and dimensions. Storage usage now matches the original file size. Filename validation and cleanup cover the supported extension set.

## 2026-07-11: Link Confirmation Is Optional and Defaults to Direct Open

Decision: Persist link-opening behavior separately from the version-2 backup as `direct` or `confirm`, with `direct` as the fresh/reset default. Detail and card-menu actions share the same policy.

Why: Frequent link opening should stay one tap by default, while users who want an external-browser boundary can opt into the existing confirmation dialog without changing clip data or the cross-platform backup schema.

Impact: Settings shows `링크 열기 방식`; `바로 열기` opens immediately and `열기 전 확인` presents the browser question. The choice survives relaunch and resets with all local data.

## 2026-07-11: Share Configuration Uses a File and Keyboard Prewarming Is Removed

Decision: Store the Share Extension configuration as one atomic App Group JSON file, migrate the legacy preference plist without invoking CFPrefs, and remove the launch-time zero-frame text-field first-responder cycle.

Why: The configuration was already a single Codable blob, so CFPrefs added no benefit and produced a simulator AnyUser/container warning. Synthetic keyboard prewarming connected and immediately detached private text-input reporters, producing `Reporter disconnected` noise.

Impact: App and extension configuration remains cross-process and atomic, legacy values migrate on first read, and the keyboard still appears only after an actual user tap. The CA launch-measurement message remains OS telemetry, not an app failure. A Share Extension cannot legally auto-open the containing app on iOS, and share-sheet Favorites order remains user-controlled.
