# Phase X5 report — Auto-category and two Android flavours (D-028)

- Date: 2026-11-23 · Branch: `phase/x5-autocategory-flavors` · Base: `origin/main` (incl. PR #26 motion polish)
- Status: done

## Summary

Typing an expense description now picks the category like Splitwise: "Swiggy" → Food · Takeaway, "Uber" → Travel ·
Cab & auto, "electricity bill" → Utilities · Electricity, about 1,000 India-first brands and words, with Hindi words
and UPI IDs. The chip under the description changes as you type and shows a small "Auto" tag. A category you pick by
hand sticks, and the app remembers it for that description next time. Payment-bubble captures and Splitwise imports
without a category get the suggestion too.

The Android app is now built in two flavours with the same app id. `standard` (the default and the GitHub APK) has no
payment bubble and so declares no accessibility, notification-listener or "display over other apps" permission, which
Google Play Protect's India fraud protection blocks for sideloaded apps. `full` keeps the bubble for adb installs and
a future Play Store listing.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| A1 keyword asset + `CategorySuggester` (pure Dart) | done | `assets/category_keywords.json` v1, `lib/domain/rules/category_suggester.dart` (S-270, S-277) |
| A2 learning (per user, phone only) | done | `lib/data/local/category_memory.dart`, `CategorySuggester.lessons` (S-272) |
| A3 editor UX (debounce, cross-fade, Auto tag, manual pick sticks, edits never change) | done | `ExpenseDraft.categoryOrigin`, `CategoryHint` on step 1, Auto tag on Details (S-271) |
| A4 captures, imports, recurring | done | capture prefill and import rows use the suggestion; repeating copies inherit the template's category (S-273) |
| A5 ARB, goldens, widget tests, emulator check | done | see Tests / Gates |
| B1 Gradle flavours `standard` (default) / `full`, same applicationId | done | `android/app/build.gradle.kts`, pubspec `default-flavor` (S-274) |
| B2 bubble only in `full` (manifest, Kotlin, res, assets, JVM tests) | done | `src/full`, `src/testFull`, stub channel in `src/standard` (S-274, S-275) |
| B3 Dart gate (row, routes, Payments to add) | done | `BuildFlavor.capture`, bridge `supported`, router `capture:` (S-275) |
| B4 scripts and docs | done | `tool/build_release.ps1` (both flavours, arm64 + universal, aapt2 check), e2e scripts, README, skills (S-276) |
| QA: Groups cold first frame (coordinator) | done | noise, not a regression; glass snapshot now taken once the screen settles (S-279, branch `qa/groups-first-frame` merged in) |

## Tests

- New tests: unit 248 (208 description vectors) · widget 8 · golden 8 (2 states × light/dark × text 1.0/2.0; 4
  amount-step goldens re-recorded for the new chip) · Kotlin JVM 13 moved to `src/testFull` and passing.
- Test IDs: TC-X5-01 … TC-X5-06 (planning/10-test-catalog.md).

## Gates

See the final gate table at the end of this file.

## Decisions made

S-270 … S-277 (planning/00-decisions.md); S-279 by the Groups first-frame investigation.

## Blockers

None.

## Owner actions

- Optional: install the `standard` APK from `build\release-apks\splitify-standard-universal.apk` (or arm64) on your
  phone; it updates the installed test build in place. To keep the payment bubble, install the `full` APK instead
  (only one can be installed at a time).
- Users on ISPs that block `supabase.co` still need a custom domain/proxy before release (unchanged).
