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
- Full suite on the merged tree (with W2-Y), `--concurrency=1`: core/data/domain/ui/app/a11y/tool 1,182 passed;
  features a–f 1,152 passed; features g–z 907 passed; goldens: 964 passed + 35 updated for the intended changes
  (Show in INR chip on the multi-currency Home card, "From contacts" in the pickers, the contacts icon in the group
  form, the Paid by row in the Default split sheet) — 0 failures. Format, analyze (0 errors/warnings), guards: OK.
  Coverage merge: SKIPPED (chunked runs, no time to merge lcov).
- Device: see "Device run" below.

## Device run

`tool/e2e/capture_w2x.ps1` → `integration_test/w2x_test.dart` on emulator-5554 (`com.unizoy.splitify.qa`,
`--no-uninstall`, DEV, DNS pin): **PASS** before the W2-Y merge (2 min 19 s) and again on the merged tree (2 min 14 s). e2e-a + a fresh second account (claims "Bina"
in a test trip): + → Bina (her direct group made online once) → "+" → Rahul (name only) → one hidden ad-hoc group made
offline, synced (type `other`, `is_adhoc` on the server), Bina's account linked by the server (the phone never sends
user_id), she sees the group (RLS) and got the `expense_added` notification; the Groups grid hides it; Rahul's page
shows the trip and "You, Bina & Rahul". "From contacts" opened the system contact picker (Google Contacts); Back added
nothing. "Save as group default" with Bina paying → server `default_split.payer` = Bina, the next expense says "Paid
by Bina". A dollar expense with a saved INR conversion → "Show in INR" on Home shows the converted total, labelled.
`pm list packages` before = after: com.unizoy.splitify (owner), com.unizoy.splitify.qa, com.Splitwise.SplitwiseMobile.
Screenshots: `splitify-artifacts\screenshots\w2x-{add-person,editor-people,friend-adhoc,save-default,home-inr}{,-dark}.png`
and `w2x-contact-picker.png`. Earlier attempts found test-only issues (friends remote not wired in the test, a fresh
account's profile name, a system Back on the only page closing the app) — fixed in the test.

## Notes for the coordinator

- Merged `origin/feat/simple-add-expense` (with W2-Y) into this branch: conflicts only in the ARB (both append blocks
  kept, l10n regenerated) and planning docs (both kept); W2-Y's editor controller, expense detail, pull applier
  (`expense_attachments`) and `MainActivity` (`PdfBridge`) changes merged cleanly next to mine (`ContactsBridge`).
- 0028 redefines none of 0029/0030's functions (apply_mutations, pull_changes, fan-out, settings): it only adds a
  column, an index, four new functions and three new triggers. After the merge, on DEV: 300 34/34, 001 32/32, 190
  288/288 (W2-Y fixed #86), 280 47/47, 290 32/32, 040 35/35, 041 29/29.
