# Round 3, package R3-A: layout, typography and accessibility on every phone size

- Date: 2026-11-28 · Branch: `feat/r3-layout-type-a11y` · Base: `origin/feat/simple-add-expense` @ 0be9c99, then
  merged with R3-B (603cf50) · Decisions S-440..S-449 · No migrations

## Summary

- **Size matrix (S-440/S-441):** `test/goldens/r3_sizes_golden_test.dart` renders 30 screens and sheets (catalogue
  `r3_screens.dart`) on 320×568, 360×640, 393×852, 412×915, 480×1000, 600×960 and 840×1200 at text 0.85/1.0/1.3/2.0
  side by side, plus dark at 393×852. Every picture fails on overflow and runs the a11y guidelines (48 dp, labels,
  tap actions) plus two new ones: text contrast against the colour really behind it, and tabular figures on every
  standalone amount. Reviewed twice with real fonts by four/five reviewers (60 + 40 findings), fixed, re-run clean.
- **Type (S-442/S-443):** the hand-set sizes became tokens (`displayLarge`, `amountLarge`, `labelCapsLarge`, `input`);
  guard `type-scale-only` forbids literal `fontSize:` outside the theme; list amounts use `amount` (tabular) everywhere.
- **Tablets / open foldables (S-444):** content keeps phone proportions in a centred 560 dp column (`ContentWidth`,
  `SliverContentWidth`, `PageBody`) while heroes and backgrounds stay full-bleed; sheets ≤ 640 dp; capsule nav ≤ 520 dp
  with a content-sized active pill; Groups grid gets a third column; hero buttons stay at the screen edges.
- **Small phones / large text (S-446/S-447):** width-based row stacking (`context.stackRows`), pinned bars stack and
  clamp to 1.5× on short phones, heroes tighten and drop decorative taglines under 700 dp, the group hero starts
  folded there, the welcome drops its preview when short, tabs/segments drop icons before shrinking labels, the
  amount field shrinks digits to fit, setting labels never break mid-word, e-mail addresses break only after @ and
  dots, nav labels drawn whole or not at all, avatar stacks no longer hide initials.
- **Contrast (S-445):** `textSecondary` #616F7F (4.5:1 on chips too), darker peach/mint initials, placeholders in
  `textSecondary`, coral/lime amounts on the lavender hero moved onto dark chips; token-pair test extended.
- **Accessibility:** TalkBack order = reading order on all 30 screens at 412, 320 and text 2.0 (`r3_a11y_test.dart`);
  errors and saves are live regions; reduced motion handled by R3-B.

## Tests

| Suite | Result |
| --- | --- |
| Size matrix (30 × 7 × 4 + dark) | 240 CI goldens, all pass incl. contrast + tabular guidelines |
| `contrast_test.dart` | 83 pass (token pairs light/dark + avatar tints) |
| `r3_responsive_test.dart`, `capsule_nav_bar_test.dart`, `r3_money_grouping_test.dart` | 23 pass |
| `r3_a11y_test.dart` | 92 pass |
| Full suite after merging R3-B, 3 chunks, `--concurrency=1`, coverage | 4,718 pass; 11 failed and were fixed and re-run green: the scrim test now scrolls the home's CustomScrollView (R3-B lazy grid), the code-screen test ignores the e-mail's break hints, the join carousel swipe covers a full page, the matrix group form uses the edit route (the new form's autofocus caret blinked) |
| Gates | format clean, analyze 0 errors / 0 warnings, guards OK (incl. `type-scale-only` and R3-B's haptics rule), coverage 95.0 % overall (presentation 95.1 %, money 100 %, sync 99.5 %) |

## Device

Before shots (`splitify-artifacts\screenshots\r3a-before-*.png`): 10 key screens at font 1.0/0.85/1.3/2.0 and the
small display for home and group. After: the emulator could no longer run (S-449: `wm density` froze it three
times; then the window failed with GetDC 0x486 — Windows out of USER handles, the rundll32 leak — and the headless
emulator crashed when the app drew), so the after set is the real-font matrix renders
(`r3a-after-golden-*.png`). Owner action: reboot the PC to clear the leaked handles before the next device round.
