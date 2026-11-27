# 07 — Screens, navigation and flows

Components and tokens: `06-design-system.md`. Behaviour: `08-feature-specs.md`. Atlys references by time stamp
(e.g. 438) in `C:\Users\mohit\OneDrive\Desktop\theCode\splitify-design-reference\atlys\`.
Navigation: `go_router` with a `StatefulShellRoute` for the 4 tabs; deep links `splitify://…` handled by the router.

## 1. Route map

| Route | Screen | Atlys reference |
| --- | --- | --- |
| `/welcome` | Onboarding (D-029): Groups hero background, product preview (group covers fanned behind the glass "Overall" card), serif "split it. / settle it.", feature chips, white "Get started →" pill, "Have an invite? Join a group" (sign-in first, then join) | 455, 438 |
| `/sign-in`, `/sign-in/code` | Google / email, 6-digit code | 532 (centred question + options), 602 (underline field) |
| `/groups` (tab) | Groups home | 438 |
| `/friends` (tab) | Friends | 438 list style + 646 rows |
| `/activity` (tab) | Activity feed + bell | 646 rows, 636 empty |
| `/account` (tab) | Account (profile, wallet, cards, settings sheet) | 542, 614, 623 |
| `/groups/new`, `/groups/:id/edit` | Create/edit group | 602 |
| `/groups/:id` | Group detail (hero + FolderTabs Expenses · Balances · Totals) | 455 hero, 712 tabs/banner |
| `/groups/:id/settings` | Members, invite, default split, simplify, currency, archive, import, export | 614 accordions |
| `/groups/:id/invite` | Invite sheet (QR, code, share, reset) | 455 dashed circle around QR |
| `/join`, `/join/:code` | Join (enter/scan) → preview → claim | 532 options, 602 avatar carousel |
| `/expense/new?group=` , `/expense/:id/edit` | Add/edit expense stepper | 532, 534 |
| `/expense/:id` | Expense detail + comments | 712 layout, 636 composer |
| `/expense/:id/history`, `/payment/:id/history` | Edit history | 646 rows |
| `/settle?group=&member=` | Settle up (record / Pay via UPI) | 712 sticky bar, 646 gauge |
| `/friends/:userId` | Friend page | 542 header |
| `/notifications` | Bell list | 646 |
| `/search` | Search | 438 search pill |
| `/insights?group=` | Charts | 542 dot-matrix card |
| `/account/profile`, `/account/appearance`, `/account/notifications`, `/account/security`, `/account/sync`, `/account/deleted-groups`, `/account/about` | Settings pages | 614/623 |
| `/debug/gallery`, `/debug/login` | Debug only | — |

## 2. Key screens (layout top → bottom)

### Groups home (`/groups`) — like 438
```
[status bar over lavender→white hero]                      (search pill icon) (bell)
            split it. settle it.            ← heroDisplay, white, centred
   ┌──────────── GlassCard ────────────┐
   │ ◉ Overall   YOU ARE OWED  (pill)  │   per-currency lines: ₹2,400 · $35
   │ 3 groups · 2 people owe you       │
   │ [      Settle up      ] (white)   │
   └───────────────────────────────────┘
╭──────────────── OverlapSheet (white, r36) ────────────────╮
│  ACTIVE GROUPS · 4                         [Join] [+ New]  │
│  ┌─────────┐ ┌─────────┐   GroupCoverCard 2-col grid       │
│  │ cover   │ │ cover   │   (trip icon, GOA TRIP, divider,   │
│  │ GOA TRIP│ │ FLAT 4B │    YOU ARE OWED  ₹1,200)          │
│  └─────────┘ └─────────┘                                   │
│  Archived groups ›                                          │
╰────────────────────────────────────────────────────────────╯
        ( ●Groups  👥  ⚡  (avatar) )  (+)   ← CapsuleNavBar + amber add button
```
Empty: illustration-free EmptyState "Create your first group" + two pills (Create, Join).

### Group detail (`/groups/:id`) — hero 455 + tabs 712
Cover hero (generated) with back + share(invite) + settings icons; serif group name; StatusPill
("You are owed ₹1,200" lime-on-dark-green chip / "You owe" red chip / "All settled"); member avatar stack "+3".
OverlapSheet with `FolderTabs` Expenses · Balances · Totals:
- **Expenses:** month headers (`labelCaps`), `AmountRow` per expense (category icon circle, description, "Rahul paid
  ₹1,200", right: "you lent ₹400"/"you borrowed ₹300"/"not involved"), payments as slim rows ("Asha paid Mohit
  ₹500"), SyncMarker on pending rows.
- **Balances:** `OverlapBanner` summary, per-currency sections, member nets, who-owes-whom rows with Settle/Remind,
  simplify toggle state + "Show original debts".
- **Totals:** total spent, per person paid/share, link to Insights.
Bottom: `StickyActionBar` with amber "Add expense" and secondary "Settle up".

### Add expense (`/expense/new`, `/expense/:id/edit`) — one screen like Splitwise (D-032)
App bar: back (asks "Discard this expense?" in an app sheet once anything was typed), title "Add expense" /
"Edit expense" / "Edit future copies", and Save (enabled only when valid). Then, top to bottom:
1. "With you and" + the group chip (the friend's avatar and name for a friend expense); "saved offline" pill.
2. Category icon button (opens the category picker sheet; the small AUTO tag while the description picked it,
   D-028) + description UnderlineField (system text keyboard, sentence case; required).
3. Currency chip (currency picker) + large amount field on the system number keyboard (no custom keypad, so only
   one keyboard is ever up); text → integer minor units via `AmountExpression`.
4. One pill "Paid by You · split equally" with the live line under it ("3 people · ₹400 each", or in red what is
   left); tapping opens one sheet with the payer chips (+ "Multiple people" amounts) and the split editors.
5. Bottom toolbar (stays above the keyboard): Date (calendar sheet, today in local time), Notes, Receipt, Repeat
   chips that open sheets, and the amber full-width "Save expense". Save with a problem shows the inline errors and
   points at the first one (description → amount → sheet → notes → repeat). Success: Celebration-lite check, then
   back to the group.

### Settle up (`/settle`) — 712 + 646
Header "Settle up" serif; person row (avatar → arrow → avatar); amount (editable, prefilled); `ArcGauge` showing
how much of the total owed this payment settles; method chips (Cash · UPI · Bank · Other); date; note.
Sticky bar: if INR + VPA: amber "Pay ₹500 via UPI" and text button "Record cash payment"; else amber
"Record payment". After UPI return → sheet "Did it go through?" → Mark as paid → Celebration ("all *settled*").

### Account (`/account`) — 542 + 614/623
Top right gear opens the **Account settings** sheet. Centre: large initials/photo avatar (96 dp) flanked by
smaller faded avatars of your frequent friends (542 style, tap → friend page), name (title), `labelCaps` "YOU". `WalletCard` (overall balance per currency, tap →
breakdown). `DotMatrixCard` "Your spending" (this month, groups, people; tap → Insights). `MetalCard` "Your stats".
Settings sheet: AccordionCards **Profile** (name, photo, UPI ID, default currency), **Preferences** (appearance,
notifications), **Security** (app lock); DashedListRows: Sync & storage, Deleted groups, Import from Splitwise,
About & licences, Sign out, Delete account; footer "Version x.y.z (code)".

### Join (`/join`) — 532 + 602
Question "Join a group" (headline); OptionTiles "Enter code" / "Scan QR"; code UnderlineField with auto dash;
preview card (cover + name + members); claim step: `AvatarCarousel` of unclaimed name-only members inside the ring +
"I'm new here" pill; black "Join group" CTA.

### Others (brief)
- **Friends:** search pill; list of friends with avatar, total chip (owed/owe/settled per currency); amber
  "Add friend expense".
- **Activity:** header with bell (badge); filter IconChips; day headers; rows (actor avatar, sentence, time,
  amount); BlobBackground empty state.
- **Expense detail:** category hero band, serif amount, paid/owe rows, receipt thumbnail, "History" link, comments
  thread with composer (636: + button, pill field, send circle).
- **History:** vertical timeline; each version card shows who/when and field diffs; conflict versions muted.
- **Notifications:** AmountRow-style list, unread dot, "Mark all read".
- **Insights:** SegmentedPill (Group / Me), donut by category, bars by month, legend chips.
- **Sync & storage:** status tiles (last sync, queued, failed), failed list with actions, "Sync now".
- **Loading states:** skeleton shimmer for lists; `StackedCardsLoader` for first sync, import, joining.

## 3. Flows (happy paths; e2e scenarios reuse these)

1. **First run:** welcome → sign-in (Google or email code) → profile name confirm (+ optional UPI) → notification
   pre-prompt → Groups (empty) → Create group.
2. **Add expense:** group → Add expense → description + amount → (defaults) → Save → row appears with SyncMarker → marker clears
   after sync.
3. **Settle up:** group Balances row "You owe Asha ₹500" → Settle → Pay via UPI → chooser → return → Mark as paid.
4. **Join:** Groups → Join → scan/enter → preview → claim "Rahul" → group opens.
5. **Offline:** airplane mode → add/edit/delete → markers → back online → markers clear, other member sees changes.
