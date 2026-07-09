# Visual QA

## Scope

Clip Inbox Trello-token static prototype based on `clip_inbox_trello_token_ui_spec_v1_5.md` and the local `Reference/*.png` images.

## Captured Evidence

Responsive baseline:

- `mobile-390.png`
- `tablet-768.png`
- `desktop-1280.png`

Interactive and state coverage:

- `state-search-empty.png`
- `state-add-saved.png`
- `state-detail.png`
- `state-folders.png`
- `state-settings.png`
- `interaction-sort-later.png`

## Browser QA

Command:

```sh
npm run qa
```

Result:

```json
{
  "ok": true,
  "baseUrl": "http://127.0.0.1:4173",
  "findings": [
    { "viewport": "mobile-390", "horizontalOverflow": false },
    { "viewport": "tablet-768", "horizontalOverflow": false },
    { "viewport": "desktop-1280", "horizontalOverflow": false }
  ]
}
```

## Anti-Slop Pre-Flight

- [x] Zero visible em-dashes in app source.
- [x] No sports, ranking, prediction, voting, leaderboard, or gamification UI.
- [x] No AI-purple glow or generic gradient default.
- [x] System font stack is intentional for an iOS-first utility app.
- [x] Warm background, black outlines, yellow accent, and pastel type badges match the v1.5 token direction.
- [x] Real local cropped image assets are used for clip thumbnails.
- [x] Fallback preview card is a valid saved state, not an error state.
- [x] Search empty, preview loading, saved disabled, fallback media, and sort-later states are present.
- [x] Motion uses transform or opacity transitions and respects reduced motion.
- [x] No horizontal page scroll at 390, 768, or 1280 px.

## Open Design MCP Note

Open Design `tools-dev` was started and the daemon/web/desktop processes came up on dynamic ports. The MCP connector in this session still attempted `http://127.0.0.1:7456` and could not reach a project context, so Open Design project operations were not available through the connector. The local reference images were used as the visual target instead.
