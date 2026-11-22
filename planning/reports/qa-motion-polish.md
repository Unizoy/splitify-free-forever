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

PERF_TABLE

## Gates

GATES_TABLE
