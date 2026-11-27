# 10 Splitwise flows: hands-on walkthrough of the free tier, plus the Pro list (D-034)

Date: 2026-11-27. Owner request D-034: take Splitwise as the reference for flows and minimalism (not its look),
and give everything in Splitwise Pro for free.

**How this was done**
- **App:** Splitwise for Android 26.11.3 (build 977), installed from the Play Store on the shared emulator (Pixel 9,
  API 36). Signed in with "Sign in with Google" using the emulator's Google account. Phone time zone is India.
  This is the **free tier**.
- **Test data:** one throwaway group, "Splitify research", with two fake people (reserved `example.com`
  addresses). Five expenses, three payments and one comment were created. Everything was deleted at the end:
  the group, the expenses, the payments and the friend. Nobody real was invited or reminded.
- **Pro features:** the app shows only their paywall screens. For how they work, see the web sources at the
  end (Splitwise's Pro page and help centre).
- **Screenshots:** about 90, kept outside the repo because they are Splitwise's copyrighted UI:
  `C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\splitwise-reference\`. File names start with a
  step number (for example `22-add-expense-form.png`).
- **Wording:** everything below is in our own words. Short UI labels are quoted only where the exact label
  matters.

Tap counts count taps only (typing is not counted). "Free" and "Pro" mean the Splitwise tier.

---

## 1. What makes Splitwise feel minimal (the patterns)

1. **One home for each job.** Four tabs (Groups, Friends, Activity, Account) and one green **Add expense**
   button that floats on every list screen.
2. **Balances are shown before you ask.**
   - Each tab opens with one line ("Overall, you are owed ₹300").
   - Every group or friend row repeats the per-person lines under it.
   - The group page lists who owes you right under its name, in a section that can be collapsed.
3. **The add form reads as a sentence.** "With you and: [group]", then the description, then the amount, then
   "Paid by [you] and split [equally]". Each bracketed word is a button. Nothing else is on the form.
4. **Extras live in one bottom strip.** Group, date (repeat sits *inside* the date screen), camera, and notes,
   shown as icons.
5. **Two-person shortcut.** When only you and one friend are involved, the split button opens four one-tap
   answers: you paid / they paid × split equally / owed the full amount. "Owed the full amount" is how a loan is
   entered, so there is no separate loan screen.
6. **Secondary group actions sit in one row of chips that scrolls sideways:** Settle up, Convert currency,
   Charts, Balances, Totals, Whiteboard, Export. Nothing is hidden in an overflow menu.
7. **Settling is one screen.** It shows two avatars with an arrow, a big amount already filled in, and one
   button. A note says no money moves. Other choices (group, date, photo, notes) show up only after you tap the
   amount.
8. **Settle everything with one person in one go.** From a friend's page, "Settle all balances" makes one
   payment. Splitwise then clears every group balance between the two of you and records how it split the
   payment across groups.
9. **History stays out of the way.** When you are settled with a friend or in a group, older expenses collapse
   behind "Tap to show settled expenses".
10. **Disabled, not failed.** "Leave group" stays visible but greyed out, with a sentence explaining why. You
    never tap it only to get an error.
11. **Restore is on the deleted item itself.** Tap the "deleted" row in Activity, and the expense page has
    Restore in its top bar.
12. **Notes are part of the comments.** The expense's note is shown as the first message in the comment thread,
    so the page has one section instead of two.

---

## 2. Free-tier limits and upselling (seen on the device)

- **Daily cap: 4 new expenses a day** (which matches the help centre).
  - **3rd and 4th add:** before the form opens, a full-screen Pro offer appears with a gift picture, "Start your
    free trial", and a **"Continue in N" button that counts down about 10 seconds**.
  - **5th add:** a hard wall. "Unlock unlimited expenses with Pro… or wait until tomorrow when your daily limit
    resets". There is no way to continue.
  - **Not limited:** recording payments still works after the cap.
- **Ads:** no banner or video ads appeared during this session. The selling was all Pro screens and badges.
- **Pro badges in the free app:**
  - a diamond on the Charts chip (group and friend pages)
  - "Convert to USD" (the account's default currency)
  - a PRO tag on "Default split" in group settings
  - Search (every tab's search icon opens the paywall)
  - "Scan Receipt" in the attach sheet
  - "View more charts" on the expense page
  - the settle-up reminder switch on Home-type groups
  - the "Trip Pass" card in group settings
- **Promo cards:** "Do more with Splitwise Pro" on the Account tab, and "Pro users get more" on Totals.
- **Price shown in the app (India, Play billing):** "Individual + Trip Pass" for 12 months costs ₹1,399
  (shown as ₹116.58 a month), with a 7-day free trial for first-time subscribers.
- **Default currency trap:** after Google sign-in from India, the account's default currency was **USD**. The
  first expense started in $. After INR was picked once, the currency picker remembered it under "Recent".

---

## 3. Flows, one by one

### 3.1 Onboarding and sign-in

1. **Start screen:** Sign up / Log in / Sign in with Google.
2. **Google:** pick the account (1 tap), then "Agree and share" (1 tap).
3. **Welcome carousel:** 3 swipe pages. "Welcome, [name]" with a sample balance card, then "Add expenses", then
   "Settle up".
4. **"Let's get started":** three cards. Add a group trip / Add your household / Skip setup for now.
5. **Notification permission:** asked as soon as a card is chosen. We declined.

**Taps to an empty trip group:** 3 sign-in taps, 2–3 swipes, 1 card, 1 permission answer, 1 for Done. On Done,
a dialog may also need 1 tap (see 3.3).

### 3.2 Home tabs

**Groups**
- **Top bar:** search (Pro) and create group.
- **Summary line:** "Overall, you are owed ₹X" with a filter button. The filter has four options: All groups /
  Outstanding balances / Groups you owe / Groups that owe you.
- **Group rows:** cover image, name, "you are owed ₹300", then one line per person ("Asha owes you ₹200").
- **"Non-group expenses":** a pseudo-group for friend expenses.
- **"Start a new group"** button, and the floating **Add expense**.

**Friends**
- Same summary line and filter.
- Friend rows: name, then "owes you ₹200" / "you owe" / "settled up".
- "Add more friends" button.
- Top bar: search (Pro) and add friend.

**Activity**
- One flat list, newest first, with no filters.
- Each row is a sentence plus your effect and a time, e.g. "You added "Dinner" in "Group". You get back
  INR400.00 · Today, 8:35 PM".
- It also has milestone rows such as "You are fully settled up with Asha".
- Search is Pro. There is no separate notifications bell.

**Account**
- Name and email with **Edit**.
- Pro promo card.
- **Scan code**.
- **Splitwise Pro**.
- **Preferences:** Email settings, Device and push notification settings, Security, Appearance.
- **Help & Support:** Help Center, Contact support, Rate.
- **Log out**, and the version at the bottom.

### 3.3 Create a group

**Entry points:** Groups → create icon (or "Start a new group", or the onboarding card).

**One screen:**
- Photo button, Group name (focused, keyboard up).
- Type tiles: Trip (selected by default), Home, Couple, Other.
- **What appears under the type depends on it:**
  - **Trip:** "Add trip dates" switch, **on by default**, with Start = today and End empty. Help text says
    Splitwise will remind people to join, add expenses and settle up.
  - **Home:** "Add settle up reminders" switch instead. It is Pro: tapping it opens the paywall ("Custom group
    reminders").
- **No group currency.** Splitwise uses each person's default currency.
- **Done.** With trip dates on but no end date, a dialog asks to "Turn off and save" (1 extra tap every time).

**After saving:** the new group page shows "You're the only one here!" with **Add group members** and **Share
group link**.

### 3.4 Add members and friends

- **Add group members:**
  1. Contacts permission prompt; we declined. The screen then offers "Allow contact access".
  2. One search field: name, email or phone.
  3. Typing a new name shows `Add "Asha" to Splitwise` (1 tap). A form opens with name plus **phone or email**.
- **Email or phone is required.** Next without it gives the error "Enter an email address or phone number for
  this person". A name-only member is impossible in the app.
- **Several people:** each chosen person becomes a chip at the top. Next goes to **Review** (each person with
  Edit and ×). Its note says people with email/phone will be told they were added. Then "Add members".
- **Cost:** about 4 taps plus 2 fields per person, then 2 taps to finish.
- **Group invite:**
  - **Group settings → Invite via link:** the link, Copy link, Share link, Change link. **No QR for groups.**
- **Personal code:**
  - **Account → Scan code:** two tabs. **Scan** a friend's code, or show **My Code**: a personal QR plus
    `splitwise.com/l/add_friend/…`, with Share / Copy / Change code and a warning to share it only with people
    you trust.
  - Scanning someone's code adds them as a friend.
- **Friends tab → add:** the same person search and form as above.

### 3.5 Add expense (group)

**Entry:** the floating **Add expense** on the group page.
- The first time only, a dialog says "This expense will be split with 3 people" with "Start adding expenses" /
  "Edit group members".

**The form (one screen):**
- **App bar:** ← and ✓ (save).
- **"With you and:"** with the group chip, plus an inline text box to add more people or groups.
- **Category tile:** a receipt icon at first. It **changes by itself as you type** ("Dinner" turned it into a
  dining icon). Tapping it opens the category list.
- **Description**, focused, with the keyboard up.
- **Currency tile ($)**, then the **amount** in large digits.
- **"Paid by [you] and split [equally]".** There is no per-person line on the form; that sits in the split
  screen's footer.
- **Bottom strip:**
  - **group chip:** opens a picker with Recent, All, and "Not in a group"
  - **date:** a calendar, with a **Repeat** row inside offering Off / Weekly / Fortnightly / Monthly / Yearly
    and no end date
  - **camera:** a system chooser with Camera, Photos, **Scan Receipt (Pro)**, Files, Drive
  - **notes:** its own small screen with Save

**Currency picker:** full screen with a search field, then "Recent", then all currencies A–Z.

**Paid by:** full screen "Who paid?" listing every member plus "Multiple people". Multiple people opens "Enter
paid amounts": one amount field per person, with a footer like "₹0.00 of ₹600.00 · ₹600.00 left".

**Split ("Adjust split"):** full screen with tabs that scroll sideways.
| Tab | How it works | Default and footer |
| --- | --- | --- |
| Equally | Checkbox per person, plus an "All" checkbox in the footer | All ticked; footer "₹200.00/person (3 people)" |
| Unequally | Exact amount per person | Footer "₹0.00 of ₹600.00 · ₹600.00 left" |
| By percentages | % per person | All 0; footer "0% of 100% · 100% left" |
| By shares | Shares per person; help text mentions nights and families | **All 0** (not 1); footer "0 total shares" |
| By adjustment | Extra amount per person; the rest is split equally | All 0 |

There is **no itemized tab** in the free app. Itemization is Pro and starts from a scanned receipt.

**Save:** ✓ goes straight back to the group. There is no success animation. The new row shows the date column
(Nov / 27), the category tile, the description, "You paid ₹600.00", and on the right "you lent ₹400.00".

**Taps (group page → saved):** Add expense (1) → type description → tap amount (1) → type → ✓ (1) = **3**.
Unequal split: +3 (split button, tab, ✓).

### 3.6 Expense with one friend (non-group)

- **Entry:** the friend's page → Add expense. "With you and: asha", and the bottom chip says "Choose group" (no
  group).
- **Split button:** shows the whole sentence "Paid by you and split equally." Tapping it opens "How was this
  expense split?" with four answers, each with its live effect:
  1. **You paid, split equally:** "asha owes you ₹150"
  2. **You are owed the full amount:** "asha owes you ₹300"
  3. **asha paid, split equally**
  4. **asha is owed the full amount**
  5. **More options:** the full paid-by and split screens
- **Several friends without a group:** type more names into "With you and". The expense is split across those
  friendships.
- **Taps:** Add expense (1) → description → amount (1) → split (1) → preset (1) → ✓ (1) = **5**. Keeping the
  default is **3**.

### 3.7 Expense page, comments, edit, delete, restore

**Expense page:**
- **Top bar:** add photo, delete, edit.
- **Hero:** category icon, description, big amount, "Added by you on Nov 27, 2026".
- **Payer and splits:** the payer's avatar with "You paid ₹600.00", then a tree of "You owe ₹200 / Rahul owes
  ₹200 / asha owes ₹200".
- **"Spending trends for [group] :: [category]":** three monthly bars, plus a Pro button "View more charts".
- **Comments:** the note is shown first, then comments as chat bubbles ("You · Just now"). The composer is
  pinned at the bottom.

**Edit:** opens the same one-screen form, titled "Edit expense".

**Delete:** a confirm dialog warns it removes the expense for everyone (2 taps).

**Restore:**
- Activity shows "You deleted …". Tapping it opens the expense with **Restore** in the top bar, plus "Updated by
  / Deleted by" lines.
- There is no field-by-field edit history.

**Payment page:** "Rahul paid you", the amount, "Added by…", a note that no money moved, delete and edit, and
comments.

### 3.8 Settle up and record a payment

- **From the group's Settle up chip:**
  1. A list titled "Select a balance to settle". Each row shows the person, "you are owed" and the amount.
  2. **More options** leads to: select payer → select recipient → amount.
  3. A **Pro "Convert to USD"** button.
- **From a Balances row:** Settle up opens Record a payment at once.
- **Record a payment (one screen):**
  - payer avatar → arrow → receiver avatar, with "Rahul paid you"
  - a big amount **filled in with the full balance**, with a pencil icon
  - a note: "You are recording a payment that happened outside Splitwise. No money will be moved."
  - one green **Record a payment** button
- **Partial payment:** tap the amount (1). The strip with group, date, photo and notes appears, and the button
  becomes Next. Type the amount, then Next (1) → Record (1).
- **Payment method:** none. In the India build there is no UPI, cash or bank choice and no in-app paying.
- **From a friend's page:** "Select a balance to settle with asha".
  - The first row is **"Settle all balances · ₹455"**. Below it, "Or settle a specific group balance" lists each
    group and Non-group expenses.
  - Settle all makes one payment. Splitwise then adds an automatic "fully settled up in all groups" record that
    clears the group balances. Its page explains which group balances it cleared.
  - Deleting that record puts the group balances back and keeps the payment (we saw this when cleaning up).
- **After settling:** the friend page says "You are all settled up" with "Tap to show settled expenses".
  Activity adds "You are fully settled up with asha".
- **Taps:** with one balance from a Balances row, **2** (Settle up, Record). From the group chip, **3**. With a
  friend across groups, **3** (friend page Settle up → Settle all → Record).

### 3.9 Balances, Totals, Charts, Whiteboard, Export (group chips)

- **Balances:**
  - Members, each expandable: "Unizoy gets back ₹400 in total", then "Rahul owes ₹200 to Unizoy" with
    **Remind…** and **Settle up** buttons.
  - Footer: "Simplify debts is turned off in this group" with "Turn on simplify debts".
- **Totals:**
  - A donut of the group total against your share.
  - "Total spent ₹600", "Your share ₹200 · 33% of total group spending".
  - At the bottom, an **All time** button and a **month picker with ‹ ›**.
  - A Pro promo card.
- **Charts:** Pro paywall.
- **Whiteboard:** one free-text page per group with Save. The help text says it is for things like the
  landlord's address or emergency contacts, and that anyone who joins the group can see it. **Free.**
- **Export:** the Android share sheet with `export.csv`. One tap, free.

### 3.10 Group settings

- **Group row:** name and type, with Edit (the same form as create, titled "Customize group").
- **Trip Pass card (PRO):** "Upgrade everyone in your group to Pro for 30 days".
- **Group members:**
  - Add people to group
  - Invite via link
  - member rows with email and their balance in the group ("gets back ₹400", "owes ₹200")
  - tapping a member opens a sheet: View settings (friendship), Invite to group, Remove from group
- **Advanced settings:**
  - **Simplify group debts** switch: **off** for this new trip group. Help text, plus a "Learn more" page with
    a three-person worked example.
  - **Default split (PRO):** "Paid by you and split equally". It is **personal**, not for the whole group.
- **Leave group:** greyed out with the reason (outstanding balances).
- **Delete group:** a confirm dialog warns it deletes the group for everyone.

### 3.11 Friends

- **Friend page:**
  - Cover, avatar and name.
  - "Invite asha to Splitwise" when they have no account.
  - Balance sentence: "asha owes you ₹200 in 'Splitify research'". It becomes "You are owed ₹350 overall" with
    one line per group once there is more than one.
  - Chips: Settle up, Remind…, Charts (Pro), Convert (Pro).
  - Rows: shared-group summary rows ("Splitify research · Shared group · you lent ₹200") and non-group
    expenses.
  - Floating Add expense.
- **Friend settings (gear):**
  - Invite to Splitwise.
  - Shared groups.
  - **Remove from friends list:** this deletes the non-group expenses you two share. The confirm text says they
    get no email or push.
  - **Block user:** hides shared groups and stops future notifications from them.
  - **Report user.**

### 3.12 Reminders

- **Remind…** (Balances rows and the friend page) opens a sheet, "How do you want to remind Rahul?":
  - **Send via Splitwise:** "Unavailable for this recipient" for a person without an account.
  - **More share options:** the Android share sheet with ready-made text.
- **Automatic reminders:**
  - Trip groups with dates get them (free).
  - Home groups with "settle up reminders" get them (Pro).
  - Recurring expenses have an "expense is due" email.

### 3.13 Search and charts

Both are Pro. Every search icon (Groups, Friends, Activity, Account) and every Charts chip opens the paywall.
The only free chart is the three-month bar strip on an expense's page.

### 3.14 Currencies

- Any expense can use any currency. The picker remembers recent ones.
- Balances are kept per currency.
- Converting a group or friendship to your default currency is **Pro** ("Convert to USD" chip, and a button in
  settle up). It uses the rate at the moment you tap and is hard to undo (help centre).

### 3.15 Notifications

- **Push:** asked at onboarding. Settings open Android's own notification page for the app.
- **Email settings:** checkboxes for:
  - added to a group
  - added as a friend
  - expense added
  - expense edited or deleted
  - comment
  - **expense due** (recurring)
  - someone paid me
  - **monthly summary of my activity**
  - Splitwise news

### 3.16 Account settings

- **Edit** (a web page):
  - full name, email, phone, password
  - **time zone**
  - **default currency**
  - **language for emails**
  - privacy: whether Splitwise may suggest you to people who have your contact
  - block list, log out on all devices, close account
- **There is no UPI or payment handle.**
- **Security:** "Authenticate with biometrics" switch plus a timeout (default 2 minutes).
- **Appearance:** Light / Dark / System default.

---

## 4. Tap counts: Splitwise (free, as seen) and Splitify (code on `feat/minimal-groups`)

| Flow | Splitwise | Splitify today | Who is lighter |
| --- | --- | --- | --- |
| Create a group with 2 people | ~14 taps; email/phone typed for each person; trip-date dialog | 1 screen: name, people field + Done per person, Create (~3 taps) | **Splitify** |
| Add a friend | 4 taps + email or phone | Add friend → name → Add (2) | **Splitify** |
| Add an expense from the group page, equal split | 3 | 3 (Add expense, Next, Save) | equal |
| Add an expense from Home | 4 (Add expense, pick target, amount, ✓) | 3 with one open group; 4 with a suggestion chip; **5–6 through the picker sheet** (focus is lost) | Splitwise when the picker is used |
| Two people, "they owe the full amount" | 2 extra (split button, preset) | Open the pill → exact → type both → done (~4), or the separate Record-a-loan screen | **Splitwise** |
| Several friends, no group | type the names into "With you and" | not possible (one target only) | **Splitwise** |
| Unequal split | 3 | 3 | equal |
| Settle the only balance | 2 (from a Balances row) or 3 (chip) | 2 (Settle up → Record) | equal |
| Settle with a friend across 2 groups | 3, one payment | 3 per group (6) | **Splitwise** |
| Partial payment | 3 | 2 (tap amount, Record) | **Splitify** |
| See who owes whom in a group | 0 (shown on the group page) | 1 (Balances tab) | **Splitwise** |
| Remind someone without the app | 2 (share text) | not possible (button hidden) | **Splitwise** |
| Delete an expense | 2 (confirm) | 1 (Undo snackbar) | **Splitify** |
| Restore a deleted expense | 2 (Activity row → Restore) | 3–4 (group → settings → Deleted items → Restore) | **Splitwise** |
| Invite to a group | 3 (link only) | 1–2 (QR + code + link sheet) | **Splitify** |
| Repeat an expense | 3 (date → Repeat → option) | 2 (Repeat chip → option) | **Splitify** |
| Export CSV | 1 (chip) | 2 (settings or Totals → Export) | Splitwise by 1 |
| Search / Charts / Convert / Default split | paywall | 1 tap, free | **Splitify** |
| 5th expense of the day | blocked until tomorrow | no limit | **Splitify** |

---

## 5. Splitwise Pro: every paid feature, and how it works

The same eight Pro items appear on every paywall in the app: Receipt scanning, Unlimited expenses, 30-day Trip
Pass (yearly plans only), Currency conversion, Itemization, Charts and graphs, Expense search, Save default
splits. The home-group reminder switch adds a ninth label, "Custom group reminders". The web adds the rest.

| Pro feature | How it works for the user | Where the free app gates it | Splitify today |
| --- | --- | --- | --- |
| Unlimited expenses | Lifts the 4-a-day cap and the 10-second countdown screen | Add expense (3rd add onwards) | No limit (have) |
| No ads | No ads or upsell screens | Everywhere | None (have) |
| Receipt scanning | Photograph a receipt; the expense is created with the total and detected lines. Only Pro users can scan; everyone sees the result | Camera → "Scan Receipt" | Photo attach only (**gap**) |
| Itemization | Give each receipt line to people; tax and tip are shared in proportion | Paywall list | No (**gap**) |
| Charts and graphs | Spending by category over time for a group, a friend or you | Charts chips, "View more charts" | Insights: category donut + 12-month bars (have; trends are thinner) |
| Expense search | Search the whole history | All search icons | Search with filters, offline (have; payments and comments not searched) |
| Currency conversion | One tap converts every expense in a group or friendship to the default currency at the live rate | "Convert to USD" chips, settle up | Rate saved per record; "In INR" view; "Convert all at their dates' rates" (have, safer) |
| Save default splits | Your personal default payer + split for a group | Group settings → Default split | Group-wide equal/%/shares default (have; no default payer) |
| Custom group reminders | Regular settle-up reminders for a group | Home group → settle-up reminders | None (**gap**) |
| 30-day Trip Pass | A yearly subscriber gives one trip group Pro for 30 days | Group settings card | Not needed (everything is free) |
| Transaction import | Link a card and split recent purchases (US / select countries) | Not shown in the India build | Not applicable; India substitute in the gap plan |
| 10 GB high-resolution receipt storage | Bigger, sharper receipts | — (web) | 1 photo, compressed to ≤ 500 KB (**gap**, storage cost) |
| JSON backup | Download a full backup from the website | — (web) | CSV per group only (**gap**) |
| Early access | New features first, plus a feedback channel | — | Not applicable (open source) |

**Free in Splitwise that people often think is Pro:** simplify debts, recurring expenses, comments, CSV export,
Whiteboard, trip dates, biometrics lock, dark mode, "Settle all balances", personal QR code.

---

## 6. Patterns worth adopting (feed the gap plan, file 11)

1. Two-person split answers (four presets), which also cover loans.
2. "Settle everything with this person" in one payment across groups.
3. Who-owes-whom lines on the group page itself (collapsible), so no tab switch is needed.
4. Settled history collapsed behind one row.
5. Restore on the deleted item's own page, reached from Activity.
6. Group-list filter: outstanding / I owe / owe me.
7. A personal friend code (QR + link) with Scan and My code.
8. Trip dates on trip groups, and settle-up reminders on any group.
9. A one-page whiteboard per group.
10. A share-sheet reminder for people who don't have the app.
11. Receipt scan → prefill, then itemize.
12. Group-type-aware options on the same group form.
13. The note shown as the first comment (one section, not two).

## 7. Things we deliberately do not copy

- The countdown and Pro screens, the daily cap, Pro badges and promo cards.
- Email or phone being required for each person (our name-only members are better for India).
- The trip-date dialog that appears on save.
- Confirm dialogs for delete (we use Undo).
- A personal default currency instead of a group currency (it defaulted to USD for an Indian user).
- The first-expense "split with 3 people?" dialog.
- Email notifications (PLAN: push and the in-app bell only).
- Splitwise's colours, illustrations, icons and copy.

## 8. Not verified in this session

- **Blocked by the daily cap:** the Add expense form opened from Home with an empty "With you and".
- **Pro only, so not seen working:**
  - receipt scanning
  - itemization
  - charts
  - search
  - currency conversion (descriptions come from the web sources below)
- **Expected but not opened:** the edit-expense form (same layout as add).
- **Not received:** push notifications (we declined the permission), and the effects of email settings.
- **Not toggled:** dark mode.
- **Not found:** Splitwise Pay / Card or other US-only items. The India build had no entry for them.
- **Not found:** home-screen widgets.

## Sources (web, for Pro and limits)

- Splitwise Pro page: https://www.splitwise.com/pro
- What is Splitwise Pro (plans, Trip Pass, 4 a day): https://kb.splitwise.com/pro/what-is-splitwise-pro
- Expense limit article: https://feedback.splitwise.com/knowledgebase/articles/2010350-why-am-i-seeing-an-expense-limit
- Multiple currencies and conversion: https://kb.splitwise.com/balances-and-expenses/how-can-i-manage-a-friendship-or-group-with-multiple-currencies
- Exchange rates for conversion: https://kb.splitwise.com/pro/how-are-exchange-rates-calculated-for-currency-conversion
- Recurring expenses: https://kb.splitwise.com/balances-and-expenses/how-can-i-manage-recurring-expenses
- Simplify debts: https://kb.splitwise.com/balances-and-expenses/what-is-simplify-debts
- Attachment limits (2 MB per upload): https://feedback.splitwise.com/knowledgebase/articles/436745
- App Store listing (10 GB receipts, JSON backups): https://apps.apple.com/us/app/splitwise/id458023433
- Review with US prices and the Trip Pass: https://www.moneycrashers.com/splitwise-review/
- UPI charge during the free trial (India): https://kb.splitwise.com/pro/why-was-i-charged-via-upi-during-my-free-trial
