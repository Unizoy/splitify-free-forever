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

## Motion review (flows since D-032)

| Flow | What moves now (all instant with "remove animations") |
| --- | --- |
| Single-screen editor | Inline errors fold in/out under their field (error haptic on Save); people chips fade/scale in, the row reflows (AnimatedSize); Save: success haptic, self-drawing check, page closes after 420 ms (was 700), snackbar with a check; the new row grows into the group list |
| Payer/split sheet | Sheet rise unchanged (300 ms emphasized, closes in 150 ms); payer pills ease between looks; "Multiple people" folds open; a new split kind cross-fades its rows while the sheet's height follows |
| Items | A new line grows in, a removed one closes the gap; tax/tip/discount fold open; person toggles already eased |
| Scan review | Reading → found lines (or the failure) cross-fade, the sheet's height follows |
| Settle up / record payment | Error haptic on problems; success haptic + check snackbar; "all settled" celebration unchanged (leak fixed) |
| Batch settle | Same as settle up |
| Loan | Error/success haptics, check snackbar |
| Attachments viewer | A photo flies from its tile into the viewer over a fading black page (240/200 ms); PDFs unchanged |
| Group form | People added grow in; type chips ease; success/error haptics; check snackbar on edit |
| Invite / join | Code → preview cross-fade; error haptic on invalid/pasted/QR codes |
| With-you-and picker | Picks close the sheet at once (nothing added: motion would only slow it) |
| Friend code | Success haptic + check snackbar; error haptic on bad codes |
| Whiteboard | Success haptic + check toast; error haptic when too long |
| Filters | Chips ease (IconChip); a new Groups filter replays the cards' rise; search filter chips ease |
| Monthly card | × folds the card away |
| Show in INR | Home total and friend pill cross-fade in place; the chip eases |
| Restore | Deleted note folds away, Deleted pill cross-fades to the status; success haptic + check snackbar |
| Settled history | Unfolded rows grow in (group page and friend page) |
| Who owes whom | Group hero lines fold open from the top and fade in |
| Totals | Home total counts (S-264, unchanged); group and friend status pills cross-fade when the balance changes |

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
