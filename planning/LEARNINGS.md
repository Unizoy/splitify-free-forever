# Learnings

Gotchas, working commands and fixes discovered while building. Every session reads this at start and adds to it
at the end of its phase (`capture-learning` skill). When an entry describes a repeatable procedure, turn it into a
skill under `.claude/skills/` and leave a one-line pointer here.

Format: `- [phase NN] <topic>: <what happened> → <what works>`

## Environment (Windows PC)

- [planning] PATH: the machine PATH starts with empty entries (`;;;`), which breaks `flutter.bat` with
  `'WHERE' is not recognized`. Fix per shell: see `CLAUDE.md` (Windows dev environment). Verified 2026-11-21:
  with the fix, `flutter --version` → Flutter 3.50.1 / Dart 3.14.0.
- [planning] Emulator AVD `Pixel_9_API_36` (Android 16, Play Store image) shows as `emulator-5554`.
  Android 37 images crash on this GPU — never create or use them.
- [planning] JDK: Android Studio's JBR at `C:\Program Files\Android\Android Studio\jbr` (`JAVA_HOME`).
  `keytool` lives in its `bin` folder.
- [planning] Not installed on purpose: Docker, WSL, Node, Supabase CLI. Deno is not installed yet — phase 04
  installs it per-user (see that phase).
- [planning] GitHub CLI `gh` is logged in (account owns `Unizoy/splitify-free-forever`).

## Build and tooling

_Add entries here._

## Backend (Supabase)

_Add entries here._

## Testing

_Add entries here._

## UI

_Add entries here._

- [phase 01] flutter create: Flutter 3.50 default pubspec adds `material_ui` and AGP 9 + built-in Kotlin (no kotlin plugin in `app/build.gradle.kts`); we replaced pubspec with the §5 block → `flutter pub get` resolves all packages, first debug build 214 s, later 25-50 s.
- [phase 01] Warnings: plugins `flutter_image_compress_common`, `home_widget`, `patrol`, `workmanager_android` still apply KGP → "will fail in future Flutter" warning, harmless today.
- [phase 01] `dart format .` fails with PathNotFoundException on transient dirs in `build/` (Gradle transforms) → format only `lib test integration_test tool`.
- [phase 01] Bash heredocs with many `'` quotes in one big command failed to parse on this PC → write files with the Write tool; `sed` also turns `\t` in replacement text into a TAB (broke `.\tool\verify.ps1` in CONTRIBUTING).
- [phase 01] Emulator: a debug APK started by `adb shell am start` stays on the Android 12 splash (Flutter icon) and `am start -W` times out → use `flutter run -d emulator-5554 --dart-define-from-file=secrets/env.dev.json` (or `--no-resident`) to see the UI; `flutter test integration_test/... -d emulator-5554` installs, runs and uninstalls the app.
- [phase 01] First `flutter test integration_test` run on a fresh emulator session failed once at "loading" (install/VM service), reruns passed twice → re-run once before debugging.
- [phase 01] Screenshot: `adb shell screencap -p /sdcard/x.png; adb pull /sdcard/x.png <dest>`.
- [phase 01] CI: first run failed in `flutter build apk` (Gradle could not resolve kotlin-gradle-plugin 2.3.20 from plugins.gradle.org); the re-run on the next push passed (green, ~15 min cold) — transient plugin-portal issue.
