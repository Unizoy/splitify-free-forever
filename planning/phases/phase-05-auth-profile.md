# Phase 05 — Auth, profile, account (B1, B2)

- Depends on: 02, 04 · Owner setup: phase 00 C (Google), D (Resend SMTP) · Branch: `phase/05-auth-profile`
- Goal: sign in with Google or an email code, dev-only password login for tests, profile (name, photo, UPI ID +
  QR scan, default currency), Account tab + settings sheet, sign out, delete account.
- Read first: `08-feature-specs.md` B1/B2, `07-screens-and-flows.md` (welcome, sign-in, account), `03-backend.md`
  §4 (`update_profile`) and §7 (`delete-account`), `research/04` (google_sign_in 7.x snippet), `research/05` §5.

## Tasks

- [x] T1 `lib/data/remote/supabase_client.dart` (init from env), `AuthRepository` (Google via
      `GoogleSignIn.instance.initialize(serverClientId: GOOGLE_WEB_CLIENT_ID)` → `authenticate()` → `idToken` →
      `signInWithIdToken`; email `signInWithOtp` + `verifyOTP(type: OtpType.email)`; dev `signInWithPassword`;
      sign out; session stream). Unit tests with fakes.
- [x] T2 Migration: `update_profile` RPC (if not in 0004) + auth trigger check; test `022`.
- [x] T3 Screens: welcome (DashedCircleButton), sign-in (Google pill + email UnderlineField), code entry (6 boxes,
      resend timer), profile confirm on first sign-in. Router redirects by auth state.
- [x] T4 Dev login (debug only): `/debug/login` + deep link `splitify://dev/login?user=e2e-a`; harness creates
      `e2e-a/b/c@splitify.test` with `signUp` if missing. Release build test proves it's absent (TC-B1-08).
- [x] T5 Profile edit (online-only action with local cache — allowed exception, show "Needs internet" offline):
      name, photo (picker → crop → compress → `avatars` bucket), UPI ID + "Scan my UPI QR" (`mobile_scanner`,
      `upi://pay?pa=` parser), default currency picker.
- [x] T6 Account tab: avatar header, WalletCard/MetalCard/DotMatrixCard with placeholder data (real data phase
      09/17), Account settings sheet (accordions + rows: Appearance (B3), Sign out, Delete account, About &
      licences, version).
- [x] T7 (deploy SKIPPED, BLK-001) `delete-account` Edge Function + tests (deno) + deploy; client flow with "type DELETE" confirm.
- [x] T8 Sign-out: wipe local data (secure storage + prefs except theme), go to welcome.
- [ ] T9 (SKIPPED, BLK-001) Integration: dev sign-in → edit profile → restart → still signed in; sign out. Google e2e only if
      `emulator_has_google_account` is true.

## Tests

TC-B1-01…09, TC-B2-01…05.

## Done when

All listed tests pass (B1-07 may be `needs-owner`, B1-09 is manual-opt); screens pass `ui-review`.

> **Amendment (D-020, 2026-11-21):** services the owner has not set up yet run in dummy mode — build and test them behind their config checks with fakes; missing Google client id / Resend / Firebase file is not a blocker.
