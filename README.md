# Splitify Free Forever

A free and open-source app for splitting expenses with friends, roommates and groups.
Track shared costs, see who owes whom, and settle up. No ads, no paywalls, free forever.

> **Status:** early development. The app skeleton runs; features arrive phase by phase.

## Tech stack

- [Flutter](https://flutter.dev) (Dart)
- Targets: Android (iOS later)

## Development setup

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


## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening an issue or pull request,
and follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## Security

Please do not report security issues in public. See [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE) © Unizoy
