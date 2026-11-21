# 09 — Testing strategy

Everything is tested by the sessions themselves (no human tester). Research: `research/06-upi-release-ci.md`,
`research/04-flutter-architecture-and-packages.md`.

## 1. Layers and tools

| Layer | Tool | Where | Runs |
| --- | --- | --- | --- |
| Money / domain / sync logic | `test` + `glados` (property tests) + `mocktail` | `test/core/**`, `test/domain/**`, `test/data/sync/**` | `flutter test` (G2) |
| Local DB | Drift `NativeDatabase.memory()`; schema migration tests with `drift_dev` dumps | `test/data/local/**` | G2 |
| Providers / controllers | Riverpod `ProviderContainer` with overrides, fake repositories, fake clock | `test/features/**/application/**` | G2 |
| Widgets | `flutter_test`, semantics + a11y guidelines (`androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`) | `test/features/**/presentation/**`, `test/ui/**` | G2 |
| Goldens | `alchemist` (CI-safe goldens; bundled fonts loaded in `flutter_test_config.dart`) — light, dark, text 2.0 | `test/goldens/**` | G2 |
| SQL / RLS | pgTAP files via MCP `execute_sql` (`BEGIN … ROLLBACK`) on dev; same files in CI with `supabase start` | `supabase/tests/*.test.sql` | G3 |
| Edge Functions | `deno test` with mocked `fetch` | `supabase/functions/**/**_test.ts` | G3 |
| Integration (device) | `integration_test` against the dev project with dev-login users; Patrol only if a flow needs native UI (permission dialogs, notification shade) | `integration_test/**` | G5 |
| E2E scenarios | scripted: integration tests + adb (airplane mode, kill app, fake UPI app, fingerprint) + multi-user harness | `integration_test/scenarios/**`, `tool/e2e/*.ps1` | G5 |
| Visual review | `ui-review` skill (screenshots vs spec + Atlys refs) | artefacts folder outside repo | G5 |

## 2. Contract tests (client = server)

`test/fixtures/money_vectors.json` (copy of `planning/reference/money_vectors.json`) drives
`test/core/money/vectors_test.dart`; `tool/gen_sql_vectors.dart` generates `supabase/tests/010_money_vectors.test.sql`
from the same file. CI fails if the generated SQL is stale (`git diff --exit-code` after regeneration).
Same idea for the recurring next-date calculator (`recurring_vectors.json`) and the UPI link builder.

## 3. Multi-user harness

`integration_test/support/harness.dart`: signs in test users A/B/C with the dev-only password login (created with
`signUp` if missing; dev project has email confirmation off), creates a fresh group per test (name prefixed
`e2e-<timestamp>`), lets B/C act through the real `apply_mutations` RPC from the test process while the app on the
emulator runs as A. Cleanup: soft-deletes its groups at the end; a weekly SQL job is not needed (dev data is
disposable). Test emails: `e2e-a@splitify.test` etc.; password `E2E_PASSWORD` in `secrets/env.dev.json`.

## 4. Coverage floors (checked by `tool/coverage_check.dart`)

`lib/core/money` 100 % lines · `lib/data/sync` 95 % · other `lib/core` + `lib/domain` 90 % · `lib/data` 85 % ·
`application` (controllers) 85 % · presentation 60 % (goldens cover visuals) · overall 80 %.

## 5. Conventions

- Test names: `'<unit> <behaviour> when <condition>'`; tag with TC id in a comment `// TC-5..9-03`.
- Tags: `golden`, `device` (needs emulator), `needs-owner` (needs an owner setup item), `quarantine` (only external
  services; must have a BLK entry), `slow`.
- Fakes over mocks for repositories and the remote API (`FakeRemoteApi`, `FakeClock`, `FakeConnectivity`).
- Factories: `test/support/factories.dart` (`aGroup()`, `anExpense()`, members with positions).
- No real network in G2. No sleeps: use fake clocks / `pumpAndSettle` with timeouts.
- Every bug fixed gets a regression test referencing the bug in the test name.

## 6. CI (GitHub Actions, public repo = free minutes)

`.github/workflows/ci.yml` on push to `phase/**`, `main` and PRs:
1. `flutter` job (ubuntu): `subosito/flutter-action` pinned to 3.50.1 + cache → `flutter pub get` → format check →
   `flutter analyze` → `dart run tool/guards.dart` → `flutter test --coverage --exclude-tags device,needs-owner,quarantine`
   → coverage floors → `flutter build apk --debug` with a dummy env file (`secrets/env.example.json`).
2. `db` job: `supabase/setup-cli` → `supabase start` (Docker on runner) → apply `supabase/migrations` →
   `supabase test db` (runs `supabase/tests`) → stale-vector check.
3. `functions` job: `denoland/setup-deno` → `deno fmt --check`, `deno lint`, `deno test` in `supabase/functions`.
No secrets needed (forks safe). Device tests stay local (emulator on this PC); android-emulator-runner is optional
later.

## 7. Phase gates

Each phase file lists its TC ids; G2/G3/G5 must show them passing (or `needs-owner` with an open BLK). Flaky = bug.

## 8. Test-only tooling built during the plan

| Tool | Phase | Purpose |
| --- | --- | --- |
| `tool/env.ps1` | 01 | PATH fix + `JAVA_HOME` for every PowerShell session |
| `tool/verify.ps1` | 01 | G1–G4 in one command, prints a gate table |
| `tool/guards.dart` | 01 | static guards (money doubles, Supabase outside remote layer, `print`, literal colours, secrets) |
| `tool/coverage_check.dart` | 01 | floors §4 |
| `tool/run_sql_tests.md` | 04 | how the session runs `supabase/tests` through MCP (until a script is possible) |
| `tool/gen_sql_vectors.dart` | 04 | §2 |
| `tool/e2e/*.ps1` | 06+ | adb helpers: airplane mode, kill/relaunch, screenshots, notification dump |
| `tool/fake_upi_app/` | 11 | debug-only app handling `upi://pay` (logs URI under tag `FAKE_UPI`) |
