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
- [phase 08] Riverpod 3 `AsyncNotifier` already has an `update(...)` method: a controller method named `update` is an invalid override; name it `edit`. Two `clockProvider`s exist (data_providers + auth_providers) -> import auth_providers with `show`.
- [phase 08] PowerShell has no `<<'EOF'` heredoc: pipe a `@' ... '@` here-string into `python -` for UTF-8-safe multi-line edits.
- [phase 07] MCP `execute_sql` returns only the last row-returning statement → run pgTAP as `create temp table tap(t text)`, `insert into tap select is(...)`, `insert into tap select f from finish() f`, then one `select string_agg(...)`; pgTAP here has no `__tresults__`. A `lateral (select volatile_fn(const))` runs once → tie the argument to the row.
- [04 dev apply] The guard hook's `truncate` regex also matches privilege lists (`revoke … truncate, references …`) in migrations → write `revoke all … ; grant select …` instead.
- [04 dev apply] MCP `execute_sql` returns only the last result set → for pgTAP add `select num_failed(), _get('curr_test'), _get('plan');` before `rollback`; strip leading `--` comments so the SQL starts with `begin` (guard treats only that as a test).
- [04 dev apply] Other worktrees share the dev DB: phase 07 applied `0010_groups_members` while 0001–0009 were going in — always check `list_migrations` before applying.
- [phase 08] Instrument Serif has no ₹ glyph (tofu box in real-font goldens; CI goldens obscure text and miss it) → serif money text needs `fontFamilyFallback: const [AppFonts.sans]`.
- [phase 08] Riverpod 3 family overrides are per instance: `provider(arg).overrideWith(() => Notifier(arg))`; the family-level `overrideWith` gets no arg. AsyncNotifier errors are retried by default → `.future` hangs and screens stay loading; pass `retry: (_, _) => null` for local-DB loads.
- [phase 08] `PopScope(canPop: false)` also swallows your own `Navigator.maybePop()` → after a save close with `navigator.pop()` (ignores PopScope), `context.go(...)` when nothing is below.
- [phase 08] `Row[Expanded(name), Flexible(Text(amount, textAlign: end))]` leaves the amount mid-row (a loose Flexible child sits at the start of its share) → put the amount as a plain `Text` after the `Expanded`.
- [phase 08] Signed-in screens cannot be shot from a release build (dev login is debug-only) → debug integration test with sample data printing `UI-CAPTURE <name>` + `.claude/skills/ui-review/scripts/capture_markers.ps1` (prints reach the `flutter test` output, not logcat).
- [phase 08] Two test agents in one worktree: `flutter test` sometimes fails with "failed to delete build\native_assets\…\sqlite3.dll" → rerun after ~10 s.
- [06 leftovers] This PC's ISP answers every plain DNS query for `*.supabase.co` (even to 8.8.8.8/1.1.1.1) with a block-page address (202.83.21.15); Windows resolves correctly (DoH), the emulator does not and Android Private DNS (DoT) does not help → device tests pass `--dart-define=PIN_HOST_IP=<PC answer>` and `integration_test/support/net_pin.dart` connects there with the right TLS name. Symptom: `AuthFailure(offline)` / no edge logs. Real users on such ISPs need a Supabase custom domain or proxy (owner, phase 19/20).
- [06 leftovers] `android/app/src/main/AndroidManifest.xml` had no INTERNET permission (only debug/profile had it) → release APKs could not reach Supabase; added.
- [06 leftovers] Integration tests: the router leaves on the sign-out event while `LocalWipe` is still running → wait for the wipe (prefs empty) before asserting or tearing down, else the DB closes mid-transaction ("database has already been closed").
- [06 leftovers] A harness `SupabaseClient` (second user) needs `authFlowType: AuthFlowType.implicit` for `signUp`, or gotrue asserts "You need to provide asyncStorage to perform pkce flow".
- [06 leftovers] Screens that need a signed-in dev user (release builds have no dev login): integration test prints `UI-CAPTURE <name>` and holds; `.claude/skills/ui-review/scripts/capture_markers.ps1` screenshots light/dark/200 %.
- [06 leftovers] Widget tests opening a sheet that watches a `StreamProvider`: one `pump(600ms)` is not enough (the stream value lands after the frame) → pump in steps; lazy `ListView` items below the fold need `scrollUntilVisible`, not `ensureVisible`. Drift in widget tests: `DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true)` (`testDb()` in test/support/fakes.dart).
- [06 leftovers] Never edit files with PowerShell `Get-Content | Set-Content` (re-confirmed: turned `→` into mojibake and added a BOM); use the Edit tool or Python with `encoding='utf-8'`.
- [06 leftovers] With several agents building on this PC, `flutter test` (default concurrency) sometimes fails files with "Connection closed before test suite loaded" / "did not complete" (not test failures) → rerun with `--concurrency=1` (full suite ~4.5 min).
- [phase 07] New Phosphor icons: the vendored TTFs only have `uniXXXX` glyph names → look the name up in `https://cdn.jsdelivr.net/npm/@phosphor-icons/web@2.1.1/src/regular/style.css` (`.ph-<name>:before { content: "\eXXX" }`), then check the glyph exists with fontTools `getBestCmap()`.
- [phase 07] An invisible sizing child (`Opacity(0)` text) placed last in a `Stack` takes the taps of the widgets under it (`RenderParagraph` hit-tests itself) → wrap it in `IgnorePointer` (fixed in `FolderTabs`).
- [phase 07] Riverpod 3: `StreamProviderFamily` and `Override` are exported from `package:flutter_riverpod/misc.dart`, not the main library; family overrides are `provider.overrideWith((ref, arg) => …)`.
- [phase 07] Widget tests with a memory Drift DB: close it in a teardown that pumps a little time; a bare `db.close()` hangs once `watch()` streams are active. Goldens override the stream providers with `Stream.value(...)` instead of using Drift.
- [phase 07] A hung `flutter test` can leave `flutter_tester.exe` holding `build/native_assets/windows/sqlite3.dll` → kill only that process before re-running.
- [phase 08] Emulator DNS answers `*.supabase.co` with an ISP block address (202.83.21.15, TLS reset) while the PC resolves Cloudflare IPs; Private DNS (DoT) is blocked too → integration tests run with `--dart-define=PIN_HOST_IP=$((Resolve-DnsName <host> -Type A)[0].IPAddress)` (`integration_test/support/net_pin.dart`). Never leave the shared emulator's DNS settings changed.
- [phase 08] `capture_markers.ps1 -Hold 12` is too short: each marker needs ~10 s of adb work, so later `-text200` shots catch the next screen → keep the default `-Hold 30`.
- [phase 07] Integration tests that hold a screen for host screenshots must wait with `await Future.delayed(...)` + `pump()`, never a `while (…) await tester.pump(d)` loop: Dart runs on Android's main thread (merged threads), the tight loop starves input/config events and Android shows "isn't responding" over every shot. `capture_markers.ps1 -Define 'UI_ONLY=a,b'` re-captures single screens when the test supports it.
- [phase 07] Emulator captures: Gboard's "Try out your stylus" tip covers autofocused fields → `adb shell settings put secure stylus_handwriting_enabled 0` during captures, `settings delete …` afterwards.
- [phase 07] `flutter test integration_test/...` failed once with "Failed to start Dart Development Service" right after another device run → re-run once (same as the phase 01 loading flake).
- [phase 12] PowerShell expands backticks inside `python -c "..."`: a `` `r `` in a Drift comment became a CR, the rest of the comment became SQL, build_runner still passed but `drift_dev schema dump` crashed ("Null check operator" in `SchemaWriter._entityToJson`) → do scripted edits through Bash quoted heredocs (`python -I - <<'EOF'`).
- [phase 12] Drift schema bump: `dart run drift_dev schema dump lib/data/local/app_database.dart drift_schemas/` + `dart run drift_dev schema generate drift_schemas/ test/data/local/generated/`, then `dart format` the regenerated `app_database.g.dart` (unformatted output = a 4k-line diff) and `git checkout` `schema_v1.dart` (line endings only); onUpgrade `if (from < N)` steps keep parallel phases' bumps mergeable.
- [phase 12] postgrest-dart `.order(column)` sorts DESCENDING by default → pass `ascending: true`.
- [phase 12] `Wrap(alignment: WrapAlignment.spaceBetween)` only spreads its children when it gets the full width → the parent Column needs `crossAxisAlignment: stretch`. A vertical dashed rail = `RotatedBox(quarterTurns: 1, child: DashedDivider())` in an `IntrinsicHeight` row.
- [phase 12] Data the UI needs only on one screen (edit history) can be fetched per record with a plain RLS select through a small `*Remote` interface + Drift cache instead of widening `pull_changes` (which parallel phases also replace).
