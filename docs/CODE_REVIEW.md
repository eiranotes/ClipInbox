# Code Review Checklist

Use this checklist before committing UI changes.

- Correctness: Screen navigation, buttons, filters, search, saved toast, empty state, and Sort Later flow work.
- Maintainability: Components stay small, token usage stays centralized, and duplicate visual systems are not introduced.
- UX behavior: No sports, ranking, prediction, gamification, social, login, server, or subscription UI appears.
- State consistency: Inbox, detail, add, search, and sort state transitions are predictable.
- Error and edge states: Fallback preview, preview loading, disabled saved state, and search empty state are visible.
- Test/build impact: Typecheck, production build, token compliance, and browser QA run before commit.
- Documentation freshness: `PROJECT_STATUS.md`, `TASKS.md`, `DECISIONS.md`, and `CHANGELOG.md` reflect the current state.
- Commit readiness: Diff is focused and Conventional Commit style is used.
