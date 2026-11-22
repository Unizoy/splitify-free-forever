# QA pass: motion, smooth scrolling and type (2026-11-23)

Branch `qa/motion-polish` (owner request D-027). Decisions S-260 to S-269. No migrations.

Owner's words: "Animations on clicking are not present in many places — add them. Scrolling is not very smooth.
Keep futuristic things so it feels like a premium product. Keep fonts a bit smaller, take reference from Atlys
itself … don't make it feel slow."

## What changed

| Area | Change |
| --- | --- |
| Tap feedback | One primitive, `Pressable` (S-261): 0.97 press-in in 90 ms, spring back in 160 ms, faint highlight in the control's shape; rows 0.985, icon/circle buttons 0.9. The tap fires on finger up at once. Used by every design-system control (cards, rows, chips, tiles, tabs, nav items, + button, hero buttons, stepper, wallet) and by all 30 feature-level tap sites; 34 screens' icon buttons are `AppIconButton`; `PillButton` shares the same press. Haptics: selection on toggles/chips/tabs/nav, light on primary pills and +, medium on save (already there). |
| Transitions | Shared-axis horizontal push/pop, 280/240 ms (was 450 ms fade-forwards) (S-262). Fade-through between nav tabs with state kept; in-page tab content fades in; folder-tab fill cross-fades; sheets rise in 300 ms on an emphasized curve, close in 150 ms; nav pill morph 300 ms spring (was 800 ms). Hero flights: group card → group page (container transform, corners 28 → 0) and expense row icon → expense page (S-263). |
| Feedback in data | Groups-home total counts to its new value in ≤ 350 ms, integer minor units (S-264). First-load entrance for the first 8 rows of the groups grid, expense list, Activity, Friends and friend page (S-265). Skeletons shimmer (S-266). |
| Smooth scrolling | 90/120 Hz: `MainActivity` asks for the display's fastest mode (S-260). Glass card blur pre-rendered from the hero background instead of a live `BackdropFilter`; hero art fade baked into the cover cache (no live `ShaderMask`); hero and overlap sheet are repaint boundaries; Activity (≤ 300 rows) and friend-page items are lazy slivers (S-267). |
| Type | Scale one step down and tighter per Atlys: body 15, secondary 13, caption 11.5, labels 11 caps +1.4, titles 16, headline 20, sheet title 28, hero 34, amounts 34/15, buttons 16 (S-268). Hero amounts are Inter everywhere; serif only for words (S-269). |

## Frame timings (profile, emulator-5554, `integration_test/perf_screens_test.dart`)

Same seeded data (12 groups, 1,260 expenses, 300 activity rows), same scroll script (4 flings up, 2 down) on each
screen; before = `main` 3f3e70f (worktree `wmotion-base`), after = this branch, one lock window, back to back.
Logs: `splitify-artifacts/qa-motion/perf-before.log`, `perf-after.log`.

| Screen (scroll) | frames drawn | build avg / p90 / worst ms | raster avg / p90 ms | missed build |
| --- | --- | --- | --- | --- |
| Groups | 93 → 103 | 2.1 / 5.1 / 13 → 2.1 / 5.1 / 15 | 184 / 288 → 192 / 297 | 0 → 0 |
| Group page (600 expenses) | 85 → 102 | 5.2 / 11.8 / 95 → 1.6 / 3.5 / 5.9 | 352 / 518 → 144 / 184 | 5 → 0 |
| Activity (300 rows) | 61 → 105 | 2.5 / 3.6 / 32 → 2.1 / 4.9 / 16 | 169 / 234 → 143 / 182 | 2 → 1 |
| Friend page | 61 → 103 | 2.9 / 3.6 / 43 → 1.8 / 2.7 / 40 | 162 / 217 → 144 / 189 | 2 → 1 |

| Screen (open) | open ms | first frame ms | build worst ms |
| --- | --- | --- | --- |
| Group page | 6,263 → 5,275 | 163 → 80 | 319 → 182 |
| Activity | 20,646 → 5,110 | 433 → 78 | 6,779 → 35 |
| Friend page | 5,856 → 4,534 | 1,630 → 265 | 1,588 → 231 |
| Groups (the app's first frames) | 8,313 → 11,608 | 404 → 1,889 | 80 → 1,085 |

Reading them: the emulator rasterises in software (150–350 ms a frame on this PC, so every frame misses the raster
budget before and after); the useful signals are the UI-thread build times, the raster drop on the group page
(glass/shader-mask work gone) and the number of frames drawn in the same timed script (+10–70 %). The Groups
"open" row is the app's cold first frame (database, fonts, pipelines) and swings run to run on this shared PC (the
seed step alone went 1,560 → 708 ms); it is not a scroll number. Real-phone 90/120 Hz checks are on the owner
checklist.


## Gates

GATES_TABLE
