# Privacy policy

Last updated: 22 November 2026

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
| Group cover images | `group-covers` bucket (server); phone | To show a cover on a group | With the group |
| Activity log | `activity` table (server) | To show who did what and when; also the source of notifications | Kept; never deleted |
| Edit history | `record_versions` table (server) | To show earlier versions and restore them | Kept; never deleted |
| Recurring bill templates | `recurring_templates` table (server) | To create repeating expenses | Until a group member deletes them |
| Notifications and notification settings | `notifications`, `notification_settings` tables (server) | To show the in-app bell and respect your push settings | Until you delete your account |
| Device push tokens (Firebase Cloud Messaging) | `device_tokens` table (server) | To send push notifications to your phone | Removed when you sign out of that device, and when you delete your account |
| Exchange rates | `fx_rates` table (server) | To convert currencies. No personal data. The server fetches them from Frankfurter | Kept |
| Sync de-duplication | `mutation_log` table (server) | So a change that is sent twice is applied once | Kept until the backend owner prunes it (suggested: 30 days) |
| Join rate limit | `join_attempts` table (server) | To slow down guessing of invite codes | 1 day |
| Local database: a copy of your groups, and an outbox of changes not yet sent | Your phone | To work offline | Wiped when you sign out |
| App lock setting | Your phone | To lock the app with biometrics or the device PIN | Until you change it or clear app data |
| Home-screen widget data: a balance summary | Your phone, in the app's private storage | To draw the widget | Until you hide it, sign out or clear app data |
| Payment bubble captures (only if you turn it on): amount, payee, UPI reference, app, time | Your phone only | To offer "Add to Splitify" after a payment | 7 days, or until you add or dismiss it; wiped on sign-out |
| One-time email codes | Sent through the project's SMTP provider | To sign you in by email | Not kept by the app; the mail provider keeps its own delivery logs |
| Hosting and API logs | Supabase | To run and secure the service | Set by Supabase |

## What we never do

- No ads.
- No analytics or tracking libraries.
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
- **Frankfurter**: exchange rates. Only the server calls it, so it never sees your device or data.
- **Email (SMTP) provider**: delivers one-time sign-in codes to your address.

## Payment bubble (optional, off by default)

The payment bubble is an optional Android feature. It is off until you turn it on in Account, Payment bubble.

- It reads payment alerts to offer "Add to Splitify". You choose the sources: payment notifications, and an
  optional advanced screen capture.
- It works on your device only. Nothing is sent to a server until you tap Add and save the expense.
- It reads only apps on a fixed allow-list of payment, bank and SMS apps, and you can switch apps off one by one.
  Apps that do much more than payments (WhatsApp, the Amazon shopping app) start switched off.
- It keeps only the parsed fields (amount, payee, UPI reference, app, time) in the phone's local database. It
  does not store the raw notification text or screen text.
- It never reads PIN or password fields, and never reads the UPI PIN pad.
- Captures are removed after 7 days, or as soon as you add or dismiss them.
- Signing out switches it off and forgets every waiting capture and the group names used for its shortcuts.
- To turn it off, switch off Payment bubble in Account. You can also revoke notification access, "display over
  other apps" and accessibility access in Android settings.

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
