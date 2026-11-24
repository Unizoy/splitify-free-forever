# UI report — Welcome redesign (D-029)

- Date: 2026-11-24 · Branch: `ui/welcome-redesign` · Base: `origin/main` (652cb01)
- Status: done · Decisions: S-280..S-287

## Summary

The first screen now looks like the rest of the app: the Groups hero's lavender → dusk background over the
whole page, a product preview (a trip and a home cover fanned behind the frosted "Overall" card), the serif
"split it. / settle it." headline with the lime second line, three glass feature chips, a white
"Get started →" pill and "Have an invite? Join a group". Same look in light and dark mode; the launch splash
now has the welcome's top colour, so splash → welcome is seamless. An invite opened while signed out now
survives sign-in and opens right after the profile step (before: the code was lost).

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| Background = Groups hero (gradient + art + grain), darker toward the bottom, light + dark the same | done | `HeroBackground` made public (S-280) |
| Top bar: mark + SPLITIFY, lime "Free forever · no ads" pill | done | wraps at large text |
| Product preview: 2 `GroupCoverCard`s fanned ±8° + Groups-style `GlassCard`, entrance ≤ 350 ms, idle float, reduced motion static | done | S-281; covers drop their footer (`GroupCoverCard.footer`) |
| Headline, subline, feature chips | done | S-282 |
| "Get started" white pill + arrow (haptic), "Have an invite? Join a group", footer | done | `PillButton.trailingIcon` |
| Join flow signed out | done | S-283 `PendingJoin`: `/join` → sign-in → profile → `/join?code=…` |
| Layout small → tall phones, landscape, 200 % text | done | S-285 |
| DashedCircleButton off the welcome; two-line ARB string dropped | done | component kept (gallery, final-QA test) |
| Native splash colour | done | S-286 |
| Shared-axis transition to sign-in | done | S-284; found go_router 18 makes every plain GoRoute a `NoTransitionPage` (app-wide) |

## Tests

- New: widget 23 (`test/features/onboarding/welcome_screen_test.dart`), golden 2 new + 4 re-recorded
  (`test/goldens/welcome_golden_test.dart`, `screen_welcome_*`), updated `test/app/app_test.dart` and
  `integration_test/app_smoke_test.dart` (Get started by key).
- Test IDs: TC-W-01..TC-W-04 (`planning/10-test-catalog.md`).

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | `dart format` clean, `flutter analyze --no-fatal-infos` 0 errors/warnings, `dart run tool/guards.dart` OK |
| G2 Tests | PASS | `flutter test --coverage --exclude-tags device,needs-owner,quarantine`: 3,429 passed; coverage overall 95.3 %, domain 98.3 %, data 91.2 %, sync 99.5 % |
| G3 Backend | SKIPPED | no migrations, RPCs or functions touched |
| G4 Build | PASS | `flutter build apk --debug` OK; release x64 preview build OK |
| G5 Device | PASS | emulator-5554, release x64 `integration_test/support/welcome_preview_main.dart` (S-287), lock held 12:37–12:43; owner's APK restored, data intact |
| G6 Docs | PASS | 00-decisions (D-029, S-280..S-287), 06, 07, 10-test-catalog, LEARNINGS |

Screenshots: `C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\screenshots\welcome-v2-light.png`,
`welcome-v2-dark.png`, `welcome-v2-text200.png`, `welcome-v2-text200-scrolled.png`, `welcome-v2-splash.png`.

## UI review (ui-review rubric, real fonts + device; light and dark are the same screen)

| Criterion | Score | Notes |
| --- | --- | --- |
| Atlys feel | 9 | hero gradient, frosted glass card, serif headline, white pill CTA, tilted cover cards (Atlys 438) |
| Typography | 9 | serif 42 headline / Inter body, caps labels; preview text fixed (illustration) |
| Layout & spacing | 9 | 20 dp margins, 4 dp rhythm, chips on one row at 412 dp, actions at the bottom on tall phones |
| Colour & contrast | 9 | tokens only; lime = owed colour; footer 50 % white ≈ 4.7:1 on the deep blue |
| Signature elements | 9 | hero, glass card, group covers, lime highlight word |
| Polish | 9 | no stray divider (footer-less covers), shadows on covers, no clipping at 2.0 |
| States | 8 | small phone (glass only), text 1.3 (smaller fan), text 2.0 (scrolls), reduced motion (static) |

## Decisions made

S-280 background/theme · S-281 preview + motion · S-282 type and chrome · S-283 join before sign-in ·
S-284 page transitions (go_router/material_ui finding) · S-285 layout · S-286 splash · S-287 device capture.

## S-288 (coordinator): page transitions app-wide

go_router 18 checks for `material_ui`'s `MaterialApp`, so every plain `builder:` GoRoute was a `NoTransitionPage`
(S-262's shared axis and the S-263 hero flights never ran). Now every route is an `AppRoute` (Flutter
`MaterialPage`), the tab shell is a page, the group page and expense detail draw on their first frame so the
cover/icon heroes fly, and the page colour sits behind all routes. Full suite 3,433 passed (no timing fixes or
golden changes needed); emulator (lock 13:04–13:10): pushing into a group, an expense, group settings and back
all animate; the owner's app is the branch build (pinned, release x64), still signed in with its data. Owner's
previous APK kept at `splitify-artifacts\apk\owner-installed-backup-2026-11-24.apk`.
