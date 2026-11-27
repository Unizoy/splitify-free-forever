# 11 Splitwise gap analysis and build plan (D-034)

Date: 2026-11-27.

**Inputs**
- `10-splitwise-flows.md`: the hands-on Splitwise walkthrough and its Pro list.
- Splitify code on `origin/feat/minimal-groups` at 84a10a7. This is the newest app: one-screen add expense,
  settle up, loans, group form and settings, and the "With you and" picker.
- `docs/PLAN.md`, `CLAUDE.md`, `planning/07`, `planning/08`.

**Owner direction (D-034, 2026-11-27):**
- Take Splitwise's flows and minimalism as the reference, and keep Splitify's design system.
- Give everything that is in Splitwise Pro for free.

**What this overrides:** PLAN.md "Out of scope" listed receipt scanning, itemized split and the whiteboard.
D-034 brings them back in. *Action for the coordinator:* add a D-034 row to `planning/00-decisions.md` that
records this. This research did not edit the decisions file.

**Labels used below:**
- **P1 / P2 / P3:** build order.
- **[DB]:** needs a numbered migration in `supabase/migrations/`. Every [DB] item also needs pgTAP tests and RLS.
- **[no DB]:** works on the current schema.

---

## (a) Features Splitwise has that Splitify lacks

### Free in Splitwise

| # | Feature | What Splitwise does | Splitify today | Prio | DB |
| --- | --- | --- | --- | --- | --- |
| F1 | Two-person split answers | When the expense is with one friend, four one-tap answers: I paid / they paid, split equally / owed the full amount | The pill opens the full payer and split sheet; "owed the full amount" needs an exact split, or the separate loan screen | P1 | no DB |
| F2 | Settle everything with one friend | One payment clears every group balance with that person | One payment per group; the friend page picks a group each time | P1 | no DB (one payment per group, written together) |
| F3 | Who owes whom on the group page | Collapsible per-person lines under the group name | Status pill only; the lines are in the Balances tab | P1 | no DB |
| F4 | Settled history collapsed | Once settled, old rows hide behind one "show settled expenses" row (group and friend pages) | Everything is always listed | P1 | no DB |
| F5 | Restore from the deleted item | Activity → deleted expense → Restore in its top bar | Opening a deleted expense from Activity shows "not found / may have been deleted on another phone"; restore only through group settings → Deleted items | P1 | no DB |
| F6 | Groups-list filter | All / Outstanding / Groups I owe / Groups that owe me | No filter | P2 | no DB |
| F7 | Personal friend code | Account → Scan code / My code: a personal QR + link; scanning one adds a friend | Group invite codes only; friends are name-only until they join a group | P2 | **[DB]** |
| F8 | Trip dates | Trip groups get start/end dates; Splitwise nudges people to settle after the trip | None | P2 | **[DB]** |
| F9 | Whiteboard | One free-text page per group (address, Wi-Fi, contacts) | None (PLAN had it out of scope) | P2 | **[DB]** |
| F10 | Reminder through the share sheet | "Remind…" offers ready-made text through Android share, for people without the app | Remind is push-only and hidden for name-only members | P2 | no DB |
| F11 | Several friends, no group | "With you and" takes several friends; the expense goes into each friendship | One target only (one group or one friend) | P3 | **[DB]** (needs a hidden ad-hoc group type) |
| F12 | Category trend on the expense page | Three-month bars for this group's category | None | P3 | no DB |
| F13 | Totals by month | All time, or one month with ‹ › | "This month / All time" toggle | P3 | no DB |
| F14 | Monthly summary | A monthly email recap | None (PLAN: no email); could be an in-app card plus optional push | P3 | [DB] (cron) |
| F15 | Pick people from contacts | Contacts list in add-people | Names typed by hand | P3 | no DB (system picker, no permission) |

### Pro in Splitwise (must be free here)

| # | Pro feature | Splitify today | What we build | Prio | DB |
| --- | --- | --- | --- | --- | --- |
| P-1 | Receipt scanning | Attach a photo only | On-device text recognition fills amount, date and description; detected lines can go straight into Itemize | P1 | no DB |
| P-2 | Itemization | None | An "Items" split: lines with prices, each assigned to people; tax, service, tip and discount shared in proportion | P1 | no DB (saved as an exact split; the items go in `split_values`) |
| P-3 | Custom group reminders | None | Per-group settle-up reminder (off / weekly / monthly), plus a nudge when a trip ends | P2 | **[DB]** (columns + cron) |
| P-4 | JSON backup | CSV per group only | Account → "Download my data": JSON of everything plus one CSV per group | P2 | no DB |
| P-5 | Expense search (full) | Search covers expenses only; a group search route exists but nothing links to it | Also search payments and comments; open search from the group page | P2 | no DB |
| P-6 | Charts and graphs (full) | Category donut and 12-month bars | Category trend over months, plus who paid what over time | P3 | no DB |
| P-7 | High-resolution receipts, more files | 1 photo, ≤ 500 KB | Several attachments per expense (photos, PDF); full resolution on tap | P3 (wave 2) | **[DB]** (+ storage cost on the Supabase free plan) |
| P-8 | Transaction import (US cards) | Not applicable in India | India version: "Share to Splitify" from a UPI app or a receipt screenshot opens a prefilled expense | P3 (stretch) | no DB |
| P-9 | Currency conversion to one currency | Saved rate per record, the "In INR" view and "Convert all" in a group | Add "Show in INR" to the friend page and the Home overall card, using saved conversions only and labelled as such | P3 (wave 2) | no DB |
| P-10 | Default splits (personal, with payer) | Group-wide default (equal / % / shares), free | Optional default payer; a "Save as group default" tick in the split sheet | P3 | no DB (the `default_split` jsonb gets a `payer` key) |
| — | Unlimited expenses, no ads, Trip Pass, early access | Already true or not needed | Nothing | — | — |

---

## (b) Flows where we take more taps or screens (from 10 §4)

| Flow | Splitwise | Splitify | Fix |
| --- | --- | --- | --- |
| Two people, "they owe the full amount" | 2 taps | ~4 taps, or a separate screen | F1 presets (WP-A) |
| Settle with a friend across 2 groups | 3 taps, 1 payment | 6 taps, 2 payments | F2 (WP-B) |
| See who owes whom in a group | 0 | 1 (Balances tab) | F3 (WP-C) |
| Restore a deleted expense | 2 | 3–4, and the Activity link is a dead end | F5 (WP-A expense page, WP-B payment page) |
| Remind a person without the app | 2 | not possible | F10 (WP-B) |
| Add expense from Home through the "With you and" sheet | 4 | 5–6 (focus is lost after picking) | After a pick, put the cursor back in the description (WP-A) |
| Export CSV | 1 | 2 | Leave it: export is rare, and the totals and settings entry points are fine |
| Several friends, no group | 1 field | not possible | F11 (wave 2) |

---

## (c) Where Splitify is already better (keep, do not regress)

**No limits**
- No daily cap, no countdown screens, no paywalls.
- Search, charts, conversion and default split are free today.

**People and groups**
- **Name-only members:** add people by name, no email or phone. Splitwise needs about 4 taps plus an email per
  person.
- **One-screen group creation** with people inline. No trip-date dialog.
- **Group invite:** a QR, a code and a link in one sheet. Splitwise has a link only.
- **Per-group main currency.** Splitwise uses each person's default currency, and gave an India user USD.

**Payments**
- UPI "Pay via UPI", with fallbacks (copy, QR).
- A payment method field (cash / UPI / bank / other).
- Partial payment in 2 taps, with a live "₹x left" line.

**Safety net**
- Delete with Undo (1 tap) instead of a confirm dialog.
- Full edit history with field diffs and lost-conflict versions. Splitwise shows only "updated by / deleted by".
- Offline-first, with a "not synced yet" marker.
- Loans as their own kind, kept out of totals and charts.

**Everyday screens**
- Activity filters plus a notifications bell with per-kind settings. Splitwise's activity is one flat list.
- A live "3 people · ₹400 each" line on the add form. Splitwise shows it only inside the split screen.
- Repeat in one tap from the toolbar, with an end date. Splitwise has no end date.
- Home-screen widget, app lock, Splitwise CSV import, and the settle celebration.

**Design system**
- Keep Splitify's design system (`planning/06`). Borrow only flow and tap economy.

---

## Build plan: 4 parallel work packages

**General rules for every package**
- Work only in your own files. You may *read and import* any file, and *edit* only the files your package owns.
- Each package runs on its own branch: `feat/d034-a-entry`, `feat/d034-b-settle`, `feat/d034-c-groups`,
  `feat/d034-d-data`.
- Each package merges to `main` through a PR, in the order D → A → B → C.
- Money rules (CLAUDE.md 1–4, 12, 13): read the `money-rules` skill before any amount code.
- Offline rules (rule 6): read the `offline-sync-rules` skill before any data code. Every write goes through the
  outbox, and every pending row shows the "not synced yet" marker.

### Shared files (the only places packages could collide)

| File(s) | Owner | Rule for the others |
| --- | --- | --- |
| `lib/l10n/app_en.arb` | everyone, append-only | Each package adds keys in **one block at the end** with its prefix: A `entry…`, B `settle2…` / `friendCode…` / `remindShare…`, C `trip…` / `board…` / `groupFilter…` / `nudge…`, D `backup…` / `search2…` / `trend…`. On a merge conflict keep both blocks, then re-run `flutter gen-l10n`. Never hand-merge the generated `app_localizations*.dart`. |
| `pubspec.yaml`, `pubspec.lock`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/**` | **WP-A** | No other package adds packages or changes the manifest. If one is needed, defer it to wave 2. |
| `lib/data/local/tables/schema.drift`, `lib/data/local/app_database.dart` (+ `.g.dart`, schema dumps), `lib/data/sync/row_codec.dart`, `lib/data/sync/pull_applier.dart` | **WP-C** | Only WP-C bumps `schemaVersion` (9 → 10). |
| `supabase/migrations/` | **WP-B** writes `0025_friend_codes.sql`; **WP-C** writes `0026_group_extras.sql` | A and D add no migrations. Only WP-C redefines `apply_mutations` column lists, the activity `type` check and the notification fan-out. |
| `lib/app/router.dart` | **WP-C** | Exception: WP-B adds **one** clause in the deep-link redirect, mapping `splitify://friend?code=X` to `/friends/code/X`, written exactly like the existing `join` clause. Nothing else in the file. |
| `lib/ui/components/**`, `lib/ui/theme/**` | frozen | New widgets go inside the package's feature folder. If a shared component truly must change, note it in the report and leave it for wave 2. |
| Existing golden images | the package that owns the screen | If a golden of a screen you don't own changes, stop and fix your change. Don't re-bless it. |

**Test conventions for every package**
- **Goldens:** each package adds **one new golden file**, `test/goldens/d034_<pkg>_golden_test.dart`, using
  `goldenScales` (text 1.0 and 2.0) × light and dark, plus a **small phone 320 × 568** at text 1.0 (the pattern
  in `minimal_groups_golden_test.dart`), and `expectA11y`.
- **Device e2e:** `integration_test/d034_<pkg>_test.dart` on emulator-5554.
  - Take the emulator lock first (`splitify-artifacts\emulator.lock`).
  - Read `splitify-artifacts\EMULATOR-WARNING.txt`: run the `.qa` build with `--use-application-binary` so the
    tool never uninstalls `com.unizoy.splitify`.

---

### WP-A: Smart entry (add-expense editor, itemize, receipt scan, expense page)

**Owns**
- `lib/features/expenses/presentation/**`, *except* `expense_list.dart` (that one is WP-C's).
- `lib/features/expenses/application/**`.
- New:
  - `lib/features/receipt_scan/**`
  - `lib/core/money/itemize.dart`
  - `lib/domain/rules/receipt_text_parser.dart`
- `lib/data/repositories/expense_reads.dart`.
- `pubspec.*`, the Android manifest and Kotlin files (see shared files).
- Tests:
  - `test/features/expenses/**`
  - `test/core/money/itemize_test.dart`
  - `test/domain/receipt_text_parser_test.dart`
  - `test/features/receipt_scan/**`
  - `test/goldens/d034_a_golden_test.dart`
  - `integration_test/d034_a_test.dart`
  - fixtures under `test/fixtures/receipts/**`

**Tasks**

**A1 (P1) Two-person answers (F1).**
- *When:* the "With you and" target has exactly two people (a friend, or a group with two active members).
  Tapping the "Paid by … split …" pill then opens a short sheet:
  1. "You paid · split equally" (Asha owes you ₹150)
  2. "You're owed the full amount" (Asha owes you ₹300)
  3. "Asha paid · split equally" (You owe Asha ₹150)
  4. "Asha is owed the full amount" (You owe Asha ₹300)
  5. "More options" → today's full sheet
- Each answer's line updates live with the amount.
- *Picking an answer* sets the payer and the split and closes the sheet (1 tap).
- *"Owed the full amount"* is a normal expense with an **exact** split (payer 0, the other person the full
  amount). It is *not* a loan, so it counts in totals.

**A2 (P1) Itemize (P-2).**
- *Where:* a sixth split type, "Items", in `split_editor.dart`.
- *Item rows:* optional name, amount, and people chips (default: everyone in the split).
- *Extras:* tax (e.g. CGST + SGST), service charge, tip, discount. All typed as **amounts**, never %, so there
  is no rounding question about the inputs.
- *Pure function* in `lib/core/money/itemize.dart`:
  - each person's item subtotal
  - extras spread by `allocateRatio` (05 §3), with leftover paise given out in fixed member order (rule 2)
  - result: integer shares that add up to the expense total
- *Footer:* "₹x of ₹y · ₹z left" like the exact split. If no amount was typed, offer "Use items total".
- *Storage:* `split_kind = 'exact'`, `shares` = the computed values, and
  `split_values.itemized = {v: 1, items: [{name, amount, members:[memberId…]}], extras: {tax, service, tip, discount}}`.
  `split_values` is already a free jsonb object (0004 l.127; 0009/0019 pass it through), so **no migration**.
  Editing reopens Items. Recurring templates copy `split_values` unchanged.

**A3 (P1) Receipt scan (P-1).**
- *Entry:* the Receipt chip sheet gets "Scan receipt" (camera or gallery).
- *Recognition:* on-device, with `google_mlkit_text_recognition`, Latin model, **bundled** so it works offline.
  Record an S-decision with the APK size cost.
- *Parser:* `receipt_text_parser.dart`, pure Dart, finds:
  - the total ("Grand Total", "Net Amount", "Amount Payable", "Total", "To Pay"; falls back to the largest amount
    near the bottom)
  - the date (dd/mm/yyyy, dd-mm-yy, dd MMM yyyy)
  - the merchant (first text line)
  - tax lines (CGST/SGST/IGST/GST/VAT/Service charge)
  - discount
  - item lines (name + amount, "qty x rate")
  - Indian number formats: `1,23,456.00`, `₹`, `Rs.`, `INR`
- *Review sheet:* shows what was found, each field with a tick. "Use these" fills amount, date and description.
  "Itemize" opens A2 prefilled with the detected lines.
- *Never saves on its own.* The scanned photo stays attached as the receipt, using the existing upload queue.

**A4 (P1) Restore from the expense page (F5).**
- `expense_reads.dart` and `expenseViewProvider` also load **deleted** expenses for the detail page.
- *Hero:* a "Deleted" pill plus **Restore** (existing `actions.restore`) instead of Edit/Delete. The body is
  read-only.
- Opening a deleted expense from Activity no longer shows "not found".

**A5 (P2) Focus fix.**
- After a pick in the "With you and" sheet, the cursor returns to the description (or to the amount if the
  description is filled). Saves 1 tap.

**A6 (P3) Category trend card.**
- *On the expense page:* the last 3 months of this category in this group, using insights providers read-only.
  Tap → Insights.

**A7 (P3, stretch) Share to Splitify (P-8).**
- *Android share target* for `image/*` and `text/plain`, added to the manifest.
- *Shared image* → A3 scan. *Shared text* (UPI apps share "Paid ₹250 to …") → parse amount and payee.
- *Then:* the editor opens prefilled; the user picks "With you and".

**Acceptance**
- **Presets:** two-person presets appear only when exactly 2 people are involved. Each one saves the right
  payer and shares. Offline save works and shows the "not synced yet" marker.
- **Itemize sums:** an itemized expense of ₹1,000 with lines 400 (A), 350 (A, B), 150 (B), tax ₹100 saves shares
  that add up to 100000 paise exactly. Reopening shows the same lines.
- **Itemize on the server:** the server accepts the itemized expense (no `SPLIT_SUM_MISMATCH`).
- **Scan totals:** scanning each receipt fixture (≥ 8 Indian receipts: restaurant with GST, grocery, fuel,
  pharmacy, cab, a hand-written-ish bill, an English hotel bill, a UPI screenshot) finds the right total in
  ≥ 7 of 8.
- **Scan safety:** the scan never moves money and never saves without the user.
- **Restore:** a deleted expense opened from Activity shows Restore; restoring writes `expense_restored` and the
  row comes back.
- **Fixed rounding:** ₹100 itemized to three people gives 33.34 + 33.33 + 33.33.

**Tests**
- **Unit:**
  - `itemize_test.dart`: vectors and glados properties. The parts always add up to the total; no negative
    share unless a discount is bigger than a person's items (that is an error); fixed rounding order.
  - `receipt_text_parser_test.dart`: fixture texts, Indian number formats, no total found.
  - Presets: the draft mapping for each preset.
- **Widget:**
  - the preset sheet (2 people vs 3, live lines)
  - the Items editor (add/remove a line, assign people, live remaining, errors)
  - the scan review sheet (found / nothing found / offline)
  - the deleted-expense page
- **Golden (`d034_a`):** preset sheet, Items editor (empty and full), scan review sheet, deleted expense page.
  Each in light/dark × text 1.0/2.0, plus a 320 × 568 small phone.
- **Device e2e:**
  - an itemized expense added offline, then synced; the shares are checked on the server through the harness
  - a fixture receipt image pushed with `adb push` to the gallery, then scanned; the amount is prefilled
  - delete, then Activity → Restore

---

### WP-B: Settle and friends (settle all, share reminders, friend code)

**Owns**
- `lib/features/payments/**` and `lib/features/friends/**`.
- `lib/features/notifications/presentation/remind_button.dart` and
  `lib/features/notifications/application/reminders.dart`.
- New `lib/features/friend_code/**`.
- `lib/data/remote/friends_remote.dart` and `lib/data/repositories/friends_repository.dart`.
- `supabase/migrations/0025_friend_codes.sql` and `supabase/tests/250_friend_codes.test.sql`.
- The one deep-link clause in `router.dart` (see shared files).
- Tests: `test/features/payments/**`, `test/features/friends/**`, `test/features/friend_code/**`,
  `test/goldens/d034_b_golden_test.dart`, `integration_test/d034_b_test.dart`.

**Tasks**

**B1 (P1) Settle everything with a friend (F2).**
- *Sheet:* the friend page's Settle up sheet starts with one row per currency where the person has more than one
  balance, e.g. "Everything with Asha · ₹455 · 2 groups". Single balances still open the form at once (today's
  behaviour).
- *Form:* the settle-up screen opens in "all groups" mode.
  - the same one screen, with the amount filled in with the total
  - a small "Across 2 groups" line that opens a read-only breakdown
- *Saving:* writes **one payment per group** (and the direct group) in **one local transaction / outbox batch**,
  using the existing payment rows, so **no migration**.
- *Partial amounts:* allocated in a fixed, documented order: biggest group balance first, ties broken by group
  id. Each group's payment is ≤ what is owed there. Paying more than the total is blocked with an inline error.
- *UPI (INR):* one "Pay ₹455 via UPI" for the total. "Mark as paid" records all the payments. Method `upi` on
  each.
- *Currencies:* never mixed. Each currency is its own row and its own batch.

**B2 (P1) Restore on the payment page (F5).**
- Same as A4, for payments opened from Activity: a "Deleted" pill plus Restore.

**B3 (P2) Share a reminder (F10).**
- *Name-only or unlinked member who owes me:* the Remind button shows and opens "Share a reminder", the Android
  share sheet with text such as "Hi Asha, a reminder about ₹200 for 'Goa trip'". If it is INR and I have a UPI
  ID, the `upi://pay` link from rule 13 is added.
- *Linked member:* keeps push Remind, with a secondary "Share instead".
- *Sending:* the app sends nothing itself. It writes the `reminder_sent` activity only for push reminders, which
  matches PLAN's "no app-sent SMS/WhatsApp" rule.

**B4 (P2) Personal friend code (F7) [DB 0025].**
- *Table:* `public.friend_codes(user_id pk → auth.users, code text unique, rotated_at)`, 8-character Crockford
  code like invite codes. RLS: a user can select only their own row.
- *RPCs:* `my_friend_code()`, `rotate_friend_code()`, and `add_friend_by_code(code)`.
  - `add_friend_by_code` is security definer and rate-limited like joins (10 tries an hour).
  - It finds or creates the direct group for the two users (`find_or_create_direct_group`), with **both linked**.
    It writes `member_joined` activity.
- *UI:* the Add friend sheet on the Friends tab gets two rows.
  - "Show my code": QR of `splitify://friend?code=…`, the code, Copy, Share, Reset. It needs internet the first
    time, then the code is cached.
  - "Scan a friend's code": the existing `mobile_scanner`. A pasted link works too.
- *Result:* the friend's page opens.
- *Offline:* clear "needs internet" copy.

**B5 (P2) Friend page tidy (F4).**
- When we are settled in every currency, rows older than the last full settle-up collapse behind "Show settled
  items (N)".
- When a balance is open, list everything as today.

**Acceptance**
- **Settle all:** with Asha owing me ₹200 in Goa and ₹255 direct, one tap on "Everything · ₹455", then Record,
  gives 2 payments, both nets reach 0, and Activity shows both.
- **Partial settle:** ₹300 pays Goa ₹200 + direct ₹100. The order is documented and unit-tested.
- **UPI:** the UPI link carries the total once. Mark as paid records N payments, and the outbox sends them in
  order offline → online.
- **Share reminder:** text and the UPI link are correct; nothing is written to the activity log.
- **Friend code:** user B scans A's code, and both see each other under Friends with a linked direct group.
  A wrong code gets friendly copy. The rate limit works. A reset code stops the old one.
- **RLS:** nobody can read someone else's friend code.

**Tests**
- **Unit:**
  - the allocation of a batch payment (vectors plus a property: the sum equals the input; each part ≤ what is
    owed; currencies kept apart)
  - the reminder text builder (encoding, the 50-character note cap)
  - the friend-code parser
- **Widget:** the settle sheet with the "Everything" row; the batch form with its breakdown; the share-reminder
  sheet; My code / Scan code; the collapsed history.
- **SQL (`250_friend_codes.test.sql`):** RLS, rotate, add by code (new pair, existing pair, self, unknown code,
  rate limit), activity written.
- **Golden (`d034_b`):** settle sheet, batch form, My code, share reminder sheet, friend page collapsed. Each in
  light/dark × text 1.0/2.0, plus a small phone.
- **Device e2e:**
  - batch settle offline, then online; check the server nets through the harness
  - the fake UPI handler receives the total once
  - the friend code through a deep link `adb shell am start -d "splitify://friend?code=…"` for a second test
    user

---

### WP-C: Groups (group page, trip dates, reminders, whiteboard, filters)

**Owns**
- `lib/features/groups/**`.
- `lib/features/expenses/presentation/expense_list.dart`.
- `lib/features/balances/presentation/balances_tab.dart` and `balance_copy.dart`.
- `lib/features/activity/**`.
- `lib/app/router.dart` (minus WP-B's line).
- `lib/data/remote/groups_remote.dart`.
- The Drift, sync and codec files in the shared-files table.
- `supabase/migrations/0026_group_extras.sql` and `supabase/tests/260_group_extras.test.sql`.
- Tests: `test/features/groups/**`, `test/features/activity/**`, `test/data/**` (schema/codec),
  `test/goldens/d034_c_golden_test.dart`, `integration_test/d034_c_test.dart`.

**Tasks**

**C1 (P1) Who owes whom on the group page (F3).**
- *Where:* under the status pill.
- *Content:* up to 3 lines from my point of view, per currency, main currency first ("Asha owes you ₹200",
  "You owe Rahul ₹100"), then "+2 more" → Balances tab.
- *Display:* collapsible; the state is remembered per group on this phone. It follows simplify when that is on.
- *Pending changes:* the lines show the "not synced yet" marker.

**C2 (P1) Settled history collapsed (F4).**
- *Where:* in `expense_list.dart`. If the group is fully settled in every currency for every member, rows dated
  before the last moment it became settled collapse into one "Show settled expenses (N)" row.
- *Computed on the phone* from the ledger.
- *Search and export* still see everything.

**C3 (P2) Groups-list filter (F6).**
- *Where:* a small filter pill next to "Active groups · N".
- *Options:* All / Outstanding / I owe / Owe me, kept on this phone. An empty filter result shows "No groups
  match" with a "Show all" link.

**C4 (P2) Trip dates and settle-up reminders (F8, P-3) [DB 0026].**
- *Columns on `groups`:*
  - `trip_starts_on date`
  - `trip_ends_on date` (check: end ≥ start)
  - `settle_reminder text` (check in `off`/`weekly`/`monthly`, default `off`)
- *Group form:*
  - **Trip type:** an optional "Trip dates" row, start and end, *no dialog*. A missing end date simply means "no
    end".
  - **Any type:** a "Settle-up reminders: Off / Weekly / Monthly" row.
- *Group page:* a dates chip ("12–18 Dec").
- *Server:*
  - `private.send_settle_nudges()` runs daily through `cron.schedule` (10:00 IST). Pick the exact UTC time in
    the migration, like 0017/0019.
  - It inserts one `settle_nudge` activity per due group: weekly on the group's creation weekday, monthly on the
    1st, and the day after `trip_ends_on`.
  - Only when someone has a non-zero balance. Idempotent per group per day, using a `settle_nudges_sent(group_id,
    day)` table with RLS on and no client policies.
  - The fan-out (0016) maps `settle_nudge` to the `reminders` kind and sends it to members with a balance
    (rule 10; muted groups get in-app only).
- *Activity:* the activity `type` check gains `settle_nudge` and `whiteboard_updated`.

**C5 (P2) Whiteboard (F9) [DB 0026].**
- *Columns:* `groups.whiteboard text` (≤ 5,000 characters, checked).
- *Screen:* `/groups/:id/notes`, a full-screen text field with "Last edited by Asha · 21 Nov" and Save.
- *Entry:* a "Group notes" row in settings, plus a small notes chip on the group page when it isn't empty.
- *Saving:* offline through the outbox (a `groups` update; `apply_mutations` column list updated).
  `record_versions` already keeps group versions, so both versions survive a conflict (rule 6).
- *Activity:* `whiteboard_updated` (no push by default; in-app only).

**C6 (P2) Search from the group page (P-5).**
- A search icon in the group hero opens `/search?group=<id>`. WP-D makes that route preselect the group.

**C7 (P1) Schema plumbing for C4/C5.**
- Drift `schemaVersion` 9 → 10 with a step migration, a schema dump, `row_codec`/`pull_applier` for the new
  columns, and the `groups_remote` fields.

**Acceptance**
- **Group lines:** the group page shows the right lines with and without simplify, for several currencies.
  They match the Balances tab exactly.
- **Settled history:** a settled group shows one collapsed row, and tapping it reveals the older rows.
- **Filter:** the four filters return the right groups; the choice survives an app restart.
- **Nudges:** a group with `settle_reminder = weekly` and an open balance gets exactly one `settle_nudge` on its
  weekday, and a second cron run the same day adds nothing. Members with zero balance and the muted get no push.
- **Whiteboard:** text edited offline syncs. A conflicting edit keeps both versions in history.
- **RLS:** non-members can't read `whiteboard` or the trip dates.
- **Migration safety:** the migration applies cleanly on top of 0025, and all old pgTAP files still pass.

**Tests**
- **Unit:** the "last settled moment" finder; filter predicates; the nudge schedule (the weekday and month-end
  rules mirrored in Dart for display, "next reminder on …").
- **Widget:** group lines (0, 1, 3, more; several currencies; pending); the collapsed list; the filter pill; the
  trip-dates and reminder rows on the form; the whiteboard screen (empty, edited, offline).
- **SQL (`260_group_extras.test.sql`):**
  - column checks
  - `apply_mutations` accepts the new fields and rejects too-long text
  - `send_settle_nudges` is idempotent and covers weekly/monthly/trip-end
  - fan-out recipients
  - the activity type check
  - RLS
- **Golden (`d034_c`):** the group page with lines (light/dark × text 1.0/2.0, small phone), the collapsed
  history, the filter sheet, the form with trip dates, the whiteboard.
- **Device e2e:**
  - a whiteboard edit offline, then synced, seen by user B
  - a nudge forced by calling the SQL function on dev through the harness; the notification appears in
    `dumpsys notification`
  - the filter persisting across a restart

---

### WP-D: Data, search and insights

**Owns**
- `lib/features/export/**`, `lib/features/search/**`, `lib/features/insights/**`.
- `lib/features/balances/presentation/totals_tab.dart`.
- `lib/features/account/presentation/account_settings_sheet.dart`, plus a new data screen in the account folder.
- `lib/data/repositories/search_repository.dart`, `export_reads.dart`, `lib/data/local/daos/search_index_dao.dart`.
- Tests: `test/features/export/**`, `test/features/search/**`, `test/features/insights/**`,
  `test/goldens/d034_d_golden_test.dart`, `integration_test/d034_d_test.dart`.
- No migrations.

**Tasks**

**D1 (P2) Download my data (P-4).**
- *Entry:* Account settings → "Your data" → **Download my data**.
- *Output:* a `.zip` holding:
  - `splitify-backup.json`: format `{format: "splitify-backup", version: 1, exported_at, me, groups:[{group,
    members, expenses, payments, comments, recurring}]}`, with amounts as **integer minor units + currency
    code**, never decimals (rule 1)
  - one CSV per group, from the existing writer
- *Delivery:* the share sheet or a save dialog.
- *Source:* built from the phone's database, so it works offline. Unsynced rows are marked `"pending": true`.
- *Docs:* the format is written up in `docs/backup-format.md`. That is user documentation, part of the deliverable.

**D2 (P2) Search everything (P-5).**
- *Payments* ("Asha paid Mohit ₹500") and *comments* show as result types, found with plain local queries (no
  FTS schema change). Each result type has its own chip.
- *`/search?group=`* preselects the group chip and shows "in Goa trip".
- *Recent searches:* the last 5, kept on this phone.

**D3 (P3) Charts and trends (P-6).**
- *Insights adds:*
  - "Category over time": monthly bars for one picked category, last 12 months
  - "Who paid": per-member paid against share over months, for a group
- *Rules:* main currency only, using saved conversions; unconverted records are left out, with the existing note.

**D4 (P3) Totals by month (F13).**
- *In the Totals tab:* "All time" or a month with ‹ ›. Today's numbers then follow the chosen period.

**Acceptance**
- **Backup:** the JSON reloads in a test into exactly the same per-currency nets as the ledger (round trip).
  Amounts are integers. The file opens on the phone and shares.
- **Search:** finds a payment by amount and by person, and a comment by text, offline.
- **Group search:** the group search route opens with the group already chosen.
- **Trends:** trend numbers match the totals for the same period.

**Tests**
- **Unit:** backup builder (shape, integers, pending flag, a 500-row performance budget); round trip into
  balances; the search query for payments and comments; trend aggregation; the month navigator's maths.
- **Widget:** the "Your data" rows and progress; search result types and the group chip; the trend card; the
  Totals month picker.
- **Golden (`d034_d`):** search with mixed results, the trend charts, the Totals month view, the data screen.
  Each in light/dark × text 1.0/2.0, plus a small phone.
- **Device e2e:** download my data through the share sheet (stub the share intent, check the file exists and
  parses); search offline in airplane mode.

---

## Order, size and dependencies

| Package | P1 | P2 | P3 | Migration | Size |
| --- | --- | --- | --- | --- | --- |
| WP-A Smart entry | A1, A2, A3, A4 | A5 | A6, A7 | none | L (biggest: the OCR parser and Items editor) |
| WP-B Settle and friends | B1, B2 | B3, B4, B5 | — | 0025 | M |
| WP-C Groups | C1, C2, C7 | C3, C4, C5, C6 | — | 0026 | M–L |
| WP-D Data, search, insights | — | D1, D2 | D3, D4 | none | S–M |

**Dependencies**
- The packages don't depend on each other's code.
- C6 (the button) and D2 (what the route does) meet at the existing `/search?group=` route, which already exists.
- Merge order D → A → B → C keeps the risky schema and migration work last.
- After all four merge, one integration session runs the full gates (G1–G6) and a complete device pass.

**Wave 2 (after these four packages):**
- F11, several friends without a group: new group type `adhoc`, hidden from the Groups grid. [DB]
- P-7, several attachments and PDF: `expense_attachments` table plus storage policies. [DB] Check how much of
  Supabase's free 1 GB storage it would use first.
- P-9, "Show in INR" on Home and the friend page.
- P-10, a default payer.
- F14, a monthly summary card and push. [DB] (cron)
- F15, a contacts picker (needs a package, so it goes through WP-A's files).
- Fewer notifications for a batch settle: one push per batch instead of one per group. [DB] (fan-out)

---

## Check against the app's rules

- **Money (rules 1–2):**
  - Itemize, batch settle and the backup use integer minor units only.
  - Extras and partial payments are split with the existing allocation helpers and fixed leftover order.
  - Every new money function has glados property tests (the parts add up to the total).
- **Currencies (rule 4):** batch settle, group lines, trends and the backup never mix currencies.
  "Show in INR" (wave 2) uses only saved conversions.
- **Offline (rule 6):** every new write goes through the outbox and shows the sync marker:
  - presets and itemized expenses
  - batch payments
  - restore
  - the whiteboard
  - trip dates and the reminder setting

  These need internet, with clear copy: friend-code lookup and rotate, and the receipt OCR model if it is ever
  unbundled (it stays bundled by default).
- **RLS (rule 7):**
  - `friend_codes`: the owner only.
  - `settle_nudges_sent`: RLS on, no client policies.
  - The new `groups` columns: covered by existing member policies.
  - Each case is tested in pgTAP.
- **Nothing lost (rule 9):**
  - Restore uses the existing soft delete.
  - Whiteboard edits create versions and activity.
  - Nudges are activity rows.
- **Notifications (rule 10):** nudges go activity → notifications → push, respect per-user settings and mutes,
  and skip the actor.
- **UPI (rule 13):** batch UPI uses the standard link with the total. A payment is recorded only on "Mark as paid".
- **No secrets (rule 15):** the OCR model is on the device; no new keys.
- **Design:** every new screen and sheet uses `planning/06` components and tokens. Nothing visual is borrowed
  from Splitwise.

## Open points for the coordinator (not blocking)

1. Add the D-034 row to `00-decisions.md`. It lifts PLAN's out-of-scope receipt scanning, itemized split and
   whiteboard.
2. OCR model bundled (+ APK size, offline) or unbundled (smaller, but needs Google Play services and a download
   the first time). The plan assumes bundled.
3. Batch-settle order when paying part of the total. The plan says biggest group balance first. The other
   choice is oldest debt first.
