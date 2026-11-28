# Privacy policy

Last updated: 26 November 2026

Splitify Free Forever is a free, open-source expense-splitting app. This page says what data the app and its
backend handle, why, and what you can do about it. It is written to be short and plain.

## Who runs it

The project is run by Unizoy and is open source (MIT). The code, including the whole backend, is in
[this repository](https://github.com/Unizoy/splitify-free-forever).

If you use a release published by this project, your data is held in the backend run by Unizoy. If someone
**self-hosts** their own backend (see [supabase/README.md](../supabase/README.md)), that person runs their own copy
and is responsible for the data in it. This policy describes what the software does; a self-hoster's own rules and
contact apply to their copy.

## What we store and why

| Data | Where | Why | Retention |
| --- | --- | --- | --- |
| Account: email, and the Google account id and name if you sign in with Google | Supabase Auth (server) | To sign you in | Until you delete your account |
| Profile: display name, avatar photo, UPI ID, default currency | `profiles` table, `avatars` bucket (server); phone | To show your name to group members and fill in UPI payment links | Until you delete your account (cleared on deletion) |
| Groups, members, expenses, payments, comments | `groups`, `group_members`, `expenses`, `payments`, `comments` tables (server); phone | The core of the app: splitting and settling | Until deleted by a group member; deleted items are kept (soft delete) so they can be restored |
| Receipt photos | `receipts` bucket (server); phone until uploaded | To attach a receipt to an expense | With the expense |
| Expense attachments: photos and PDFs | `expense_attachments` table and the private `expense-files` bucket (server): only members of the group can open them, and only files the app registered for an expense can be uploaded; phone (thumbnails, PDFs, photos you opened) | To keep bills, tickets and invoices with an expense, in full resolution | With the expense. Removing one is a soft delete that can be undone, so the file stays |
| Group cover images | `group-covers` bucket (server); phone | To show a cover on a group | With the group |
| Activity log | `activity` table (server) | To show who did what and when; also the source of notifications | Kept; never deleted |
| Edit history | `record_versions` table (server) | To show earlier versions and restore them | Kept; never deleted |
| Recurring bill templates | `recurring_templates` table (server) | To create repeating expenses | Until a group member deletes them |
| Notifications and notification settings | `notifications`, `notification_settings` tables (server) | To show the in-app bell and respect your push settings. The monthly summary push is off unless you turn it on | Until you delete your account |
| Crash reports, if you leave them on (see "Crash reports") | Firebase Crashlytics (Google) | To find and fix crashes | 90 days (Crashlytics) |
| Device push tokens (Firebase Cloud Messaging) | `device_tokens` table (server) | To send push notifications to your phone | Removed when you sign out of that device, and when you delete your account |
| Exchange rates | `fx_rates` table (server) | To convert currencies. No personal data. The server fetches them from Frankfurter | Kept |
| Sync de-duplication | `mutation_log` table (server) | So a change that is sent twice is applied once | Kept until the backend owner prunes it (suggested: 30 days) |
| Join rate limit | `join_attempts` table (server) | To slow down guessing of invite codes | 1 day |
| Local database: a copy of your groups, and an outbox of changes not yet sent | Your phone | To work offline | Wiped when you sign out |
| App lock setting | Your phone | To lock the app with biometrics or the device PIN | Until you change it or clear app data |
| Home-screen widget data: a balance summary | Your phone, in the app's private storage | To draw the widget | Until you hide it, sign out or clear app data |
| One-time email codes | Sent through the project's SMTP provider | To sign you in by email | Not kept by the app; the mail provider keeps its own delivery logs |
| Hosting and API logs | Supabase | To run and secure the service | Set by Supabase |

## What we never do

- No ads.
- No analytics or tracking libraries. Crash reports are the only diagnostics, they hold no personal data, and you
  can switch them off.
- We do not sell your data.
- We do not upload your contacts.
- The app never makes a payment. A "Pay via UPI" button opens your own UPI app. A payment is recorded only when
  you tap "Mark as paid".

## Who can see what

Only members of a group can see that group's data. Row Level Security is on for every table, so the database
itself refuses reads and writes outside your groups. The app holds only the project's publishable key, never a
secret key.

## Deleted items

Deleting an expense, payment, comment or group is a soft delete. Group members can restore it. Nothing is lost by
accident, and every change is in the activity log and the edit history.

## Deleting your account

In the app, use Account, then Delete account. The `delete-account` function then:

1. clears your profile and removes your UPI ID;
2. turns your memberships into name-only members, so other people's balances and history stay correct;
3. removes your avatar photos;
4. deletes your device push tokens;
5. deletes your sign-in account.

Content you added to groups (expenses, comments, receipts) stays in those groups, because other people's balances
depend on it. To have it removed, ask your groups to delete it, or open an issue on GitHub.

## Third parties

- **Supabase**: hosts the database, sign-in, file storage and server functions, as our processor.
- **Google Sign-In**: only if you choose "Continue with Google".
- **Firebase Cloud Messaging**: delivers push notifications. It receives a device token and the notification text.
- **Firebase Crashlytics**: receives crash reports while "Send crash reports" is on (see below).
- **Frankfurter**: exchange rates. Only the server calls it, so it never sees your device or data.
- **Email (SMTP) provider**: delivers one-time sign-in codes to your address.

## Crash reports

When the app hits an error it did not expect, it can send a crash report through Firebase Crashlytics, so the
crash can be found and fixed.

- **What a report holds:** the type of the error (for example `StateError`) and the stack trace of the app's own
  code (file, line and method), plus what Crashlytics adds itself: the phone model, the Android version, the app
  version, free memory and disk, and a random installation id.
- **What it never holds:** your name, email, UPI ID, group names, amounts, descriptions, notes, comments, photos,
  or the error's message text (a message can quote what you typed, so it stays on your phone). The app sets no
  user id and no custom keys.
- **Your choice:** Account → Settings → **Send crash reports**. It is on in store builds and off in debug builds;
  nothing is collected before the app has applied your choice. Builds without Firebase (contributors' builds, the
  side-by-side test build) have no crash reporting at all.

## Payment bubble (not in this version)

Earlier test builds (0.1.x) had an optional payment bubble. This version does not have it: the app does not read
notifications, screen content or SMS, and asks for no notification-access, accessibility or "display over other
apps" permission. Payments the bubble had kept on the phone are deleted when the app updates. If the feature comes
back in a later release, this policy will describe it first.

## Security

Connections use TLS. Row Level Security protects every table, and file storage has per-user folder rules and name
checks. The app ships only the publishable key. Secrets such as the Firebase service-account key live only as
server-side function secrets. Report security problems as described in [SECURITY.md](../SECURITY.md).

## Children

Splitify is not for children under 13. Do not use it if you are under 13.

## Contact

Open an issue at <https://github.com/Unizoy/splitify-free-forever/issues>. For security reports, follow
[SECURITY.md](../SECURITY.md) instead of opening a public issue.

## Changes to this policy

The date at the top shows the last update. Every change is visible in the repository history.
