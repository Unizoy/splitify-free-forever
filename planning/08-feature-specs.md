# 08 — Feature specs: behaviour, edge cases, acceptance, tests

One section per feature (PLAN.md numbers, B = basics, X = owner extras). Each test line is
`TC-<feature>-NN [type] description`; types: `unit`, `widget`, `golden`, `integ` (integration on emulator), `sql`
(pgTAP), `edge` (Edge Function), `e2e` (scripted emulator scenario), `manual-opt` (optional owner check, never
blocks). Status of every TC lives in `10-test-catalog.md`. Copy text in quotes is the exact UI copy (English ARB).
Evidence: `research/01-product-research.md` (Splitwise behaviour), `research/05`, `research/06`.

## Cross-cutting rules

- **Who can do what (D-008):** any active member can add/edit/delete/restore any expense, payment, comment of
  their own; comments can be deleted only by their author. Group settings, invite rotation, archive: any member.
  Delete group: creator only. Remove member / leave: only when that member's nets are 0 in every currency.
- **Activity types:** `group_created, group_updated, group_archived, group_unarchived, group_deleted,
  group_restored, member_added, member_joined, member_claimed, member_left, member_removed, expense_added,
  expense_edited, expense_deleted, expense_restored, payment_added, payment_edited, payment_deleted,
  payment_restored, comment_added, comment_deleted, reminder_sent, settings_changed (simplify/default split),
  recurring_created, recurring_updated, recurring_stopped, import_completed`. Text templates live in ARB
  (e.g. "Rahul added “Dinner” · ₹1,200").
- **Notification kinds (channels):** `expenses` (added/edited/deleted/restored, recurring copies), `payments`,
  `reminders`, `comments`, `groups` (joined/left/removed/claimed/settings). Recipients = linked members involved in
  the record (payer or share > 0, both sides of a payment, the reminded person, participants of a commented
  record) + for `groups` all members. Never the actor. Muted groups: in-app yes, push no.
- **Limits:** 100 active members per group; description 120; notes 1000; comment 1000; group name 60; display name
  50; amounts per `05-money-engine.md`; 1 receipt photo per expense (≤ 5 MB upload after compression ≤ 500 KB).
- **Dates:** expense `date` is a local calendar date (no time); stored as `date`; default today in device time zone.
- **Errors:** every server rejection code maps to friendly copy in ARB; unknown → "Something went wrong. Your
  change is saved on this phone and will retry."

---

## B1 Sign-in and account (D-007)

- Methods: **Continue with Google** (Credential Manager via `google_sign_in` 7.x → `signInWithIdToken`) and
  **Continue with email** (6-digit code: `signInWithOtp(email)` → code screen → `verifyOTP(type: email)`; resend
  after 60 s; code valid 10 min; 5 wrong tries → "Too many tries, request a new code"). Same email via Google and
  OTP = same account (Supabase auto-links verified emails).
- Debug builds only: "Developer sign-in" (email+password) for test users; compiled out by `kReleaseMode` +
  `--dart-define=DEV_LOGIN=false` default; release build test asserts it is absent.
- Sign out: confirm sheet → push outbox (10 s best effort) → unregister device → wipe local data → onboarding.
- Delete account: Account → Delete account → explain effects ("Your expenses stay in your groups under your name
  so balances stay right; your profile, photo, UPI ID and sign-in are removed") → type DELETE → Edge Function →
  signed out. Works only online.
- Edge: no network on first launch → onboarding shows "You're offline — connect once to sign in"; Google
  cancelled → stay; OTP email typo → "Change email"; account deleted on another device → next sync 401 → signed
  out with message.
- TC-B1-01 [widget] onboarding shows both buttons and dev login only in debug · TC-B1-02 [unit] auth controller
  maps OTP errors to copy · TC-B1-03 [integ] dev sign-in → home · TC-B1-04 [integ] sign-out wipes local DB and token
  · TC-B1-05 [edge] delete-account converts memberships to name-only and deletes user · TC-B1-06 [sql] deleted
  user's expenses still balance for others · TC-B1-07 [integ] Google sign-in (only if emulator has Google account)
  · TC-B1-08 [unit] release config has no dev login · TC-B1-09 [manual-opt] email code arrives from owner domain.

## B2 Profile

- Fields: display name (required), photo (crop square, avatars bucket), UPI ID (optional; validated by regex in
  `03-backend.md`; "Scan my UPI QR" fills it from a `upi://pay?pa=…` QR), default currency (for new groups; default
  INR). Shown to co-members: name, photo, UPI ID.
- Edge: invalid UPI → "Enter a UPI ID like name@bank"; photo upload offline → queued; removing UPI ID hides
  "Pay via UPI" for others.
- TC-B2-01 [unit] UPI regex accepts/rejects table · TC-B2-02 [unit] UPI QR parser · TC-B2-03 [widget] profile form
  validation · TC-B2-04 [integ] edit profile persists after restart and syncs · TC-B2-05 [sql] co-member can read
  profile, stranger cannot.

## B3 Light and dark mode

- System default; Account → Appearance: System / Light / Dark; stored in shared preferences; applied before first
  frame (no flash).
- TC-B3-01 [widget] switching updates theme · TC-B3-02 [unit] persisted value restored · TC-B3-03 [golden] every
  component in both modes (phase 02 gallery).

## 1 Groups

- Create: name, type (trip/home/couple/other), main currency (default = profile default), cover (generated by
  default, or photo). Creator becomes member #1 (owner). Rename/change type/cover/currency: any member; changing
  main currency affects only future default currency and converted views (never existing records).
- Archive (any member): moves to "Archived" section, read-only banner, unarchive anytime. Delete (creator): soft;
  restorable by the creator for 30 days from Account → Deleted groups.
- Groups tab: hero + wallet/glass overall balance + group cards grid (sorted: unsettled first, then recent
  activity); empty state "Create your first group".
- TC-1-01 [unit] group form validation · TC-1-02 [sql] create via apply_mutations makes creator owner member ·
  TC-1-03 [sql] archived group rejects new expenses (`GROUP_ARCHIVED`) · TC-1-04 [widget] groups grid states
  (empty, loading, list, offline) · TC-1-05 [golden] group card variants · TC-1-06 [integ] create group offline then
  sync · TC-1-07 [sql] only creator can delete; restore works.

## 2 Friend expenses

- Friends tab lists everyone you share a group with + direct friends, with "Total with friend" (#16).
  "Add friend expense": pick a friend (existing co-member user, or new name-only friend) → direct group created
  lazily (`find_or_create_direct_group`) → normal add-expense flow. A name-only friend gets the direct group's
  invite code/QR to claim.
- Friend page: header with avatar + total per currency, list of shared items across groups (group chip on each),
  actions: Add expense, Settle up, Remind.
- TC-2-01 [sql] one direct group per user pair · TC-2-02 [integ] friend expense appears on both friends' pages ·
  TC-2-03 [widget] friend page states.

## 3 Invite by code or QR

- Each group has an 8-char code (Crockford base32, shown `ABCD-EFGH`) and a QR of `splitify://join?code=ABCDEFGH`.
  Invite sheet: big QR, code, "Share invite" (Android share sheet with text "Join my group “Goa trip” on Splitify
  Free Forever: code ABCD-EFGH"), "Reset code". Join: Groups → Join → type code or scan QR (camera permission asked
  just-in-time). Preview shows group name/cover/member count before joining.
- Edge: invalid code → "That code doesn't match any group"; rate limited after 10 tries/hour → "Too many tries,
  wait a bit"; already a member → opens the group; archived group → can still join (read-only notice); code reset
  → old code fails; offline → "Joining needs internet".
- TC-3-01 [unit] code format/normalisation (lowercase, dashes, O/0) · TC-3-02 [sql] preview/join/rotate/rate-limit
  · TC-3-03 [widget] join screen states · TC-3-04 [integ] scan QR (inject image / deep link) → join ·
  TC-3-05 [e2e] user B joins A's group by code via harness, A sees "B joined".

## 4 Name-only members

- Add member by name (and optional tint) → name-only (`user_id` null). They appear in splits and balances.
- Claim: joiner picks "I'm Rahul" from unclaimed list or "I'm new here". Claiming links the spot (keeps all history);
  group gets activity `member_claimed`. Any member can **unlink** a wrong claim within the group settings
  (member becomes name-only again; activity logged) — protects against the wrong person claiming.
- Edge: two people claim the same spot simultaneously → second gets `ALREADY_CLAIMED`; a user can hold only one
  member per group; renaming a linked member changes only the fallback display_name.
- TC-4-01 [sql] claim/unlink rules · TC-4-02 [sql] cannot claim a linked member · TC-4-03 [widget] claim picker ·
  TC-4-04 [integ] claimed spot keeps balances.

## 5–9 Split types (equal, exact, percentages, shares, adjustment)

- Engine rules: `05-money-engine.md` §4. Editor: `FolderTabs`/segmented row `= · 1.23 · % · ⅟ shares · ±` (Splitwise
  order), member rows with avatar, checkbox (equal) or input/stepper, live footer: "₹x of ₹y · ₹z left" or
  "100 % · done" in `owedText`, errors in `oweText`. Switching type keeps chosen members; values reset sensibly
  (percent → equal percentages; shares → 1 each).
- Sentence summary on the add screen: "Paid by **you** and split **equally**" (tappable parts), like Splitwise.
- TC-5..9-01 [unit] every split vector in `money_vectors.json` · TC-5..9-02 [unit] glados property tests ·
  TC-5..9-03 [widget] editor per type: live remaining, error copy, Save disabled · TC-5..9-04 [golden] editor per
  type · TC-5..9-05 [sql] server rejects inconsistent payers/shares (`SPLIT_SUM_MISMATCH`).

## 10 Multiple payers

- "Paid by" sheet: single payer list + "Multiple people" → amounts per payer with live remaining. Payers needn't
  be participants.
- TC-10-01 [unit] payer validation vectors · TC-10-02 [widget] multi-payer sheet · TC-10-03 [unit] pairs per
  `expense_pairs`.

## 11 IOU / loan

- Quick action "Record a loan": "I lent / I borrowed", person, amount, note. Stored as `kind='iou'`; excluded from
  totals and charts; shown with a "Loan" chip.
- TC-11-01 [unit] IOU produces correct pair · TC-11-02 [widget] direction toggle copy.

## 12 Recurring bills

- On an expense: "Repeat: never / weekly / every 2 weeks / monthly / yearly" (+ optional end date). Creates a
  template; server cron adds copies on their dates (`03-backend.md` §6). Month-end clamp: 31st → last day.
  Copies are normal expenses (editable alone); editing the template affects future copies only; "Stop repeating"
  ends it. Offline phones get copies at next sync.
- TC-12-01 [sql] generation idempotent (double run = one copy) · TC-12-02 [sql] 31st clamp for Feb/Apr ·
  TC-12-03 [sql] stop/ends_on · TC-12-04 [widget] repeat picker · TC-12-05 [unit] next-date calculator parity with SQL.

## 13 Expense details and comments

- Fields: description (required), amount, currency, date, category (picker with icons, parent → sub), notes,
  receipt (#29), repeat (#12). Detail screen: hero with category icon + serif amount, who paid/owes rows,
  "Added by X on …", "Edited by Y …" link to history (#20), comments thread at bottom with composer (Atlys chat
  style, 636).
- Categories (keys): `food.dining_out, food.takeaway, food.snacks`, `groceries.groceries, groceries.household`,
  `travel.flights, travel.train_bus, travel.cab_auto, travel.fuel, travel.hotel, travel.parking_tolls`,
  `rent.rent, rent.maintenance`, `utilities.electricity, utilities.water, utilities.gas, utilities.internet_phone,
  utilities.subscriptions`, `shopping.clothing, shopping.electronics, shopping.gifts, shopping.other`,
  `entertainment.movies, entertainment.events, entertainment.games, entertainment.sports`,
  `other.general, other.medical, other.education, other.services`. Default `other.general`; last used per group
  suggested first.
- Comments: author can delete own; activity `comment_added`; notifies involved people.
- TC-13-01 [widget] form validation · TC-13-02 [widget] category picker · TC-13-03 [integ] add comment offline then
  sync · TC-13-04 [sql] comment delete only by author.

## 14 Mixed currencies in a group

- Currency picker on every expense/payment (search by code/name; recent first; group main currency on top).
  Balances, pairs, simplify and totals always per currency (separate sections "INR", "USD").
- TC-14-01 [unit] balances never mix currencies · TC-14-02 [widget] multi-currency balance sections ·
  TC-14-03 [sql] group_balances returns per-currency blocks.

## 15 Group balances

- Balances tab: per currency, each member's net (green/red/grey) and "who owes whom" (pairs, or simplified if on).
  Rows tap → settle up prefilled. Overlap banner at top: "You are owed ₹x" / "You owe ₹x" / "You're all settled".
- TC-15-01 [unit] vectors BAL-* · TC-15-02 [sql] parity with vectors · TC-15-03 [widget] balances tab states ·
  TC-15-04 [integ] local vs server checksum equal after sync.

## 16 Total with a friend

- `05-money-engine.md` §5. Shown on Friends tab rows and friend page; per currency.
- TC-16-01 [unit] across groups + direct · TC-16-02 [sql] my_overview friend totals.

## 17 Simplify debts

- Group setting toggle (off by default) with help: "Fewer payments, same totals. Someone may pay a person they
  didn't share an expense with." Balances tab shows simplified transfers when on and a link "Show original debts".
  Per currency; "after converting to INR" option available only when every record has a saved conversion.
- TC-17-01 [unit] simplify vectors + properties · TC-17-02 [sql] parity · TC-17-03 [widget] toggle + link.

## 18 Activity feed

- Activity tab: all groups, newest first, grouped by day, filter chips (All, Expenses, Payments, Comments,
  Groups). Group detail has its own feed (Expenses tab bottom or Activity section). Own unsynced actions show with
  `SyncMarker`. Tap → target.
- TC-18-01 [sql] every mutation type writes activity · TC-18-02 [widget] feed grouping/filters · TC-18-03 [golden].

## 19 Notifications

- Bell icon (Activity tab header) with unread badge → Notifications screen (list, mark all read). Push via FCM
  with channels per kind; tap opens the target. Settings: per kind toggles for push and in-app, mute group.
  Permission prompt (Android 13+) shown after first group join/create with a pre-prompt sheet.
- Edge: permission denied → in-app only + banner in settings; token refresh → re-register; uninstall → token
  removed on UNREGISTERED.
- TC-19-01 [sql] fan-out recipients exclude actor/muted · TC-19-02 [edge] send-push idempotent + token cleanup ·
  TC-19-03 [widget] bell badge · TC-19-04 [integ] notification appears in dumpsys after B adds expense ·
  TC-19-05 [unit] settings model.

## 20 Edit history and restore

- Expense/payment detail → "History": timeline of versions (who, when, what changed: field diffs incl. split
  changes), conflict versions labelled "Not applied (a newer edit won)". Restore deleted: group → menu → "Deleted
  items" → Restore (any member). Restoring writes activity.
- TC-20-01 [sql] versions written for insert/update/delete/restore/conflict · TC-20-02 [unit] diff builder ·
  TC-20-03 [widget] history timeline · TC-20-04 [integ] delete → restore round trip.

## 21 Group totals

- Totals tab: total spent (per currency, excluding IOUs and payments), per person "paid" and "share" totals,
  this month vs all time.
- TC-21-01 [unit] totals exclude IOU/payments · TC-21-02 [widget] totals tab.

## 22 Export (CSV)

- Group menu → Export CSV → UTF-8 with BOM, columns: Date, Description, Category, Currency, Amount, Paid by,
  Split type, then one column per member (net for that row, Splitwise-style), Notes, Added by, Deleted (yes/no);
  payments as rows with category "Payment"; footer total-balance row per currency. Amounts as plain decimals
  (`1250.50`), Indian grouping not used in CSV. Saved via Android share sheet / save dialog.
- TC-22-01 [unit] CSV writer escaping, BOM, totals · TC-22-02 [unit] round trip with X1 importer.

## 23 Reminder

- On balances/friend page rows where someone owes you: "Remind" → push + bell entry to them: "Mohit reminded you
  about ₹500 in “Goa trip”". Name-only members can't be reminded (button hidden, tooltip). Throttle 1/24 h per pair.
- TC-23-01 [sql] throttle + recipient · TC-23-02 [widget] remind button states.

## 25 Record a payment

- Settle up → pick person and direction → amount (prefilled with what's owed) → method (cash/UPI/bank/other),
  date, note → "Record payment" (amber). Partial payments allowed. Any currency.
- TC-25-01 [unit] payment effect on nets/pairs · TC-25-02 [widget] settle-up form · TC-25-03 [integ] settle a week
  of expenses (phase 09 e2e).

## 26 Pay via UPI

- Shown only when the balance currency is INR and the receiver (linked user) has a UPI ID. Builds
  `upi://pay?pa=<vpa>&pn=<name>&am=<amount 2dp>&cu=INR&tn=<"Splitify: Goa trip">` (URL-encoded, note ≤ 50 chars),
  opens the Android chooser of UPI apps (`<queries>` for scheme `upi`). After returning: sheet "Did the payment go
  through?" → **Mark as paid** (records payment, method `upi`) / Not yet. Fallbacks always visible: copy UPI ID,
  copy amount, show UPI QR (for paying from another phone). No UPI app → message + fallbacks. Research note: some
  UPI apps may decline P2P intent payments — the copy/QR fallback covers it.
- TC-26-01 [unit] link builder encoding/rounding · TC-26-02 [integ] fake UPI handler receives exact params ·
  TC-26-03 [integ] no UPI app → fallback sheet · TC-26-04 [widget] hidden for non-INR / no VPA ·
  TC-26-05 [manual-opt] real UPI app on a phone.

## 27 Offline entry

- All add/edit/delete/restore of expenses, payments, comments, groups (create/rename), members (name-only) work
  offline; joining, invite rotation, account deletion, rates fetch need internet (clear message). Every unsynced
  item shows `SyncMarker`; Account → Sync & storage lists issues.
- TC-27-01..10 [unit] sync engine suite (`04-sync-engine.md` §10) · TC-27-11 [e2e] airplane-mode scenario ·
  TC-27-12 [e2e] kill app mid-sync · TC-27-13 [integ] conflict both versions in history.

## 29 Receipt photo

- One photo per expense: camera or photo picker (Android photo picker, no storage permission); compress; upload
  queue (`04-sync-engine.md` §6); full-screen viewer with pinch zoom; replace/remove.
- TC-29-01 [unit] compression bounds · TC-29-02 [sql] storage policies (member-only) · TC-29-03 [integ] offline
  photo uploads later.

## 32 Currency conversion

- On a foreign-currency expense/payment: "Convert to INR" → rate auto-filled from cached `fx_rates` for the
  expense date ("1 USD = 83.12 INR · Frankfurter · 21 Nov"), editable (manual source). Saved per
  `05-money-engine.md` §6. Group-level "Show balances in INR" + "Convert all" action.
- TC-32-01 [unit] FX vectors · TC-32-02 [edge] fetch-rates upsert/throttle/backfill · TC-32-03 [sql] cross_rate
  parity · TC-32-04 [widget] conversion sheet manual/auto · TC-32-05 [unit] missing date uses previous rate.

## 33 Simple charts

- Insights (from DotMatrixCard): spending by category (donut) and by month (bars, last 12 months) for a group or
  "Me" (my shares), in the main currency using saved conversions; unconverted records excluded with a note.
  `fl_chart`.
- TC-33-01 [unit] aggregation · TC-33-02 [golden] charts.

## 34 Search

- Search icon on Groups/Activity: query matches description, notes, member names, amount (e.g. "1200" or "1,200");
  filters: group, person, date range, category. Local FTS5 — works offline.
- TC-34-01 [unit] query parser (amount detection) · TC-34-02 [integ] search finds by each field.

## 35 Default split per group

- Group settings → Default split: choose type + values (e.g. 60/40). New expenses prefill it; falls back to equal
  if members changed.
- TC-35-01 [unit] fallback rules · TC-35-02 [widget] prefill.

## X1 Import from Splitwise (CSV)

- Group (new or existing) → Import from Splitwise → pick CSV (file picker) → parse (format & algorithm in
  `research/01-product-research.md` §4) → map each Splitwise name to a member (existing / new name-only / skip) →
  preview (count, per-currency totals vs the file's "Total balance" row; mismatch warning) → Import (runs through
  normal outbox with `source='import'`, one `import_completed` activity, no per-row notifications) → result screen.
  Single-payer rows keep the original cost; multi-payer rows import as net amounts with the original cost in notes;
  "Payment" rows become payments. Undo: "Delete this import" soft-deletes the batch (`import_batch_id` in
  `split_values` meta).
- TC-X1-01 [unit] parser fixtures (quotes, BOM, multi-currency, payments, totals row, JPY) · TC-X1-02 [unit]
  reconstruction keeps nets equal to the file · TC-X1-03 [widget] mapping/preview · TC-X1-04 [integ] import 200 rows
  offline then sync.

## X2 App lock

- Account → Security → App lock (off by default): biometric or device PIN (`local_auth`), lock on cold start and
  after 1/5/15 minutes in background (default 1); recents screenshot hidden (`FLAG_SECURE` only while locked
  screen shows). Fails open to device credential, never locks the user out (if biometrics removed → device PIN).
- TC-X2-01 [unit] lock timer logic · TC-X2-02 [integ] fingerprint via `adb -e emu finger touch`.

## X3 Home-screen widget

- Android widget (2×2 and 4×2): overall balance per currency (top 2), "Updated 5 min ago" (or "Not synced yet"),
  tap → app; privacy option "Hide amounts". Updated after every sync/local write via `home_widget`.
- TC-X3-01 [unit] widget data builder · TC-X3-02 [integ] widget data updated after expense (read shared prefs).
