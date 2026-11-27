# Splitify backup format ("Download my data")

**Where:** Account → Your data → **Download my data** (or **Share instead**).

The app builds the file on your phone from what the phone holds, so it works offline. Changes that have
not reached the server yet are in the file too, marked `"pending": true`.

## The file

A `.zip` named `splitify-backup-YYYY-MM-DD.zip` (your phone's date). It holds:

| Path | What it is |
| --- | --- |
| `splitify-backup.json` | Everything, in the format below. |
| `README.txt` | A short note on what is inside. |
| `csv/<group>.csv` | One spreadsheet per group that has expenses or payments. This is the same file as **Export CSV** on the group's Totals tab. |

**CSV file names:**
- The group name in lower-case letters and digits, joined with `-`, at most 40 characters.
- A name with no such characters becomes `group`.
- When two groups end up with the same name, the second gets `-2`, the third `-3`, and so on.

Deleted groups are in the JSON but get no CSV.

## `splitify-backup.json`

UTF-8 JSON, indented with two spaces.

```json
{
  "format": "splitify-backup",
  "version": 1,
  "exported_at": "2026-11-27T15:30:00.000Z",
  "app_version": "0.2.0",
  "me": { "user_id": "…", "name": "Mohit", "upi_id": "mohit@okaxis", "default_currency": "INR" },
  "groups": [ { "group": {…}, "me_member_id": "…", "members": [], "expenses": [], "payments": [],
                "comments": [], "recurring": [] } ]
}
```

**Top-level fields:**
- `format`: always `"splitify-backup"`.
- `version`: `1`. A change that could break a reader raises it. New fields can appear without a raise, so a
  reader should ignore fields it does not know.
- `exported_at`: when the file was made (UTC, ISO 8601).
- `me`: your account as the phone knows it. `name`, `upi_id` and `default_currency` are `null` when your
  profile is not on the phone.

### Money

Rule 1 of the app holds here too:
- **Amounts are integers in the currency's minor unit**, always next to their currency code: paise for
  `INR`, cents for `USD`, whole yen for `JPY` (no minor unit). `240000` with `"currency": "INR"` is ₹2,400.00.
- **Amounts are never decimals.** Nothing in the file was rounded on the way out.
- **Exchange rates are decimal strings** (`"90.5"`), exactly as they were saved with the record.
- **Converted amounts** are integers in the converted currency.

### Common fields

Every row (group, member, expense, payment, comment, repeating expense) has:

| Field | Meaning |
| --- | --- |
| `id` | The record's UUID. Other rows point to it. |
| `created_at`, `updated_at` | ISO 8601 times from the server. `null` when the phone made the row and has not synced it. |
| `created_by` | The account (user id) that added it, where known. |
| `deleted_at` | Set when the row was deleted. Deleted rows are kept, because nothing in Splitify is lost. |
| `pending` | `true` while the row has changes the server has not confirmed. |

### `group`

`id`, `name`, `type` (`trip` · `home` · `couple` · `other` · `direct` for a friend), `main_currency`,
`simplify_debts` (true/false), `default_split` (an object, or `null`), `archived_at`, plus the common fields.

Also, since D-034 (still version 1; readers ignore keys they do not know):

- `trip_starts_on`, `trip_ends_on`: the trip's first and last day as `YYYY-MM-DD`, or `null` (no end date = no end).
- `settle_reminder`: `off`, `weekly` (on the weekday the group was created) or `monthly` (on the 1st).
- `whiteboard`: the group notes (free text, at most 5,000 characters), or `null`.

`me_member_id` is your member id in this group (`null` if you are not an active member).

### `members[]`

In the app's fixed order (position, then id), removed members too.

`id`, `name`, `user_id` (`null` for a name-only member), `position`, `role` (`owner` · `member`), `status`
(`active` · `left` · `removed`), `claimed_at`, `created_at`, `deleted_at`, `pending`.

### `expenses[]`

Oldest first (date, then when added). Loans are here too, with `"kind": "iou"`.

| Field | Meaning |
| --- | --- |
| `kind` | `expense` or `iou` (a loan). |
| `description`, `notes`, `category` | `category` is a key such as `food.dining_out`. |
| `date` | The expense date, `YYYY-MM-DD`. |
| `currency`, `total` | ISO 4217 code and the total in minor units. |
| `paid_by` | `{member id: minor units}`: who paid what. The values add up to `total`. |
| `owed` | `{member id: minor units}`: each person's share. The values add up to `total`. |
| `split_kind`, `split_values` | How it was split (`equal`, `exact`, `percent`, `shares`, `adjust`) and the typed values (an object, or `null`). |
| `fx` | `null`, or a saved conversion: `currency`, `rate` (string), `rate_date`, `source`, `total`, `paid_by`, `owed` (minor units of `fx.currency`). |
| `receipt_path` | Where the receipt photo is stored on the server, or `null`. The photo itself is not in the zip. |
| `recurring_id`, `source` | The repeating expense that made it, and `app` · `recurring` · `import`. |
| `updated_by`, `deleted_by` | Who last changed it, and who deleted it. |

### `payments[]`

Oldest first.

`from_member` paid `to_member` the `amount` (minor units) in `currency` on `date`. `method` is `cash` ·
`upi` · `bank` · `other`. Also `note`, `fx` (`null`, or `currency`, `rate`, `rate_date`, `source`,
`amount`), `deleted_by` and the common fields.

### `comments[]`

Oldest first.

`target_type` (`expense` · `payment`), `target_id`, `body`, `created_by` and the common fields.

### `recurring[]`

Repeating expenses.

`expense_id`, `interval` (`weekly` · `fortnightly` · `monthly` · `yearly`), `anchor_date`, `next_date`, `ends_on`, `active`,
`template` (the expense it copies, as an object) and the common fields.

## Working out balances from the file

For each group and **each currency separately** (never add currencies together), take the rows where
`deleted_at` is `null`:

1. For every expense (loans too), each member's net goes up by what they paid (`paid_by`) and down by
   their share (`owed`).
2. For every payment, the net of `from_member` goes up by `amount`, and the net of `to_member` goes down
   by `amount`.

**Result:** a positive net means the group owes that person, and a negative net means they owe the group.
The nets of a currency add up to 0. They are the same numbers the app shows, before simplify debts
(simplify changes who pays whom, never how much anyone owes overall).
