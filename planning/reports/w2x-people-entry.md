# W2-X — people, entry and money display (Wave 2, D-034)

- Date: 2026-11-28 · Branch `feat/w2-people-entry` (from `feat/simple-add-expense` @ e3ad96b) · Decisions S-420..S-429
- Migration `0028_adhoc_groups` on DEV (additive only: one column, one index, four functions, three triggers; no
  DROP / DELETE / TRUNCATE). It redefines no function of W2-Y's 0029/0030.

## Built

| Item | What |
| --- | --- |
| F11 several friends without a group | "With you and": one friend is one tap; then each person is a chip (tap = change, x = remove) and "+" adds a friend, a new name or a contact. Two or more people → a hidden ad-hoc group, made offline in one transaction (group, then members through the outbox), reused for the same set of people. The server stores type `other` + `is_adhoc`; the pull maps it back to the local type `adhoc` (no Drift change). Picked people keep their identity through `origin member id XOR group id` (S-421), so friend rows, totals, the Home caption and Account stats count each person once. Accounts are linked by the server (adder must share the origin's live group); claims follow later. Hidden from the Groups grid, With picker, Insights, notification mutes, Deleted groups and the group count; shown on each friend's page as "You, Asha & Rahul" |
| F15 from contacts | System contact picker (ACTION_PICK) through `ContactsBridge.kt` (channel `splitify/contacts`, no plugin, no permission), name only; a friend with exactly that name is that friend. In the With-you-and picker (both modes), Add friend, group form |
| P-10 default payer | `default_split.payer`; new expenses start with it; "Save as group default" tick in the paid/split sheet (saved with the expense); Paid by row in the group's Default split sheet |
| P-9 show in INR | Home overall card + friend page header: one switch (kept on the phone), saved conversions only, labelled "In INR · saved rates", the rest listed as "Also $20 not converted" |

## Tests

- pgTAP `300_adhoc_groups.test.sql` 34/34 (dry run + after apply); regression after 0028: 040 35/35, 110 17/17,
  050 44/44, 130 80/80, 020 17/17, 250 27/27, 260 60/60, 190 287/288 — #86 lists `attachment_upload_ok`, a function of
  W2-Y's 0029 (its allowlist or grant needs W2-Y's fix).
- Unit + glados: `w2x_adhoc_friends_test` (300 runs × 2 properties), `w2x_in_currency_test` (400 runs × 2),
  `w2x_adhoc_sync_test`; widget: `w2x_people_test`, `w2x_show_in_test`; goldens `w2x_golden_test` (30: 6 states ×
  light/dark × text 1.0/2.0 + 320×568, expectA11y).
- Device: see "Device run" below.

## Device run

(filled in after the run)

## Notes for the coordinator

- Merge: W2-Y also edits `expense_editor_controller.dart`, `expense_detail_screen.dart`,
  `notification_settings_screen.dart`, `pull_applier.dart`, `MainActivity.kt`, `app_en.arb` (+ generated l10n): the
  hunks are separate; regenerate l10n after merging the ARB blocks (both append at the end).
- 190_attack #86 fails on DEV because of W2-Y's `attachment_upload_ok` grant (not 0028).
