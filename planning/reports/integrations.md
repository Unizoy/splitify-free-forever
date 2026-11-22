# Integrations report — real Google sign-in, email codes and push (D-026)

- Date: 2026-11-22 · Branch: `qa/integrations` · Base: `origin/main` (67a974d, phases 01–18)
- Status: done-with-blockers (Google and push PASS end to end; the email code itself needs one owner check, BLK-002)

## Summary

The three services the owner set up today were checked on emulator-5554 against the dev project with the real app
(release x64 build of `bootstrap()` plus the S-214 DNS pin, S-235). "Continue with Google" opens Credential Manager,
signs in with the owner's test account and keeps the session across a restart; sign-out works. Pushes arrive for
real through FCM with the app in front, in the background and killed, and a tap opens the right screen. Email codes
are sent through the owner's Gmail SMTP and wrong codes are refused with a clear message; reading the real code in
the emulator's Gmail app was refused by the agent permission system, so the last step is an owner check (BLK-002).
Fixes: Credential Manager errors no longer hang the screen, sign-out clears the Google credential, wrong/used codes
are handled as wrong tries with a clean retry, the code length is configurable, and the notification icon no longer
looks like a "blocked" sign.

## Results

| Check | Result | Evidence (screenshots in `C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\integrations\`, account email greyed out) |
| --- | --- | --- |
| A1 Implementation | PASS | `google_sign_in` 7.2 `initialize(serverClientId: web client id)` → `authenticate()` = Credential Manager `GetSignInWithGoogleOption(serverClientId)` (pub cache `google_sign_in_android` 7.2.19 `GoogleSignInPlugin.kt`), all accounts, no nonce → `signInWithIdToken(provider: google)` (S-230). Debug keystore SHA-1 = the registered debug SHA-1; release builds use the debug key |
| A2 Sign in | PASS | `a1-sign-in` (no "Coming soon") → `a2-google-sheet` "Choose an account" → `a3-after-pick` consent "Agree and share" → `a4-signed-in` Groups. `auth.identities`: one `google` identity, `raw_app_meta_data.provider = google` (no email printed) |
| A3 Restart | PASS | force-stop + start → `a5-restart-still-signed-in` (Groups, no sign-in) |
| A4 Sign out | PASS | Account → settings → Sign out → `a6-signed-out` (welcome); the device token row is gone (0 rows) |
| B1 Request code | PASS | `b1-code-screen`; auth log `/otp` 200 (custom SMTP accepted the mail) |
| B2 Read code in Gmail, enter it | BLOCKED | the permission system refused reading the Gmail app's UI; nothing in the inbox was opened, read or captured. Owner check: BLK-002 |
| B3 OTP length | needs owner | could not be seen (B2); app default 6 = Supabase's documented default; `EMAIL_OTP_LENGTH` (6–10) sets it (S-232) |
| B4 Wrong code | PASS | `000000` → auth log 403 `otp_expired` "token has expired or is invalid"; old build: `b2-wrong-code` ("…Request a new code."); fixed build: see B6 |
| B5 Reused code | covered, not run live | same server answer as B4 (`otp_expired`), same UI path (S-233); live run needs the real code (BLK-002) |
| C1 Permission + token | PASS | first group → pre-prompt `c1-preprompt` → Android dialog `c2-android-permission` → Allow → `device_tokens`: 1 row (android, app 0.1.0, 142-char token) |
| C2 Foreground | PASS | B joins → heads-up "Push check · E2E B joined the group" `c4-foreground-join`; B adds "Foreground dinner" → shown + synced `c5-foreground-expense`; `dumpsys notification`: channel `groups`/`expenses`, importance 4 |
| C3 Background | PASS | HOME, B adds "Background taxi" → tray `c6-background-shade`; tap → the expense `c7-tap-opens-expense` |
| C4 Killed | PASS | HOME + `am kill`, B reminds → tray `c8-killed-shade`; tap cold-starts → group Balances tab `c9-cold-tap-opens-balances` |
| C5 send-push / FCM | PASS | 4 calls, each `{"outcome":"sent","delivered":1,"failed":0,"errors":[]}` (pg_net `net._http_response`, HTTP 200) = FCM 200; `function_edge_logs` show the 4 send-push runs. No 401/403/404 |
| D1 Fixed build: Google again | PASS | after sign-out the account picker shows again (credential cleared, S-231); spinner on the Google button `d2-google-spinner`; signed in without a new consent; the token re-registered on sign-in (1 row) |
| D2 Fixed build: new icon | PASS | push "Icon check" → brand-mark icon in the shade `d4-shade-new-icon` and status bar `d3-statusbar-icon-top` (S-234) |
| D3 Fixed build: wrong code | PASS | `000000` → boxes emptied and red, keyboard up, "That code is wrong or has expired. Check your newest email, or tap Resend code." `d5-wrong-code-fixed` (S-233) |

Not a product bug, noted for the next device session: after visiting another app, emulator screenshots of the
app came out uniformly ~7 % darker (`b2`–`b4`, same in a fresh app start, so not the app); in the next session,
started with `KEYCODE_WAKEUP`, they were normal again (`d1`–`d5`). Likely the emulator's pre-sleep screen dim.

## Fixes made

| Problem (found on device) | Fix | Tests |
| --- | --- | --- |
| A Credential Manager error other than "cancelled" escaped the repository → the sign-in screen stayed busy | `googleFailure()` maps codes to `AuthFailure`; logged by code name (S-231) | `auth_repository_test.dart` |
| Sign-out left the Google credential selected | `GoogleIdTokenSource.signOut()` → `GoogleSignIn.signOut()` (best effort) | `auth_repository_test.dart` |
| The busy dots showed on "Send code" while the Google sheet was open | spinner on the Google button, "Send code" disabled meanwhile | `auth_screens_test.dart` |
| Wrong code → "This code has expired… Request a new code." and the try was not counted (Supabase sends `otp_expired` for wrong, used and expired codes) | `otp_expired` → `invalidCode`; new copy; refused code empties the boxes, red until the next digit; offline keeps the digits (S-233) | `auth_repository_test.dart`, `auth_screens_test.dart`, goldens `screen_sign_in_code_wrong_*` |
| Code length fixed at 6 in the UI | `EMAIL_OTP_LENGTH` (6–10, default 6) drives boxes, title, semantics, auto-verify; hint says "one-time code" (S-232) | `core_test.dart`, `auth_screens_test.dart`, goldens `screen_sign_in_code_8_*`, `screen_sign_in_*` |
| Notification icon read as a "blocked" sign | brand-mark vector `ic_stat_splitify.xml` (S-234) | device D2 |

## Tests

- New/changed: unit 4 (Env length parsing, Credential Manager mapping, sign-out clearing, `otp_expired` mapping) ·
  widget 4 (8-digit code, offline keeps digits, wrong code clears, Google spinner) · golden 8 new
  (`screen_sign_in_code_8_*`, `screen_sign_in_code_wrong_*`) + 2 regenerated (`screen_sign_in_*_text200`) · device: the
  checks above. Real-font review (`PLATFORM_GOLDENS=1`): wrong-code light 9/10, 8-digit dark 9/10, 8-digit 200 % 8/10.
- Test IDs: TC-B1-07 pass, TC-B1-09 partial (BLK-002), TC-B1-10/11/12 pass, TC-19-04 dumpsys part pass, TC-19-10 pass.

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | `dart format --set-exit-if-changed` 0 changed; `flutter analyze --no-fatal-infos` 0 errors/warnings; `dart run tool/guards.dart` OK |
| G2 Tests | see below | full suite + `tool/coverage_check.dart` |
| G3 Backend | SKIPPED (n/a) | no migration (0024 not needed), no Edge Function change; send-push checked live |
| G4 Build | see below | `flutter build apk --debug --dart-define-from-file=secrets/env.dev.json` |
| G5 Device | PASS | emulator-5554, lock held 17:49–18:00 and 18:13–18:17; results table above |
| G6 Docs | PASS | D-026, S-230…S-235, TC rows, BLK-002, LEARNINGS (+5), emulator-e2e skill §8b, this report |

## Decisions made

S-230 keep `authenticate()` (Credential Manager button flow) · S-231 Credential Manager errors + credential clearing +
Google spinner · S-232 `EMAIL_OTP_LENGTH` · S-233 `otp_expired` = wrong try, clean retry · S-234 notification icon ·
S-235 pinned real-app build for device checks. Owner row D-026 added.

## Blockers

BLK-002 (open): read one "Your Splitify code" email and confirm the length / sign in with it (2 min, steps in
`planning/BLOCKERS.md`).

## Owner actions

1. BLK-002 — check the Email OTP Length in the dashboard and do one code sign-in on the phone (required before
   release; 2 min).
2. Before public release: publish the OAuth consent screen (needs privacy policy + home page links, D-026); while it
   is in Testing only listed test users can use Google sign-in.
3. Optional: allow the agent to read the one "Your Splitify code" email in the emulator's Gmail next time, so the
   email check can run unattended.
