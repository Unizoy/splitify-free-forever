# Phase 00 — Owner setup (one-time, by hand)

**Who:** the owner (Mohit). **Time:** about 60–75 minutes. **When:** any time before phase 04 starts — phases
01–03 need no cloud access and can run while this is still being done.

After this checklist, no session ever needs the owner again until the release phase (which has its own short
checklist R for the prod project). Sessions verify every item below themselves; anything missing becomes a
blocker in `planning/BLOCKERS.md` with the exact step to redo.

Values you will collect go into **one git-ignored file**: `secrets/owner-inputs.json` (template in step H).
Nothing secret is ever pasted into chat or committed.

---

## A. PC preparation (5 min)

1. *(Optional, recommended)* Fix the broken machine PATH permanently. Open **PowerShell as Administrator**:
   ```powershell
   $p = [Environment]::GetEnvironmentVariable('Path','Machine')
   [Environment]::SetEnvironmentVariable('Path', (($p -split ';') | ? { $_ }) -join ';', 'Machine')
   ```
   Restart VS Code afterwards. (Sessions also work without this; they apply a per-shell fix.)
2. *(Optional, recommended)* Add a **test Google account** to the emulator so sessions can test Google sign-in
   end-to-end: start the emulator `Pixel_9_API_36` → Settings → Passwords & accounts → Add account → Google →
   sign in with a throwaway Google account (not your personal one).

## B. Supabase dev project (10 min)

1. supabase.com → **New project** → Name `splitify-dev` → generate a strong database password and store it in
   your password manager (sessions never need it) → Region **South Asia (Mumbai)** → Free plan → Create.
2. Copy the **Project ref** (Project Settings → General → Reference ID) into `owner-inputs.json` (step H).
3. Authentication → **Sign In / Providers → Email**:
   - Email provider: **enabled**.
   - **Confirm email: OFF** for this dev project (lets automated tests create password users instantly; the
     release project in phase 20 turns it on).
   - Email OTP length **6**, OTP expiry **600 seconds**.
4. Authentication → **Email Templates**: replace the body of both **Magic Link** and **Confirm signup** with the
   code template from section D.5 (so emails contain a 6-digit code instead of a link).
5. Connect the **Supabase MCP server** to Claude Code. In a normal terminal (not VS Code) inside the repo folder:
   ```powershell
   cd C:\Users\mohit\OneDrive\Desktop\theCode\splitify-free-forever
   claude mcp add --transport http supabase "https://mcp.supabase.com/mcp?project_ref=<YOUR_PROJECT_REF>"
   claude
   ```
   In that Claude session type `/mcp` → choose **supabase** → **Authenticate** → log in in the browser → allow.
   Then ask: "Using the supabase MCP, list the tables in the public schema." It should answer (empty list).
   Type `/exit`. The login is saved on this PC and reused by every later session (VS Code too).

## C. Google sign-in clients (15 min)

1. console.cloud.google.com → project picker → **New project** → name `Splitify Free Forever` → Create → select it.
2. **Google Auth Platform** (APIs & Services → OAuth consent screen) → Get started:
   App name `Splitify Free Forever`, user support email = yours, Audience **External**, contact email = yours →
   Create. Scopes: keep the defaults (`openid`, `email`, `profile`) — no sensitive scopes, so no verification.
   Audience → **Publish app** (basic scopes need no review; otherwise only listed test users could sign in).
3. **Clients → Create client → Web application** → name `Supabase` → under *Authorized redirect URIs* add
   `https://<YOUR_PROJECT_REF>.supabase.co/auth/v1/callback` → Create. Copy the **Client ID** (into
   `owner-inputs.json` as `google_web_client_id`) and keep the **Client secret** for step 6.
4. **Create client → Android** → name `Android debug` → package name `com.unizoy.splitify` → SHA-1
   `0A:84:0D:E1:1A:CB:C7:E8:76:7B:31:11:B1:2A:A0:02:C5:A0:3E:7D` (this PC's debug key, read on 2026-11-21) → Create.
5. **Create client → Android** → name `Android release` → same package → the **release** SHA-1 printed in step F →
   Create.
6. Supabase → Authentication → **Sign In / Providers → Google** → enable → *Client IDs*: the **Web** client ID from
   step 3 → *Client Secret*: the Web client secret → turn *Skip nonce checks* **on** (the Android sign-in library
   sends no nonce) → Save.

## D. Email codes through Resend (15 min)

1. resend.com → sign up → **Domains → Add domain**. Use a subdomain of your domain, e.g. `mail.<yourdomain>`.
2. Add the DNS records Resend shows (SPF/MX + DKIM TXT) at your DNS provider → click **Verify** (can take minutes).
3. Resend → **API Keys → Create** → permission *Sending access*, domain = the one above → copy the key (shown once).
4. Supabase → Project Settings → **Authentication → SMTP Settings** → enable custom SMTP:
   - Sender email `no-reply@mail.<yourdomain>` · Sender name `Splitify Free Forever`
   - Host `smtp.resend.com` · Port `465` · Username `resend` · Password = the Resend API key → Save.
   - Authentication → **Rate Limits** → "Rate limit for sending emails": 100 per hour.
5. Template body for **Magic Link** and **Confirm signup** (Authentication → Email Templates), subject
   `Your Splitify code: {{ .Token }}`:
   ```html
   <h2>Your sign-in code</h2>
   <p>Enter this code in Splitify Free Forever:</p>
   <p style="font-size:28px;font-weight:700;letter-spacing:6px">{{ .Token }}</p>
   <p>It expires in 10 minutes. If you didn't ask for it, ignore this email.</p>
   ```
6. Test: Supabase → Authentication → Users → **Invite user**/send magic link to your own address → you should
   receive the email from your domain within a minute.

## E. Firebase for push notifications (10 min)

1. console.firebase.google.com → **Add project** → choose the existing Google Cloud project
   `Splitify Free Forever` (keeps everything together) → Google Analytics **off** → Create.
2. Project settings → General → **Add app → Android** → package `com.unizoy.splitify`, nickname `Splitify`,
   debug SHA-1 from C.4 → Register → **Download `google-services.json`** → save it as
   `C:\Users\mohit\OneDrive\Desktop\theCode\splitify-free-forever\secrets\google-services.json`
   (the `secrets/` folder is git-ignored; sessions copy it into the Android project). Skip the remaining wizard steps.
3. Project settings → **Cloud Messaging** → confirm *Firebase Cloud Messaging API (V1)* shows **Enabled**.
4. Project settings → **Service accounts** → *Generate new private key* → a JSON file downloads.
   Supabase → **Edge Functions → Secrets** → add secret `FCM_SERVICE_ACCOUNT_JSON` = the entire JSON file content
   → Save. Then **delete the downloaded JSON file** from your PC (it is a powerful key; it must only live in
   Supabase).

## F. Release signing key (5 min)

Run in PowerShell (choose a strong password when asked and store it in your password manager):
```powershell
New-Item -ItemType Directory -Force "$HOME\.splitify\release" | Out-Null
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v `
  -keystore "$HOME\.splitify\release\splitify-release.jks" -alias splitify `
  -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=Splitify Free Forever, O=Unizoy, C=IN"
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v `
  -keystore "$HOME\.splitify\release\splitify-release.jks" -alias splitify | Select-String SHA1
```
Use the printed SHA1 in step C.5. Back up `splitify-release.jks` + password somewhere safe (cloud drive /
password manager): if it is lost, future updates can't be installed over the old app.

Create `secrets\key.properties` (git-ignored) with four `name=value` lines (no spaces around `=`):
`storeFile` = `C:/Users/mohit/.splitify/release/splitify-release.jks`, `keyAlias` = `splitify`, and
`storePassword` / `keyPassword` = the password you chose above.

## G. GitHub (3 min)

1. Repo → Settings → Actions → General → *Allow all actions* (default) → Workflow permissions **Read**.
2. *(Recommended)* Settings → Branches → **Add branch ruleset** for `main`: require a pull request before merging,
   block force pushes. This doubles the "sessions never touch main" guard.

## H. Local inputs file (3 min)

Create `secrets\owner-inputs.json` (git-ignored) — non-secret identifiers only:
```json
{
  "supabase_project_ref": "<ref from B.2>",
  "google_web_client_id": "<id from C.3>.apps.googleusercontent.com",
  "email_sender": "no-reply@mail.<yourdomain>",
  "emulator_has_google_account": true
}
```
Sessions read this, fetch the project URL and publishable key through the MCP server, and write
`secrets/env.dev.json` themselves.

## I. Claude Code autonomy check (3 min)

The planning session already created the git-ignored `.claude/settings.local.json` (bypass mode + guard hooks) and
`.vscode/settings.json` (VS Code bypass settings). Check once:

1. VS Code → open a **new** Claude Code session in this folder → the mode indicator should show
   **Bypass permissions**. If a one-time warning appears, accept it.
2. Say "execute the plan". The session starts phase 01 (or the next phase) without asking anything.

## Done when

- [ ] `secrets/owner-inputs.json`, `secrets/google-services.json`, `secrets/key.properties` exist.
- [ ] Supabase MCP answers from a new session.
- [ ] Google provider + custom SMTP saved in Supabase; test email received from your domain.
- [ ] `FCM_SERVICE_ACCOUNT_JSON` secret set in Supabase; downloaded key file deleted.
- [ ] New VS Code sessions start in Bypass permissions mode.

Sessions verify these automatically (phase 04 onwards) and log a precise blocker if anything is missing.
