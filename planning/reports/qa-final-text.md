# Final QA pass 1: visuals and text (2026-11-22)

Branch `qa/final-text`. Decisions S-240 to S-249. No migrations.

## How it was reviewed

- All 580 real-font goldens (`PLATFORM_GOLDENS=1`, light and dark, text 1.0 and 2.0) were opened and scored
  against `06-design-system.md` and the ui-review rubric. Six read-only reviewers split the work by file prefix.
- Every string in `lib/l10n/app_en.arb` and `android/app/src/main/res/values*/` was read, along with the push texts
  built in `0016_notifications.sql` (read only, since this pass makes no migrations).
- README, CHANGELOG and the About screen were checked against what the app does.

## Fixed

| Area | What changed |
| --- | --- |
| Line breaks | No-break spaces keep these together: dates, times, "30 days", "10 minutes", "1 person", "made in India", and the word before " · ". A word joiner keeps a sign on its amount ("−$20"). This was the most common defect on screen ("20 / Nov", lines starting with "· 28 Oct"). |
| Text 2.0 | `StepHeader` labels use one clamped scale. `FolderTabs` and `SegmentedPill` labels share one scale, so there are no mid-word breaks such as "Syst/em" or "Equall/y". `DashedListRow` and capture access rows stack at large text ("Repe/ats", "Notificat/ion"). Group-card titles never break inside a word, and status labels wrap instead of clipping. Number badges grow with the text. The text inside the gauge and the donut stays inside the ring. |
| Copy | Split rows read "share ₹600.00" instead of "You owes". Length limits say "Use up to N characters" and match the ≤ N rules. Error messages have full stops, and comma splices are gone. Apostrophes are straight everywhere and quoted names use curly quotes. "Coming soon" and the dev/"this version" texts are reworded. The About tagline and hero, the sign-in subtitle, the lock-after text, the fx texts, the history texts, the payment bubble texts, import plurals ("1 Expense") and a single-date import range are fixed. Four unused stale strings are removed. |
| Visuals | List signs are tight ("+₹500"). Paid amounts are neutral, not green. Field labels are grey caps, the same as section labels. In dark mode the selected segment can be seen. Photo covers and heroes have stronger shades. The gauge knob is round. The lock screen mark sits on its tile, because the bare mark was invisible in light mode. The keypad has a hairline. The "Ends" spacing is fixed. The import "Done" step no longer looks complete. The category row reads "Category · Food · Dining out". |
| Behaviour (copy-driven) | The Groups bell opens notifications with its unread badge, where it used to show "Coming soon". Developer codes are hidden on sync issue cards. The sign-in golden now shows Google as configured. |
| Docs | README feature list rewritten to match the app (Google sign-in, friends, loans, repeating expenses, themes). The duplicate CHANGELOG bullet is merged. |

## Left for the owner or the device QA

These are findings from the golden review. None of them has been checked on a device.

- Settle up offers the UPI method for a USD balance (rule 13). With Cash selected, the main button still says "Pay ₹500 via UPI".
- The Groups glass card shows "Settle up" when everything is settled. Sync & storage says "Everything is synced"
  while an upload has stopped after 8 tries.
- Notification settings: the push toggles stay live while push is blocked or unavailable, and in "Muted groups" the
  switch's on state means muted.
- The push text for a repeating copy says "(recurring)" but the app says "(repeats)". Changing it needs a migration.
- Design calls that need the owner:
  - Expense and payment detail heroes use serif amounts; the spec says Inter.
  - Category icons are solid circles; the spec says tinted.
  - There is no danger button style for "Delete my account".
  - Avatar stacks cover initials.
  - The Google button uses a generic icon instead of the official "G".
  - Test fixtures use the owner's real name, in 31 places.
