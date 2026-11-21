# Phase 02 report — Design system and app shell

- Date: 2026-11-21 · Branch: `phase/02-design-system` · Base: `origin/phase/01-bootstrap` (phase 01 not merged into `main` yet)
- Commits: `8480b28..HEAD` (start, theme, components, brand, shell, guards, fixes, tests, report) · Status: done

## Summary

The app now has its Atlys-style look as reusable code: colour/type/spacing/motion tokens (light + dark), bundled
Instrument Serif + Inter + Phosphor icon fonts, ~35 design-system components, seeded generated group covers, the
app icon and splash, and a working shell: Welcome → Groups / Friends / Activity / Account in the floating capsule
nav with the amber add button, an Account settings sheet and an Appearance page (System / Light / Dark, saved on
the phone). A debug-only component gallery (`/debug/gallery`) shows every component; golden tests lock the look.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 Fonts | done | Instrument Serif (Regular, Italic), Inter variable from `google/fonts`; OFL files + `LicenseRegistry` (plus Phosphor MIT, S-008) |
| T2 Theme | done | `lib/ui/theme/`: `AppColors`/`AppText` ThemeExtensions with lerp, spacing, radii + shadows, motion (spring curve, reduced motion), `AppTheme`, `context.colors/text/motion`, `AppIcons` |
| T3 B3 theme mode | done | `ThemeModeController` (Riverpod codegen) on `shared_preferences`, loaded in bootstrap before `runApp` |
| T4 Components | done | all of §6 + helpers (DotsPulse, TintedIcon, DashedDivider, StatGrid, BrandMark, OverlapColumn render object); painters: dashed, noise (tiled, S-009), dot matrix, gauge, wallet, folder tab, brand mark |
| T5 Covers | done | `CoverPainter` (seeded mesh, grain, legibility scrim, dark dim) + `CoverCache`/`CoverArt` (LRU 48, key family/seed/size/dpr/brightness); golden per family (gallery "covers") |
| T6 Brand | done | `assets/brand/icon.svg` + PNGs rendered from `BrandMarkPainter`; adaptive + monochrome icon; Android 12 splash (S-011) |
| T7 Shell | done | `StatefulShellRoute` 4 tabs, Welcome `/welcome`, Account per 07 §2 (S-014), settings sheet, `/account/appearance` |
| T8 Gallery | done | `/debug/gallery` (kDebugMode only), 10 sections shared with goldens |
| T9 Goldens + a11y | done | alchemist CI goldens (46), contrast helper over every token pair, tap-target/label guidelines on all sections |
| T10 UI review | done | emulator screenshots light/dark/200 % + real-font gallery goldens; scores below |

## Features delivered

- B3 Appearance (Light / Dark / System, persisted) — complete.
- UI foundations for every later feature (components, covers, shell). No money/data features yet (by plan).

## Tests

- `flutter test` runs 146 tests (phase 01 had 11). New files: theme-mode controller (7 unit), appearance screen
  (TC-B3-01 widget), theme/lerp/motion (5 unit + 2 widget), contrast over every token pair (light + dark),
  stable hash (2), cover painter/cache (2 unit + 3 widget), a11y guidelines over all 10 gallery sections, and 46
  goldens (CI variant): 10 gallery sections × text 1.0/2.0, group cards × 2, 6 screens × light/dark × 1.0/2.0.
  Integration smoke test updated (welcome → shell).
- Coverage: overall 92.8 % · core 93.0 % · application 100 % · presentation 92.7 % (all floors met)
- Test IDs now passing: TC-B3-01, TC-B3-02, TC-B3-03, TC-1-05 (fake data; phase 07 re-checks with real groups)
- Quarantined / skipped: none (the two a11y failures found — 44 dp medium button, unlabeled stepper buttons — were fixed)

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | format 0 changes (`lib test integration_test tool`), `flutter analyze` 0 errors / 0 warnings (infos only: deprecated `material.dart` import, S-001), `guards: OK` incl. new `ui-tokens-only` rule |
| G2 Tests | PASS | 146 passed, 0 failed; coverage floors PASS (above) |
| G3 Backend | N/A | no SQL / Edge Function work in phase 02 |
| G4 Build | PASS | `flutter build apk --debug` 105 s; release x64 APK 38.8 MB also builds |
| G5 Device | PASS | `integration_test/app_smoke_test.dart` on emulator-5554: 1/1; UI review screenshots in `C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\phase-02\` |
| G6 Docs | PASS | phase ticks, PROGRESS, catalog, S-005…S-015, LEARNINGS, this report |

### UI review scores (D-018, ≥ 8 required; light and dark checked)

| Screen | Atlys feel | Type | Layout | Colour | Signature | Polish | States |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Welcome (455) | 9 | 9 | 8 | 9 | 9 | 8 | 8 |
| Groups home (438) | 9 | 9 | 9 | 9 | 9 | 8 | 8 |
| Friends | 8 | 9 | 9 | 9 | 8 | 8 | 8 |
| Activity (636 blobs) | 8 | 9 | 8 | 9 | 8 | 8 | 8 |
| Account (542) | 9 | 9 | 8 | 9 | 9 | 8 | 8 |
| Account settings sheet (614/623) | 9 | 9 | 9 | 9 | 8 | 9 | 8 |
| Appearance | 8 | 9 | 8 | 9 | 8 | 8 | 8 |
| Gallery sections (goldens) | 9 | 9 | 8 | 9 | 9 | 8 | 8 |

Fixed during review: settings sheet opened under the nav (now root navigator); accordion values not right-aligned
and breaking mid-word at 200 % (stacked layout); glass-card header squeezed at 200 % (wraps); nav label clipped at
200 % (cap 1.15×, S-015); card footer label clipped; step connectors looked dashed; "Create a group" wrapped;
grain noise looked like glitter on the wallet; globe silhouette faint. Accepted deviations: Celebration sits on a
navy panel (lime on white fails AA); secondary buttons 48 dp (S-006); tab screens show empty states only (no data
until phases 07–11), so loading/error/offline states are reviewed in the gallery (StackedCardsLoader, SyncMarker,
EmptyState) rather than on screens.

## Decisions made (S-0xx)

S-005 extra colour tokens · S-006 48 dp secondary buttons · S-007 only CI goldens committed · S-008 vendored
Phosphor fonts · S-009 tiled grain (Impeller stall) · S-010 commit Riverpod `.g.dart` · S-011 brand PNG pipeline +
splash style patch · S-012 `/welcome` start + honest empty tabs · S-013 gallery sample data in Dart · S-014 Account
follows 07 §2 · S-015 nav label scale cap. Amendments appended to `06-design-system.md` and the phase file.

## Blockers (BLK-xxx)

None.

## Learnings and skills added or changed

- 12 entries in `planning/LEARNINGS.md` (Impeller grain stall, debug APK black screen, phosphor compile error,
  splash tool rewriting styles, brand PNG pipeline, parallel flutter builds, regex `\b` via python, golden pumping).
- Skill `ui-review` updated: release-build capture path + new `scripts/ui.ps1` (tap by accessibility label,
  screenshots, dark mode, font scale) and `scripts/capture_shell.ps1` (light/dark/200 % passes).

## Owner actions

None required. Optional: open the emulator app (release build installed) and click through Welcome → tabs →
Account → gear → Appearance to see the look; tell a later session if you want any colour/shape changed.

## Next phase

03 Money engine (pure Dart). Phase 02 placeholders use an ARB `₹0` string; phase 03's formatter should replace it
(`groups_home_screen.dart`, `account_screen.dart`). Run screenshots with a release x64 build (see `ui-review`).
