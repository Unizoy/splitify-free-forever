# Round 3, package R3-B: motion, haptics and performance

- Date: 2026-11-28 · Branch: `feat/r3-motion-perf` · Base: `origin/feat/simple-add-expense` @ 0be9c99
- Decisions S-450..S-458 · No migrations · Parallel package R3-A (layout/type/a11y) owns screen layout

## Summary

- **Motion kit (S-451/S-452):** short, purposeful moves where something changed, never blocking a tap, instant
  with "remove animations": rows that arrive grow in (saved expense back in its group, synced rows, comments,
  activity, new groups, people and items in the editor), sections open in place (who owes whom, settled history,
  "multiple people", tax/tip/discount), values cross-fade in place (Show in INR, simplified/original, split kind,
  group/friend status pills, deleted ↔ restored, scan reading → results, join code → preview, the monthly card's ×,
  inline errors), chips and payer pills ease between looks, a photo flies from its tile into the viewer, and a
  self-drawing check confirms saves (editor overlay 700 → 420 ms, check in success snackbars).
- **Haptics (S-453):** one helper — selection, light, success (Android 11+ CONFIRM), error (REJECT); a guard
  forbids raw `HapticFeedback` calls. Error ticks on Save problems and invalid codes; success on every save/settle.
- **Performance (S-454/S-455):** lazy Groups grid; list streams drop equal re-reads and reloads coalesce (sync
  storms gone); payer/share JSON decodes once; Insights over ≥ 1,500 expenses on another isolate; undisposed
  `CurvedAnimation`s fixed (S-457).
- **Startup (S-456):** push, crash reports, WorkManager, the bell refresh, FX refresh and the home widget start
  600 ms after the first frame.

## Numbers (profile, emulator-5554, software raster; `tool/e2e/perf_r3.ps1`)

Data: 50 groups, 5,038 expenses (one group of 2,000), seeded like a pull. Before = 704f73c (harness only, built
from a detached worktree), after = this branch. One run each unless noted (the shared PC is noisy: other
agents build in parallel).

| Measure | Before | After |
| --- | --- | --- |
| Groups home: first cards on screen | 8,459 ms | 1,271 ms |
| Groups home open: worst build / raster avg | 493 / 247 ms | 230 / 33 ms |
| Groups scroll (500 frames): worst build / raster avg | 16.3 / 11.5 ms | 7.2 / 9.3 ms |
| 2,000-expense group: open worst build | 59.8 ms | 38.7 ms |
| Sync storm (10 pulls into other groups while the group is open): frames over 16 ms build / p90 | 10 of 61 / 17.8 ms | 0 / 0.5 ms |
| Editor: ready / worst build | 158 / 43 ms | 99 / 28 ms |
| Insights (all groups): first frame / worst build | 316 / 296 ms | 66 / 27 ms |
| RSS before → after opening group, editor, Insights 20× (max) | 389 → 387 MB (404) | 359 → 353 MB (367) |
| Cold start (runs 2–6, median): main → runApp / main → first frame / `am start -W` | 252 / 597 / 2,256 ms | 194 / 445 / 1,953 ms |

## Tests

See the final section (filled at the end of the session).
