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
- [phase 02] Impeller (GLES) on the emulator: ~30–40k `drawRawPoints` per frame (cover grain) stalled the raster thread → black screen in debug, stuck splash in release, no errors in logcat → paint grain from a cached tile (`Picture.toImageSync` + repeating `ImageShader`), never thousands of primitives per frame (S-009). Bisect such hangs with a `--dart-define` kill switch + release build.
- [phase 02] A debug APK started by `adb am start` / `flutter run --no-resident` / after the tool disconnects renders black or freezes here → for screenshots use a release x64 build (`flutter build apk --release --target-platform android-x64`), see `ui-review` skill scripts.
- [phase 02] `flutter run` in a background shell exits on stdin EOF ("Lost connection") → don't rely on resident runs from tool shells.
- [phase 02] `phosphor_flutter` 2.1.0 fails to compile on Flutter 3.50 (`IconData` is final, `@RecordUse`); the analyzer does NOT catch it (package code), only `flutter build` → vendor the Phosphor TTFs and declare `const IconData` (S-008).
- [phase 02] `flutter_native_splash:create` rewrites `values*/styles.xml` with platform (non-AppCompat) parents in `-v31` and `windowDrawsSystemBarBackgrounds=false` → re-apply AppCompat parents and drop those lines after regenerating (S-011).
- [phase 02] `flutter_launcher_icons` needs PNG input → render PNGs from the painter: `flutter test tool/brand/render_brand_test.dart`, then `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`.
- [phase 02] Release build failed once with `GeneratedPluginRegistrant ... package dev.flutter.plugins.integration_test does not exist` while a sub-agent ran `flutter test` in parallel → retry; avoid parallel flutter commands in one checkout.
- [phase 02] Writing regexes with `\b` through `python - <<'EOF'` inside a Python non-raw string produced literal backspace bytes in `tool/guards.dart` → edit Dart regexes with the Write/Edit tools, check with `grep -c $'\x08'`.
- [phase 02] The guard hook blocks `git clean -d/-x`; to set files aside use `mv` into the scratchpad.
- [phase 02] alchemist: `CoverCache.warm` completes on the real event loop → golden tests clear the cache in `setUp` and pump inside `runAsync`; repeating animations (DotsPulse, sheen, spin, loader) need fixed pumps, never `pumpAndSettle`.
- [phase 02] `OverflowBoxFit` is not exported by `material.dart` → `import 'package:flutter/rendering.dart' show OverflowBoxFit;`.
- [phase 02] UI review tool: `.claude/skills/ui-review/scripts/capture_shell.ps1` (tap by accessibility label via uiautomator; light/dark/200 % passes).
- [phase 03] Coverage: a constructor only ever called as `const` shows as an uncovered line in lcov → add one runtime (non-const) call in a test.
- [phase 03] Two agents in one checkout on disjoint files worked (money core vs currencies/formatter); I wrote the shared contract (`currency.dart`, `Currencies.exponentOf/of`) first so neither blocked the other. Run only targeted `flutter test <file>` in parallel agents.
- [phase 03] Python oracle runs leave `planning/reference/__pycache__/` — delete it, never commit it.
- [phase 03] For Postgres cross rates, default `numeric` division keeps ~16 significant digits and can double-round → use explicit high scale or integer math (see S-016).
- [phase 04] Deno 2.9.8 installed per-user at `%USERPROFILE%\.deno\bin` (dev-env §4 steps worked as written).
- [phase 04] Supabase CLI v2 rejects an `[inbucket]` section in `supabase/config.toml` and the `inbucket` name in `supabase start -x` → leave both out.
- [phase 04] Postgres regex repeat counts stop at 255 (`{0,255}` errors) → split the quantifier (e.g. `{2}{0,254}`).
- [phase 04] Without the Supabase MCP, migrations + pgTAP can still be proven in GitHub Actions (`supabase start` on the runner, `supabase test db`); dev-project steps stay blocked.
- [phase 03/04] Two phases in parallel: `git worktree add ../splitify-p04 -b phase/04-… phase/03-…`, one agent per worktree, then merge the earlier phase branch into the later one (conflicts only in 00-decisions / 10-test-catalog — keep both sides).
- [phase 06] Drift: a typed `db.into(table)` on a `TableInfo<Table, Object?>` fails at runtime (`RawValuesInsertable<Object?>` is not `Insertable<LocalGroup>`) → generic writes use `customInsert`/`customUpdate` with `updates: {table}` so `watch()` streams still fire (`customStatement` does NOT notify streams).
- [phase 06] Drift tables declared in a `.drift` file avoid uncovered getter lines in coverage; FTS5 needs `sql: {dialect: sqlite, options: {modules: [fts5]}}` in build.yaml; `package:sqlite3` 3.x bundles SQLite (with FTS5), so `NativeDatabase.memory()` works in `flutter test` on Windows.
- [phase 06] `drift_dev schema generate` output trips `strict_raw_type` → exclude `test/data/local/generated/**` in analysis_options. `drift/drift.dart` clashes with matcher's `isNull`/`isNotNull` in tests.
- [phase 06] `dart run build_runner build` rewrote unrelated riverpod `*.g.dart` files (generator drift) → `git checkout` them unless the source changed.
- [phase 06] Dart records compare collection fields by identity: `expect((map, list), ({..}, [..]))` fails even when equal → assert collections separately.
- [phase 05] Riverpod 3 pauses providers nobody listens to: `container.read(streamProvider.future)` can hang → `container.listen(...)` first in tests.
- [phase 05] `flutter_test` answers every HTTP request with 400, so a real `SupabaseClient('https://x.example', 'k')` is enough to cover thin PostgREST/Storage glue (calls fail fast).
- [phase 05] PowerShell `Get-Content -Raw | Set-Content` re-encodes UTF-8 files (mojibake / `?` for `→`, BOM) → edit Dart files with Python (`io.open(..., encoding='utf-8')`) or the Edit tool.
- [phase 05] Golden tests need a valid image for `MemoryImage` (use a base64 1×1 PNG), fake bytes throw "Invalid image data".
- [prep 16] Postgres `date + make_interval(months => n)` clamps to month end (2024-01-31 + 1 month = 2024-02-29), so the T2 SQL generator matches `recurrence.dart` if it always adds n months/years to the anchor, never to the last `next_date`.
- [prep 11] Dart `Uri.queryParameters` decodes `+` as a space and `Uri.encodeComponent` leaves `!*'()` alone, so the UPI builder has its own encoder (`+` -> `%2B`, space -> `%20`).
- [phase 07] MCP `execute_sql` returns only the last row-returning statement → run pgTAP as `create temp table tap(t text)`, `insert into tap select is(...)`, `insert into tap select f from finish() f`, then one `select string_agg(...)`; pgTAP here has no `__tresults__`. A `lateral (select volatile_fn(const))` runs once → tie the argument to the row.
- [04 dev apply] The guard hook's `truncate` regex also matches privilege lists (`revoke … truncate, references …`) in migrations → write `revoke all … ; grant select …` instead.
- [04 dev apply] MCP `execute_sql` returns only the last result set → for pgTAP add `select num_failed(), _get('curr_test'), _get('plan');` before `rollback`; strip leading `--` comments so the SQL starts with `begin` (guard treats only that as a test).
- [04 dev apply] Other worktrees share the dev DB: phase 07 applied `0010_groups_members` while 0001–0009 were going in — always check `list_migrations` before applying.
