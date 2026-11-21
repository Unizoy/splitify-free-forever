# Phase 20 — Release (signed APK, draft GitHub Release)

- Depends on: 19 · Owner setup: **checklist R below** · Branch: `phase/20-release`
- Goal: prod backend live, signed release APK built against prod, smoke-tested, published as a **draft** GitHub
  Release (owner clicks Publish). No Play Store (D-014).
- Read first: `research/06-upi-release-ci.md` (signing, release script, developer verification), `03-backend.md` §9.

## Checklist R — owner (≈ 20 min, once, when ready to go public)

1. Supabase → New project `splitify-prod`, region Mumbai, free plan (move to Pro when real users arrive).
2. Auth: Google provider (same Web client id/secret; add `https://<prod-ref>.supabase.co/auth/v1/callback` to the
   Web client's redirect URIs), custom SMTP Resend (same settings), OTP templates (phase 00 D.5), **Confirm email ON**.
3. Edge Functions → Secrets: `FCM_SERVICE_ACCOUNT_JSON` (same Firebase project is fine).
4. Terminal: `claude mcp add --transport http supabase-prod "https://mcp.supabase.com/mcp?project_ref=<prod-ref>"`
   → `claude` → `/mcp` → authenticate `supabase-prod`.
5. Add `"supabase_prod_project_ref": "<prod-ref>"` to `secrets/owner-inputs.json`.
Sessions detect R by the owner-inputs key + `mcp__supabase-prod__list_tables` working; otherwise phase stays
`blocked` with this list in BLOCKERS.md.

## Tasks (session)

- [ ] T1 Apply all migrations to prod via `supabase-prod` MCP (guard allows it only in phase 20), verify list, run
      the SQL test suite against prod inside rollbacks (read-only effect), advisors clean.
- [ ] T2 Deploy all Edge Functions to prod; set `private.settings` project URL; check cron jobs; trigger
      `fetch-rates` once.
- [ ] T3 `secrets/env.prod.json` (prod URL + publishable key, `DEV_LOGIN=false`).
- [ ] T4 Version `1.0.0+1`; CHANGELOG; build signed release APKs (`--split-per-abi` + universal) with
      `--dart-define-from-file=secrets/env.prod.json`; SHA-256 checksums file.
- [ ] T5 Smoke test the release APK on the emulator against prod: sign in by email code is manual-opt, so test with
      Google if the emulator has an account, else verify welcome → sign-in screen renders, app lock, offline
      start; record what ran.
- [ ] T6 `docs/PRIVACY.md` linked in README; note about Android developer verification (register package
      `com.unizoy.splitify` + signing key SHA-256 before Google's India rollout, research 06 §3) in the report as an
      owner action.
- [ ] T7 `gh release create v1.0.0 --draft --target phase/20-release --title "Splitify Free Forever 1.0.0"
      --notes-file CHANGELOG.md <apks> <sha256 file>` (guard allows only `--draft`).

## Done when

Draft release exists with APKs + checksums; report lists owner actions: review & publish the draft, merge phase
branches to `main`, optional real-phone UPI check, developer verification registration.
