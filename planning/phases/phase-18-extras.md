# Phase 18 — Import from Splitwise, app lock, home-screen widget (X1, X2, X3)

- Depends on: 15 · Owner setup: 00 · Branch: `phase/18-extras`
- Read first: `08-feature-specs.md` X1–X3, `research/01-product-research.md` §4 (CSV format + parser lessons),
  `research/04` (local_auth, home_widget notes).

## Tasks

- [ ] T1 X1 parser (`csv` package): BOM, quotes, header check, totals row as checksum, payments rows, per-currency,
      exponent-aware string → minor units (no floats). Fixtures in `test/fixtures/splitwise/` (hand-written from
      the documented format: simple, multi-currency, multi-payer, payments, JPY, quoted commas).
- [ ] T2 X1 reconstruction (single payer exact; multi-payer as nets with cost in notes) — nets must equal the file.
- [ ] T3 X1 UI: entry points (group settings, Account), file pick, member mapping (existing / new name-only / skip),
      preview with totals check, import through outbox with `source='import'` + batch id, result, "Delete this
      import". Server: suppress per-row activity for `source='import'`, write `import_completed`.
- [ ] T4 X2 App lock: settings (off/on, timeout 1/5/15 min), `local_auth` (biometric or device credential), lock
      screen on cold start and resume after timeout, hide content in recents while locked.
- [ ] T5 X3 Widget: `home_widget` + Android widget layouts 2×2 and 4×2 (RemoteViews XML following the design
      tokens as closely as RemoteViews allow), data written after sync/local writes, "Hide amounts" option, tap
      opens app.

## Tests

TC-X1-01…04, TC-X2-01…02, TC-X3-01…02, TC-22-02 (export → import round trip).

Pre-built (phase 06 session, branch prep/splitwise-import): parser + reconstruction (T1, T2 core); UI/mapping still T3
