# Splitify Free Forever

Splitify is a free and open-source app for splitting expenses with friends, roommates and groups. It is made for
India first (rupees, UPI) and works with other currencies too. You can track shared costs, see who owes whom and
settle up. It works offline. No ads, no limits, free forever.

## Features

- Groups, with name-only members who can later be claimed by a real account through an invite.
- Five split types and multiple payers.
- IOUs and loans.
- Receipt photos.
- Balances per currency, with an optional simplify-debts view.
- Settle up and Pay via UPI (a payment is recorded only when you tap "Mark as paid").
- Offline-first sync: use it with no network, changes are sent when you are back online.
- Edit history and restore of deleted items.
- Comments on expenses and payments.
- Notifications and payment reminders.
- Currencies with exchange rates saved on each expense.
- Recurring bills.
- Search.
- Charts and CSV export.
- Import from Splitwise.
- App lock (biometric or device PIN).
- Home-screen balance widget.

## Screenshots

| | | |
| --- | --- | --- |
| ![Groups home with your overall balance](docs/screenshots/groups.webp) | ![A group's expense list](docs/screenshots/expenses.webp) | ![Choosing how to split an expense](docs/screenshots/split.webp) |
| ![Who owes whom in a group](docs/screenshots/balances.webp) | ![Spending by category](docs/screenshots/insights.webp) | ![Account and wallet card](docs/screenshots/account.webp) |

## Status

Android first. Release APKs are published on GitHub Releases. There is no Play Store listing yet. iOS may come
later.

## Build from source

Android only for now. You need the [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable, 3.50.x),
Android Studio (SDK + emulator) and JDK 17.

```powershell
. .\tool\env.ps1                                   # Windows: fixes PATH, sets JAVA_HOME
copy secrets\env.example.json secrets\env.dev.json # then fill in your own values (git-ignored)
flutter pub get
flutter run --dart-define-from-file=secrets/env.dev.json
```

Run all checks (format, analyze, guards, tests, coverage, debug APK) with `.\tool\verify.ps1`.
Never commit anything from `secrets/` except `*.example.json`.

## Self-hosting

The whole backend (database schema, security rules, Edge Functions) is in `supabase/`, so you can run your own
copy. See [supabase/README.md](supabase/README.md).

## Privacy

See [docs/PRIVACY.md](docs/PRIVACY.md). In short: no ads, no trackers, no selling data.

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening an issue or pull request,
and follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## Security

Please do not report security issues in public. See [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE) © Unizoy
