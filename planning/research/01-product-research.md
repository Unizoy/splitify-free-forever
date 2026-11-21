# 01 Product research: Splitwise behaviour, CSV, competitors, open-source lessons

Date: 2026-11-21. Budget used: 25 web calls. Tag **[UNVERIFIED]** = from memory or a single weak source, not confirmed on a primary page.
Gaps (not reached in budget, all [UNVERIFIED] below): Splitwise help pages for recurring, delete group, leave group, undelete, account deletion, reminders; full API category list; competitor pages; Reddit/review mining; SplitPro balance/simplify source file.

## 1. Splitwise 2026: free plan, Pro, ads

| Topic | Finding | Source |
| --- | --- | --- |
| Daily cap | Free users "can add up to 4 expenses each day". Some App Store reviews say 3. | [Splitwise KB: What is Pro](https://kb.splitwise.com/pro/what-is-splitwise-pro) |
| Cap scope | One review site says "4 new expenses per member per day", another says it is counted across all groups. Blocks entry until next day or upgrade. Exact reset rule (calendar day vs rolling 24h, timezone) not published. | [Money Crashers](https://www.moneycrashers.com/splitwise-review/) |
| Ads | Free plan shows ads. Users report a ~10 second countdown before an expense saves. | [Money Crashers](https://www.moneycrashers.com/splitwise-review/), web-search summary |
| Pro price US | $4.99/month or $39.99/year (US App Store). | [Money Crashers](https://www.moneycrashers.com/splitwise-review/) |
| Pro price India | **Not confirmed.** App Store India listing summary showed Pro at Rs 499 (in-app purchase, April 2026 data); a rival site claims about Rs 250/month. Official help page lists no prices. [UNVERIFIED] | [App Store IN](https://apps.apple.com/IN/app/id458023433), [Splitwise KB](https://kb.splitwise.com/pro/what-is-splitwise-pro) |
| Plan types | Annual Individual + Trip Pass, annual Duo + Trip Pass, monthly. Yearly Trip Pass gives every member of one trip group Pro for 30 days. | KB above, Money Crashers |
| UPI billing | Splitwise KB has an article "Why was I charged via UPI during my free trial?" so UPI payment of Pro exists in India. | [KB Pro index](https://kb.splitwise.com/pro) |

Pro-only features (KB list): unlimited expenses; transaction import (select countries, card link); search across full history; currency conversion to default currency; receipt scanning + itemization; charts (spending by category over time); default splits. Money Crashers adds ad-free and early access to new features. Android Central says free users can still record expenses in several currencies in one group, only conversion is Pro ([Android Central](https://www.androidcentral.com/apps-software/the-app-splitwise-is-the-best-hack-to-split-group-trip-expenses-in-2026)). Money Crashers says the free Itemize tool exists but scanning is Pro (sources conflict on itemize).

PLAN.md says "people can't add a friend who hasn't signed up (except website)". Not re-verified here. [UNVERIFIED]

## 2. Splitwise exact behaviours to match or decide

Only pages marked VERIFIED were read. Others come from memory of the app and should be re-checked before being treated as spec.

| Behaviour | What Splitwise does | Status | Decision for Splitify |
| --- | --- | --- | --- |
| Simplify debts guarantee | "It never changes anyone's total balance." Reduces number of payments by rerouting who pays whom. Works "within each currency separately". Pairwise amounts between specific members may be reshuffled. Turning it off after people paid can undo simplified paths (people may need to resend, nobody overpays). Any group member can toggle in group settings. | VERIFIED [KB](https://kb.splitwise.com/balances-and-expenses/what-is-simplify-debts) | Matches PLAN rule 12. Add a "who can toggle" decision: any member. |
| Simplify default for new groups | KB page silent. Older UserVoice article said it is off by default "as it can cause confusion"; users asked for default-on. | Partly VERIFIED, old ([UserVoice](https://splitwise.uservoice.com/knowledgebase/articles/107220-what-does-the-simplify-debts-setting-do)) | Off by default (matches PLAN). Offer toggle at creation. |
| Simplify "does nothing" case | Help article: debt simplification sometimes changes nothing. | Title only ([UserVoice 150674](https://splitwise.uservoice.com/knowledgebase/articles/150674-why-didn-t-debt-simplification-change-anything)) | Show a "nothing to simplify" message. |
| Remove member | If member has an outstanding balance you must "clear their balance first": record a cash payment, or edit each shared expense and remove them. Page does not say what happens to past expenses. | VERIFIED [KB](https://kb.splitwise.com/groups/how-do-i-remove-a-person-from-a-group) | Same rule: only remove at zero balance in every currency; keep their name on old expenses (rule 8, 9). |
| Leave group | Not covered by the page read. Memory: you cannot leave while you owe or are owed. [UNVERIFIED] | UNVERIFIED | Same rule as remove. |
| Delete / undelete group | KB article exists "How do I delete or undelete a group?" Notification types 6 (group deleted) and 12 (group undeleted) exist in API. Content not read. | Title only | Soft-delete group, restorable (rule 9). Spliit also schedules group deletion (`deleteAt`). |
| Deleted expense restore | KB article "How can I restore a deleted expense?" exists; API has "expense undeleted" notification (13) and `deleted_at`. Memory: restore from the group's expense list, as web feature. [UNVERIFIED] | Title only | Restore button in activity/history. |
| Recurring expenses | KB article exists. Memory: weekly, every 2 weeks, monthly, yearly; created on due date; monthly on the 29th-31st lands on last day of short months. [UNVERIFIED] | Title only | Use anchor-day logic (Spliit: `anchorDay`, "a 31st clamps in February and returns to the 31st in March", see section 6). |
| Edit history / comments | Memory: expense detail shows who added and last edited, comments thread; edits appear in the activity feed. [UNVERIFIED] | UNVERIFIED | PLAN already exceeds this (full version history). |
| Reminders | Memory: "Remind" sends push/email; Pro/free both. [UNVERIFIED] | UNVERIFIED | Push + bell only (PLAN). |
| Notification types | API list (VERIFIED, section 3): expense added/updated/deleted/undeleted, comment, added/removed from group, group deleted/undeleted/settings changed, friend added/removed, news, debt simplification, group/friend currency conversion. | VERIFIED | Map to our kinds: expense, edit, payment, reminder, comment, group. |
| Account deletion effect | Memory: other members keep the expenses; the deleted user's balances must be settled first. [UNVERIFIED] | UNVERIFIED | Decision needed: convert deleted account to a name-only member (rule 8) so history stays and balances stay exact. |
| Adding non-users | Memory: mobile adds by name/email/phone; non-user gets invite. [UNVERIFIED] | UNVERIFIED | Name-only members (PLAN #4). |
| Settled-up undo | KB article "I accidentally settled up - how can I undo this?" Payment is an expense with `payment: true`. | Title only + API | Payments are deletable and restorable like expenses. |
| Refund / reimbursement | KB article exists "How do I add a refund or reimbursement?". | Title only | Support negative-style via payment or "refund" expense; decide in TECH_PLAN. |
| Permissions | KB article "Can I prevent group members from changing expenses, or set permissions?" exists. | Title only | Keeps open decision 11 relevant; read this page before deciding. |
| Default split | Pro-only. | VERIFIED | Free in Splitify (PLAN #35). |
| Currency conversion | Pro-only; separate KB article on how exchange rates are calculated. Notification types 14/15 for group/friend conversion. | Titles + API | Per-expense saved rate (PLAN rules 4,5). |
| Add-expense sentence | App shows "Paid by **you** and split **equally**" with two tappable chips; tap payer chip -> choose payer or "multiple people"; tap split chip -> split screen. [UNVERIFIED] | UNVERIFIED | Copy the pattern: sentence under amount. |
| Split tabs | Equally (=), By exact amounts (1.23), By percentages (%), By shares (stacked bars icon), By adjustment (+/-). Validation text under list, e.g. "Rs 40.00 left" / "Rs 10.00 over" in red; Done disabled until 0 left. [UNVERIFIED] | UNVERIFIED | Same five tabs as PLAN #5-9. Show remaining amount live. |

Split types Splitwise lists in its help: equal, unequal (exact), percentages, shares, adjustment, reimbursement/payment. KB: [different ways to split](https://kb.splitwise.com/balances-and-expenses/what-are-different-ways-i-can-split-an-expense) (title only).

## 3. Splitwise API data model ([dev.splitwise.com](https://dev.splitwise.com/))

| Object | Fields (VERIFIED from page unless noted) |
| --- | --- |
| Expense `users[]` | each: nested `user` (id, name, picture), `user_id`, `paid_share`, `owed_share`, `net_balance`. `paid_share` = amount this user paid; `owed_share` = amount this user owes. Net = paid - owed. |
| Expense other | `payment` (boolean, settle-up flag), `category` {id, name} plus `category_id`, `repayments` list of {from, to, amount}. Others from memory: `cost` (string decimal), `currency_code`, `date`, `deleted_at`, `created_by`, `updated_by`, `group_id`, `repeat_interval`, `details`, `comments_count`, `receipt`. [UNVERIFIED] |
| Amounts | Decimal strings in the API (e.g. "25.0"), not integers. [UNVERIFIED] |
| Categories | Must use a subcategory, not a parent. Use "Other" subcategory if nothing fits. |

Notification types (numeric `type`, VERIFIED): 0 expense added; 1 expense updated; 2 expense deleted; 3 comment added; 4 added to group; 5 removed from group; 6 group deleted; 7 group settings changed; 8 added as friend; 9 removed as friend; 10 news (URL); 11 debt simplification; 12 group undeleted; 13 expense undeleted; 14 group currency conversion; 15 friend currency conversion. Splitwise warns types may be added without notice.

Category list (page truncated in fetch; this is from memory of `get_categories`, **[UNVERIFIED]**, re-check before copying):

| Parent | Subcategories |
| --- | --- |
| Uncategorized | General |
| Entertainment | Games, Movies, Music, Other, Sports |
| Food and drink | Dining out, Groceries, Liquor, Other |
| Home | Electronics, Furniture, Household supplies, Maintenance, Mortgage, Other, Pets, Rent, Services |
| Life | Childcare, Clothing, Education, Gifts, Insurance, Medical expenses, Other, Taxes |
| Transportation | Bicycle, Bus/train, Car, Gas/fuel, Hotel, Other, Parking, Plane, Taxi |
| Utilities | Cleaning, Electricity, Heat/gas, Other, Trash, TV/Phone/Internet, Water |
Page confirms Utilities id 1 with Cleaning and Electricity (id 5) exist.

Lesson: store `paid_share` and `owed_share` per user per expense (our `expense_payers` + `expense_splits`); net and repayments are derived. Multi-payer is native.

## 4. Splitwise CSV export format

No official spec. Evidence: [Spliit issue #22](https://github.com/spliit-app/spliit/issues/22) (author's description), [Spliit issue #342](https://github.com/spliit-app/spliit/issues/342) (real sample as of 2025), [import gist](https://gist.github.com/ChristopherJohnston/a6e69bd8894f20ecfe127fa4149bd013).

| Item | Format |
| --- | --- |
| Scope | One file per group ("Export as spreadsheet"), plus a personal/non-group export. Per-group only per third-party notes. |
| Header | `Date,Description,Category,Cost,Currency,<Member1>,<Member2>,...` (5 fixed columns then one per member). Issue #342 shows the same with names Alice, Bob, Carol, Dave. |
| Member cell | **Paid minus owed** for that row, signed. Payer of 100 split evenly between 2: payer +50.00, other -50.00. Multi-payer rows have several positives. |
| Sign | Positive = is owed (net lender on that row); negative = owes. |
| Date | `YYYY-MM-DD` (e.g. 2025-05-17). |
| Numbers | Plain decimals with dot, no currency symbol, no thousands separator (e.g. `10`, `-10`, `0`, `25.50`). [UNVERIFIED on thousands/locale] |
| Currency | Column 5, ISO code (USD). A group can contain several codes; Total balance row appears per currency. [UNVERIFIED] |
| Payment row | Sample: `2025-05-17,Bob paid Carol,Payment,10,USD,0,10,-10,0`. Category is the literal `Payment` (localised: German export says "Zahlung", so users must switch to English). Description pattern "X paid Y". Payer cell is +amount, receiver cell is -amount. |
| Total balance row | Sample: `2025-05-17,Total balance,,,USD,-10,0,10,0` - Description = "Total balance", Category and Cost empty, member cells = column sums (net balance). Positive = owed money. |
| Other quirks | Blank lines between sections; final total row must be dropped on import; ledger loses split mode (equal vs shares), so import cannot reproduce the original split. Category cell is like `Utilities - Electricity` (importer strips `" - other"`). |

Real parser logic quoted (Christopher Johnston gist for Spliit, TypeScript):
- Members: `const participantList = Object.keys(data[0]).slice(5)` (skip 5 fixed columns).
- Payment test: `expenseCategory = expenseRow.Category.toLowerCase().replace(" - other","")`; `if (expenseCategory == "payment")` then only negative cells become payees; stored as reimbursement.
- Payer: the participant with a positive cell. `paidByShare = Math.round((Cost - totalOfNegatives)*100)`; others `Math.abs(value*100)`.
- Amount: `Math.round(Number(Cost)*100)` (integer minor units); date: `new Date(Date)`.
- Weakness: gist ignores the Total balance row (would be parsed as expense, skipped only because no positive cell), hardcodes currency, rounds only the payer share. Issue #22 warns "rounding differences will accumulate".
- Fork note: sebitr/balancia fixed "Bob paid Carol" direction; a fork (spliit.cloud) added a Personal/Group CSV import wizard (per issue #22, July 2026). SplitPro imports Splitwise via a JSON from an external site and an API-shaped schema, not CSV (draft [PR #465](https://github.com/oss-apps/split-pro/pull/465), `importGroupFromSplitwise` in `splitService.ts`, not read).

**X1 import algorithm for Splitify (derived):**
1. Parse with a real CSV parser (quoted commas in descriptions). Trim BOM. Header must start `Date,Description,Category,Cost,Currency`.
2. Skip empty rows and the row where Description = "Total balance" (use it as a checksum: sums of imported nets must equal it; show a warning if not).
3. For each row: cost to integer minor units using the currency's decimals (INR 2, JPY 0, KWD 3) with string math, not floats.
4. Cells to integer nets; positives are payers; `owed_i = paid_i - net_i`, where `paid_i = net_i` if net>0 else 0 only valid when payer paid nothing of their own share. General reconstruction: total paid = Cost; if one positive cell P: payer paid Cost, owes P - Cost... i.e. `owed_payer = Cost - P`; each negative cell owes |value|. Multi-payer: ambiguous (split between payers unknown); choose proportional to positives and flag the row.
5. Category "Payment" (also match localised names via a user pick) -> payment record from the positive cell member to the negative cell member.
6. Map columns to members by name; let the user map/skip/create name-only members (fits rule 8). Rows with several currencies stay per currency (rule 4).
7. Ledger import loses split type: import as exact amounts and say so. Dedupe: store import batch id; allow undo of whole import (rule 9).

## 5. Competitors

Only Spliit/SplitPro details were fetched; the rest are memory. [UNVERIFIED] unless noted.

| App | Standout | Offline | Multi-currency | Simplify | Notes |
| --- | --- | --- | --- | --- | --- |
| Spliit | No sign-up, link-based groups, receipt scan (AI), recurring with anchor day, categories, CSV/JSON export, MIT. Verified via repo. | No (web app) | Per-expense original amount + rate; group has one currency | Greedy "suggested reimbursements" | [github.com/spliit-app/spliit](https://github.com/spliit-app/spliit) |
| SplitPro | Splitwise-like UX, friends + groups, import from Splitwise, adjustment + currency-conversion split types, PWA, open source. Verified via repo schema. | PWA partial [UNVERIFIED] | Balance per currency; conversion linked expenses | `simplifyDebts` per group (default false) | [github.com/oss-apps/split-pro](https://github.com/oss-apps/split-pro) |
| "Splittl" | No product found by that name in searches; assumed typo for Spliit (AGPL/MIT not checked). | - | - | - | Not verified. |
| Tricount (Bunq) | Easy sharing without accounts, trip focus, free with limits then paid tier; attached receipts. | Yes (reports) | Yes | Basic | [UNVERIFIED] |
| Settle Up | Multi-currency strong, offline, free, ads; recurring; group "who pays next" idea; Google/email sign-in. | Yes | Yes, rates | Yes (optimise) | [UNVERIFIED] |
| Splid | Very simple, no account, offline-first, free base; paid for export/more. | Yes | Yes | Yes | [UNVERIFIED] |
| GPay / PhonePe / Paytm split | Split inside UPI app; pay directly; no multi-currency/group history depth. India reach. | Needs net | INR only | No | Referenced in PLAN; [UNVERIFIED] |
| Splitkaro, Splitwise-likes in India | Several Play Store clones with UPI; quality unknown. | ? | ? | ? | [UNVERIFIED] |
| Cospend (Nextcloud) | Self-host, import Splitwise csv issue exists. | no | yes | yes | [UNVERIFIED]; [issue](https://github.com/julien-nc/cospend-nc/issues/203) |

Takeaway: free offline-first + multi-currency + UPI + Splitwise CSV import is an open gap; none of the open-source options is offline-first on Android.

## 6. Open-source code lessons

### Spliit (TypeScript, Prisma, Postgres)
Schema: [prisma/schema.prisma](https://github.com/spliit-app/spliit/blob/main/prisma/schema.prisma). VERIFIED fields:

| Model | Fields |
| --- | --- |
| Group | id, name, information, currency (symbol, default "$"), currencyCode, createdAt, deleteAt (scheduled deletion) |
| Participant | id, name, groupId (name-only members, no accounts) |
| Expense | id, groupId, expenseDate, title, notes, amount Int, originalAmount, originalCurrency, conversionRate Decimal, categoryId, paidById (single payer), isReimbursement, splitMode, recurrenceRule, recurringExpenseLinkId, createdAt |
| ExpensePaidFor | expenseId+participantId, shares Int (default 1) |
| Category | id, grouping, name |
| ExpenseDocument | url, width, height |
| Activity | id, groupId, time, activityType, participantId, expenseId, data |
| RecurringExpenseLink | currentFrameExpenseId, nextExpenseDate, nextExpenseCreatedAt, anchorDay (1-31; "A 31st clamps in February and returns to the 31st in March") |
| Enums | SplitMode: EVENLY, BY_SHARES, BY_PERCENTAGE, BY_AMOUNT; RecurrenceRule: NONE, DAILY, WEEKLY, MONTHLY, YEARLY; ActivityType: UPDATE_GROUP, CREATE_EXPENSE, UPDATE_EXPENSE, DELETE_EXPENSE, SCHEDULE_GROUP_DELETION, RESTORE_GROUP |

Weaknesses to avoid: one payer only; hard-deletes expenses (no soft delete column); no per-expense edit history; no accounts or RLS; amount currency is on the group.

Balance algorithm: [src/lib/balances.ts](https://github.com/spliit-app/spliit/blob/main/src/lib/balances.ts) (VERIFIED by read):
1. `getBalances`: per expense `paid[payer] += amount`; `getExpenseShares` splits the amount and `paidFor[p] += share`. `total = paid - paidFor`; positive means owed money.
2. Rounding: shares are already whole minor units; final `Math.round(x)+0` is a guard (the `+0` removes -0).
3. `getSuggestedReimbursements`: drop zero totals; sort positives first, tie by participant id (stable output); two-pointer greedy: match largest creditor end with debtor end, settle at least one person per step, so at most n-1 payments, not guaranteed minimum; drop transfers that round to zero.
4. `getPublicBalances`: rebuild balances from the suggested reimbursements (`from.total -= amount`, `to.total += amount`).
Share rounding in `lib/shares` was not read; Spliit comments say shares are integer minor units. Confirm leftover-distribution order before copying. [UNVERIFIED]

### SplitPro (TypeScript, Prisma, Postgres)
Schema: [prisma/schema.prisma](https://github.com/oss-apps/split-pro/blob/main/prisma/schema.prisma). VERIFIED:

| Model | Fields |
| --- | --- |
| Group | id, publicId, name, userId, defaultCurrency, simplifyDebts (default false), archivedAt, splitwiseGroupId |
| GroupUser | groupId+userId |
| Expense | id UUID, paidBy, addedBy, name, category, amount BigInt, splitType, currency, groupId?, deletedAt, deletedBy, updatedBy, recurrenceId, conversionToId (unique) |
| ExpenseParticipant | expenseId+userId, amount BigInt (signed share) |
| BalanceView | userId, friendId, groupId?, currency, amount BigInt: "Unified balance view that calculates balances from expenses" (a DB view; old Balance/GroupBalance tables deprecated) |
| SplitType | EQUAL, PERCENTAGE, EXACT, SHARE, ADJUSTMENT, SETTLEMENT, CURRENCY_CONVERSION |

Good ideas: balances computed by a Postgres view (matches rule 3); settlement and currency conversion are expense rows with a type; soft delete with deletedBy; `simplifyDebts` per group. The simplify algorithm file was not found in this budget; ask the next agent to read `src/lib/` in split-pro. [UNVERIFIED]

### Lessons table

| Lesson | Apply |
| --- | --- |
| Integer minor units (both) | Rule 1. Use BIGINT in Postgres, `int` in Dart (64-bit). |
| Balances from a view/function, not stored | Postgres view over expenses + splits per (group, currency, user). |
| Settlement = expense with type | One table, `kind` column: expense, payment, conversion. |
| Sort ties by id for stable simplify | Do this so every phone shows the same plan. |
| Greedy simplify is not minimal | Fine (max n-1 payments). Exact minimum is NP-hard; do not promise it. |
| Leftover rounding | Give 1 unit each to people in fixed order (e.g. by member sort key); same function in SQL and Dart, test against shared vectors. |

## 7. User pain points and ideas

Evidence base is thin: web-search summaries and product pages, no Reddit threads were fetched. Treat the pain list as hypotheses to validate. Items marked V have a source in this report.

| # | Pain point (Splitwise and others) | Evidence |
| --- | --- | --- |
| 1 | Daily 3-4 expense cap on free plan | V: [KB](https://kb.splitwise.com/pro/what-is-splitwise-pro) |
| 2 | Ads and 10 second wait before saving | V: Money Crashers |
| 3 | Search, charts, default split paywalled | V: KB |
| 4 | Currency conversion paywalled | V: KB |
| 5 | Simplify debts off by default / confusing, "changed nothing" | V: UserVoice |
| 6 | Users want a simplify on/off toggle and easier access | V: UserVoice feature requests |
| 7 | Balances don't match dashboard vs group ("help my balances are wrong") | V: [UserVoice article](https://splitwise.uservoice.com/knowledgebase/articles/425486-help-my-balances-are-wrong) title |
| 8 | Hard to remove a member with a balance (must clear balances first) | V: KB |
| 9 | Accidentally settled up, need undo | V: KB title |
| 10 | CSV export loses split details; one group at a time | V: Spliit #22 |
| 11 | Export localised ("Zahlung"), breaks imports | V: Spliit #22 |
| 12 | No offline entry in many apps | [UNVERIFIED] |
| 13 | Pro price too high for India; payment friction | [UNVERIFIED] |
| 14 | Need to mark a group as "all expenses entered" before settling | V: UserVoice request title |
| 15 | Settling through UPI needs manual typing of amount | [UNVERIFIED] |

Top 10 ideas to adopt (no extra paid services, free):

| # | Idea | Fit |
| --- | --- | --- |
| 1 | "Paid by you and split equally" sentence with live "Rs x left" validation | UI only |
| 2 | Per-currency simplify with a visible "no change" explanation and an off switch | rule 12 |
| 3 | Soft-delete + restore + undo-settle everywhere | rule 9, Postgres |
| 4 | Import from Splitwise CSV with checksum from the Total balance row and a mapping step (X1) | client-only parser |
| 5 | Settlement and currency conversion as typed rows in the expenses table (SplitPro) | schema |
| 6 | Balance view in Postgres, same function used for local offline estimate | rule 3 |
| 7 | Recurring with anchor day (Spliit) so the 31st returns after short months | Edge Function cron (pg_cron) |
| 8 | Group "settle now" lock or banner ("all entered?") before final settle | tiny UI |
| 9 | Export CSV in Splitwise-compatible layout (round trip, and lets users leave freely) | client |
| 10 | Remove-member flow that offers "record cash payment to clear" in one tap | UI |

Extras from owner (X2 app lock, X3 home widget): not researched; use Android `local_auth` and a Flutter `home_widget` plugin, hide balance in the recents screen (`FLAG_SECURE`). [UNVERIFIED]

## Sources fetched

[PLAN.md], [Splitwise KB pages](https://kb.splitwise.com/), [dev.splitwise.com](https://dev.splitwise.com/), Spliit schema and balances.ts, SplitPro schema and user.ts, Spliit issues #22 and #342, the import gist, Money Crashers, Android Central, App Store IN (via search snippets only).
