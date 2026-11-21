# Research 05: Supabase (MCP, keys, RLS, Auth, limits), FCM, Frankfurter

Date: 2026-11-21. Sources are official docs fetched this session; live API results were checked with curl.
[UNVERIFIED] = from memory or not confirmed on an official page. Pages fetched through a summarizer: wording is paraphrased.

## 1. Supabase MCP server (https://mcp.supabase.com/mcp)
Source: https://supabase.com/docs/guides/getting-started/mcp ; source code https://github.com/supabase-community/supabase-mcp

URL params:
- `project_ref=<ref>`: scope to one project. This DISABLES account tools.
- `read_only=true`: queries run as a read-only Postgres user; Feedback tools off.
- `features=a,b,c`: only the listed groups.
- `skip_elicitations=<tools>`: skip confirmation forms for named tools (hosted only).
- Combine with `&`.

Feature groups and tools (all on by default except Storage):
- database: list_tables, list_extensions, list_migrations, apply_migration, execute_sql
- debugging: query_logs, get_advisors
- development: get_project_url, get_publishable_keys, generate_typescript_types
- functions: list_edge_functions, get_edge_function, deploy_edge_function, create_edge_function_secret
- account (off when project-scoped): list_projects, get_project, create_project, pause_project, restore_project, list/get_organization, get_cost, confirm_cost
- docs: search_docs
- branching (experimental, paid plan only): create/list/delete/merge/reset/rebase_branch
- feedback: submit_feedback, delete_feedback
- storage (OFF by default): list_storage_buckets, get_storage_config, update_storage_config
- notebooks (hosted only): list/get/create/run/delete_notebook
- Exact `features=` token spellings (e.g. `functions` vs `edge-functions`) not shown on the page. [UNVERIFIED] Check the GitHub README when wiring it up.

Answers to your questions:
- Set Edge Function secrets: only via `create_edge_function_secret`, and only if the client supports URL elicitation, not read-only, and you have permission. It takes only the secret NAME; the VALUE is typed by the owner in the Supabase Dashboard (never passes through chat). So the FCM service-account JSON still needs a manual dashboard paste (Edge Functions > Secrets, can paste multiple). Plan for that as a human step. Claude Code may not support URL elicitation, in which case use the dashboard entirely.
- Create storage buckets: NO tool. Storage group can only list buckets and read/update storage config. Create buckets (and their RLS policies) with `execute_sql`/`apply_migration`: `insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values (...)` plus policies on `storage.objects`. [Writing storage.buckets by SQL is a common pattern; not stated on the MCP page.]
- Project URL + publishable key: yes. `get_project_url`, `get_publishable_keys` (returns publishable and legacy anon keys). Secret keys are not returned.
- `deploy_edge_function` params (from source): `project_id` (required), `name` (required), `entrypoint_path` (default `index.ts`), `import_map_path` (optional), `verify_jwt` (default true), `files[]` of `{name, content}` strings (must include entrypoint, deno.json/deno.jsonc if present, and relative imports). Replaces an existing function of the same name immediately. Guidance: keep verify_jwt true unless the function does its own auth (webhooks/API keys). The push and rates functions called from pg_net/cron need `verify_jwt: false` plus their own secret check. Because `files` carry content as strings, keep functions as few small files; shared code must be sent in every deploy. Bundle limit 5 MB when bundled server-side (see section 6).
- Security: prompt injection is the main risk. Keep project_ref, dev project only; use `read_only=true` for reading prod; keep manual approval on.
- Command: `claude mcp add --transport http supabase "https://mcp.supabase.com/mcp?project_ref=<ref>"`. Auth is OAuth login in browser. Newer docs mention a PAT in the `Authorization` header for CI.

## 2. API keys 2026
Source: https://supabase.com/docs/guides/api/api-keys ; https://supabase.com/docs/guides/functions/secrets ; https://supabase.com/docs/guides/functions/auth
- `sb_publishable_...`: safe in apps; maps to `anon`/`authenticated` role; RLS applies. This is the only key in the Flutter app.
- `sb_secret_...`: server only; maps to `service_role`, bypasses RLS; returns 401 if used from a browser. Not JWTs, sent in the `apikey` header (not as Authorization Bearer).
- Legacy JWT keys `anon` / `service_role`: Supabase "plans to deprecate by end of 2026". Creating new keys does not revoke them; they work until you disable them in Settings > API Keys. Use the new keys from the start.
- JWT signing keys (asymmetric, rotation): not described on the keys page; Edge Functions get `SUPABASE_JWKS` to verify user JWTs. [UNVERIFIED] details of rotation UI.
- Edge Function default env vars: `SUPABASE_URL`, `SUPABASE_DB_URL`, `SUPABASE_PUBLISHABLE_KEYS` (JSON dict), `SUPABASE_SECRET_KEYS` (JSON dict, name -> key; use the `default` entry), `SUPABASE_JWKS`; legacy `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` (still injected). Hosted-only: SB_REGION, SB_EXECUTION_ID, DENO_DEPLOYMENT_ID.
- Custom secret names cannot start with `SUPABASE_`. Only Owner/Admin can set prod secrets. Secrets apply to functions without redeploy.
- New SDK pattern: `@supabase/server` `withSupabase({ auth: 'secret' | 'user' | 'publishable' | 'none' | [..] }, handler)` gives `ctx.supabaseAdmin` (RLS bypass) or `ctx.supabase` (caller's RLS). `verify_jwt` defaults true (platform check). For cron/pg_net/webhook-called functions: `verify_jwt=false` + `auth:'secret'`. Safe fallback if the package is awkward: `createClient(SUPABASE_URL, JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS')).default)`. [UNVERIFIED the key name is `default`; the docs say named keys and a `default` secret key.]
- With the new keys, platform `verify_jwt` cannot validate `sb_` keys as JWTs, which is why service-to-service functions use verify_jwt=false and check the key themselves.

## 3. RLS performance
Source: https://supabase.com/docs/guides/database/postgres/row-level-security
- Write `(select auth.uid()) = user_id`, not `auth.uid() = user_id` (planner caches it once per statement). Same for `auth.jwt()` and security-definer function calls whose args are not row data.
- Index every column used in policies (btree; first column of the index only counts). Typical: `group_members(user_id, group_id)` and `(group_id, user_id)`, plus `group_id` on every child table (expenses, splits, payments, comments, activity).
- Membership check via a `security definer` helper, e.g. `public.is_group_member(gid uuid)` doing `exists(select 1 from group_members where group_id=gid and user_id=(select auth.uid()))`. Set `search_path = ''` and schema-qualify. Helpers also avoid recursive-policy error 42P17 (policies on group_members referencing group_members). Revoke execute from `anon`/public, grant to `authenticated`. Call it as `(select public.is_group_member(group_id))`.
- Always add `to authenticated` on policies; never rely on the default `public`.
- Avoid joins/subqueries in policies that touch other RLS tables; helper functions bypass RLS inside.
- Advisors: MCP `get_advisors` (security and performance). Run after every migration. Catches: RLS disabled on public table, policies missing, unindexed foreign keys, `auth_rls_initplan` (the un-wrapped auth.uid() case), multiple permissive policies, security definer views, mutable search_path. [UNVERIFIED lint names; the page itself did not mention Advisors.]
- Name-only members (rule 8): helper must key on membership rows linked to `auth.uid()`; name-only rows have null user_id.

## 4. Postgres -> Edge Functions, Cron, Webhooks
Source: https://supabase.com/docs/guides/functions/schedule-functions ; https://supabase.com/docs/guides/cron
- Pattern: Vault stores `project_url` and `secret_key`; `pg_cron` runs `net.http_post(url := (select decrypted_secret from vault.decrypted_secrets where name='project_url') || '/functions/v1/<fn>', headers := jsonb_build_object('Content-type','application/json','apikey',(select decrypted_secret ... 'secret_key')), body := ...)`. Needs `create extension pg_net`, `pg_cron`, and Vault (`vault.create_secret(value, name)`).
- Warning on the page: pg_net writes the decrypted key to `net.http_request_queue`, so any role that can log in can read it while pending. Acceptable for a solo-owner project; keep DB passwords private. Alternative: function authenticates with a custom shared secret (`CRON_SECRET` as Edge secret + Vault copy) instead of the full secret key; limits blast radius. [Design suggestion, not from docs.]
- Never put the secret key in a migration file in Git. Create Vault secrets with a one-off `execute_sql`, and have the migration only reference them by name.
- Cron limits: max 8 jobs running concurrently, each under 10 minutes. Jobs can run from every second to yearly. Stored in `cron.job`, history in `cron.job_run_details` (prune it; it grows).
- Syntax: standard 5-field cron, plus `'30 seconds'` interval form (pg_cron >= 1.5) [UNVERIFIED on this page]. Timezone: pg_cron on Supabase uses GMT/UTC [UNVERIFIED this session; widely documented]. India is UTC+5:30 so "daily rates at 06:00 IST" = `30 0 * * *`.
- Rates cron: Frankfurter updates through the day; schedule e.g. `15 1 * * *` (and optionally a second run at `15 13 * * *`) and make the function idempotent (upsert on date+base+quote).
- Database Webhooks: created in Dashboard (Database > Webhooks) = trigger + pg_net under the hood; HTTP POST to a function on INSERT/UPDATE/DELETE with the record in the body. The Supabase push guide uses a webhook on `notifications` INSERT to call the `push` function (verify_jwt off, 1000 ms timeout, auth with secret key). Via MCP you can instead create the trigger yourself in a migration with `net.http_post` (keeps schema in repo, rule 14). Webhooks are fire-and-forget: no retries [UNVERIFIED], so make the push function idempotent and add a sweeper cron for unsent notifications (`pushed_at is null`).
- pg_net runs async, timeout default 5 s per request (settable). [UNVERIFIED]

## 5. Auth
Sources: https://supabase.com/docs/guides/auth/social-login/auth-google ; .../auth-email-passwordless ; .../rate-limits ; .../auth-identity-linking ; .../auth-smtp ; https://resend.com/docs/send-with-supabase-smtp
Google native:
- Create in Google Cloud: a Web OAuth client (id + secret) and an Android OAuth client (package name + SHA-1). Debug and release keystores have different SHA-1; add each (Play App Signing adds a third SHA-1 from the Play Console).
- Supabase Google provider: Client IDs field = comma-separated, web client ID FIRST, then Android ID; paste the Web client secret.
- App: `GoogleSignIn.instance.initialize(serverClientId: <WEB client id>)` (google_sign_in 7.x API), authenticate, take `idToken`, then `supabase.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: ..., accessToken: ...)`.
- Nonce: Supabase validates nonces by default; pass SHA-256-hashed nonce to Google, raw nonce to Supabase. The docs say Flutter on iOS needs "Skip nonce check" on; the Flutter Android example shows no nonce. Simplest on Android: do not pass a nonce and leave Skip Nonce Check off, test; if it fails with nonce error, enable skip. [UNVERIFIED which works for google_sign_in 7 on Android; test early.]
Email OTP:
- Same implementation as magic link. Put `{{ .Token }}` in the template to send a 6-digit code. OTP length is 6 (docs say six digits; a length setting is not documented on that page). Expiry default 1 hour, configurable (Auth > Providers > Email > Email OTP expiration); one request per user per 60 s by default.
- Which template: the docs pages fetched do NOT say. Known behaviour [UNVERIFIED, from GoTrue]: `signInWithOtp` for a NEW user sends the "Confirm signup" template; for an EXISTING user it sends "Magic Link". So edit BOTH templates to show `{{ .Token }}` (and not rely on `{{ .ConfirmationURL }}`). Verify with `verifyOtp(type: OtpType.email)`; some versions need `signup` type for new users [UNVERIFIED; try `email` first].
- `shouldCreateUser: false` blocks signup via OTP.
Custom SMTP / Resend:
- Built-in SMTP: only team members' addresses, 2 emails/hour, no SLA. Unusable for real users.
- Resend: host `smtp.resend.com`, port 465, user `resend`, password = Resend API key. Needs a VERIFIED DOMAIN (needs a domain you own). Resend free tier limits not checked [UNVERIFIED; roughly 100/day, 3,000/month].
- After enabling custom SMTP, Supabase limit starts at 30 emails/hour, adjustable on the Auth Rate Limits page.
Rate limits (defaults): sign-up/sign-in per IP 30 per 5 min; OTP/magic link 1 per user per 60 s; verify 30 per 5 min; token refresh 150 per 5 min; anonymous sign-ins 30/hour per project (per IP, adjustable); emails 2/hour built-in. All but MFA configurable.
Linking:
- Identities with the same VERIFIED email auto-link into one user. Google (verified email) + email OTP (proof of ownership) with the same address end in one user. Google-then-OTP: OTP sign-in to an existing user works because OTP proves ownership. Unverified emails are never auto-linked (anti pre-account-takeover). Manual linking exists (`linkIdentity`, Dart `linkIdentityWithIdToken`) for different emails; must be enabled.
- Quirk: signing up with email after OAuth for the same address may return an obfuscated response with no email (enumeration protection). That is for password signUp; for signInWithOtp on an existing confirmed user it normally just sends the magic-link email. [UNVERIFIED]
Anonymous sign-ins: enable in Auth settings; 30/hour limit; can convert later by linking. Not needed for this plan (members are not accounts, rule 8).
Delete user: from an Edge Function with the secret key: `supabase.auth.admin.deleteUser(userId, shouldSoftDelete?)`. Verify the caller's JWT first (`auth:'user'`, take id from claims, never from body). Because rule 9 keeps data, set FKs to profiles with `on delete set null` or convert the member to name-only before deleting, and remove device tokens. [Design note.]

## 6. Free plan limits (https://supabase.com/pricing ; billing page ; realtime limits ; edge limits ; pausing page)
- Active projects: 2 (matches plan: dev + prod). 
- MAU 50,000. Database 500 MB per project. File storage 1 GB. Egress 5 GB. Edge Function invocations 500,000/month. Realtime messages 2 million/month; peak connections 200.
- Realtime per-second: 100 msgs/s, 100 channel joins/s, 100 channels per connection, payload: broadcast 256 KB, postgres_changes 1,024 KB.
- Edge Function limits: memory 256 MB, CPU 2 s per request (async I/O not counted), wall clock 150 s, 100 functions per project, bundle 5 MB if bundled server-side (MCP/dashboard) vs 20 MB with CLI.
- Inactivity pausing: paused after 7 days of low activity (email warning about a week before... the page says warning roughly one week before). Restorable up to 1 year. Hosted prod must not rely on the free plan; a daily pg_cron job counts as DB activity [UNVERIFIED]. Cron/rates job helps keep it alive; a pause will break everyone's sync.
- Backups: no daily backups on Free (Pro has 7 days) [pricing page lists backups only for Pro/Team]. Keep schema in repo (rule 14) and take own `pg_dump` exports. Point-in-time recovery is paid.
- Logs retention short on free (1 day) [UNVERIFIED].
Realtime strategy:
- postgres_changes: simple, adds table to `supabase_realtime` publication; RLS is enforced per subscriber (each change is authorized for each subscriber, so cost grows with subscribers). Docs say it "does not scale as well" as Broadcast. With 200 connection cap and 2M messages/month, each expense change fanned out to N group members counts N messages.
- Broadcast from DB: trigger calls `realtime.broadcast_changes()` on a private channel (e.g. `group:<id>`); RLS policy on `realtime.messages` controls who may subscribe; client uses `setAuth()` and `config: {private: true}`. Recommended by docs for most use cases; more setup.
- Suggestion: one private broadcast topic per group (`group:<id>`), payload = just the changed row id/type; client then pulls deltas through the normal sync (offline-first anyway). Fewer messages, fewer limits. Opt in only when the app is foreground; push (FCM) covers background.

## 7. pgTAP and RLS testing
Source: https://supabase.com/docs/guides/database/extensions/pgtap ; https://supabase.com/docs/guides/database/testing
- Enable: `create extension pgtap with schema extensions;` (hosted, any time, via `execute_sql`/`apply_migration`). Drop afterwards in prod if desired.
- Docs' runner is `supabase test db` (CLI): not available here. Alternative: run each test file via MCP `execute_sql` inside `begin; ... select * from finish(); rollback;`. Output rows are the TAP lines ("ok 1 - ..." / "not ok"). Rollback leaves no data.
- RLS impersonation (standard Postgres, works over `execute_sql`): inside the transaction `set local role authenticated; set local "request.jwt.claims" = '{"sub":"<uuid>","role":"authenticated"}';` (also `request.jwt.claim.sub` for older setups). Then run selects/inserts and assert counts with `is()`, `throws_ok()`, `results_eq()`. `reset role;` to return to postgres. Test as `anon` too. Seed users by inserting into `auth.users` (postgres role) within the transaction. [Pattern from memory; docs fetched did not show it. UNVERIFIED but standard.]
- `policies_are()` asserts the exact policy set on a table; `has_column`, `has_table`, `col_is_pk`, `table_privs_are` also useful; also assert `relrowsecurity` for every public table (rule 7) with a query on `pg_class`.
- basejump `supabase-test-helpers` (https://github.com/usebasejump/supabase-dbdev / `basejump-supabase_test_helpers`): installed as a dbdev/TLE extension (`tests.create_supabase_user`, `tests.authenticate_as`, `tests.clear_authentication`, `tests.rls_enabled`). Installing needs `pg_tle`/dbdev: [UNVERIFIED availability on hosted free]. No CLI needed in principle, but simpler and fewer deps: write own 3 small helper functions in a `tests` schema (create_user, authenticate_as, clear) in a migration or per-test preamble. MCP `execute_sql` runs one request at a time; keep each pgTAP file a single call.
- Caveat: `execute_sql` on MCP wraps results with prompt-injection text; fine for tests.
- With `read_only=true` tests that write will fail; keep tests on the dev project with write mode.

## 8. FCM HTTP v1 from a Deno Edge Function
Sources: https://supabase.com/docs/guides/functions/examples/push-notifications ; https://firebase.google.com/docs/cloud-messaging/error-codes
- Official Supabase guide uses `npm:google-auth-library@^10` `JWT` client with scope `https://www.googleapis.com/auth/firebase.messaging`, reading service-account JSON (their example ships the file in the function dir; we must NOT: put the JSON in an Edge secret `FIREBASE_SERVICE_ACCOUNT` and `JSON.parse(Deno.env.get(...))`).
- Lighter option (no dependency): sign an RS256 JWT with Web Crypto (`crypto.subtle.importKey('pkcs8', ...)` from the PEM `private_key`, claims `iss=client_email`, `scope`, `aud=https://oauth2.googleapis.com/token`, 1h exp), POST to `https://oauth2.googleapis.com/token` with `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer`, get `access_token`. Cache the token in module memory for ~50 min. [Standard OAuth; not on the Supabase page.] Using `jose` from npm also works in Deno. Recommend Web Crypto + jose to stay under the 5 MB bundle and cut cold start; google-auth-library is bigger but is the documented route.
- Send: `POST https://fcm.googleapis.com/v1/projects/<project_id>/messages:send`, headers `Authorization: Bearer <token>`, `Content-Type: application/json`, body `{"message":{"token":"<device token>","notification":{"title","body"},"data":{...string values only...},"android":{"priority":"HIGH","notification":{"channel_id":"..."}}}}`. One call per device (no batch in v1; use `Promise.all` with small concurrency). `data` values must be strings.
- Error codes: `UNREGISTERED` (HTTP 404) = delete the token (the only code docs say to delete on). `INVALID_ARGUMENT` (400) = bad request; the docs say fix the request, not retry. In practice a malformed/garbage token also gives INVALID_ARGUMENT, so delete the token if the message payload is known good [practical rule, UNVERIFIED]. `SENDER_ID_MISMATCH` (403) = token from another Firebase project; delete. `QUOTA_EXCEEDED` 429, `UNAVAILABLE` 503 (honour Retry-After), `INTERNAL` 500: retry with backoff. Read the `error.details[].errorCode` field for the code; `error.status` also carries it.
- Project id and client_email come from the service-account JSON. Firebase Spark plan FCM is free with no quota worth mentioning.
- Secrets: set `FIREBASE_SERVICE_ACCOUNT` (whole JSON) in Dashboard. Never commit.
- Flutter init with only google-services.json (no firebase_options.dart): [UNVERIFIED; fetch failed] On Android, applying the Google Services Gradle plugin (`com.google.gms.google-services`) with `android/app/google-services.json` makes `await Firebase.initializeApp()` (no options) work, because the native SDK auto-initialises from the generated resources. This is the documented "manual installation" path for FlutterFire. FlutterCLI's `firebase_options.dart` is only needed for iOS/web or multi-app. Requires the plugin in the Gradle settings and the file path exact; file is Git-ignored (rule 15), so CI/other contributors must add their own. In the open-source repo, make Firebase init in a try/catch so the app runs without it. Package id must match the Firebase Android app. Confirm early with an emulator run (needs Google Play image).
- Android 13+ needs the `POST_NOTIFICATIONS` runtime permission.

## 9. Frankfurter (verified live with curl, 2026-11-21)
Sources: https://frankfurter.dev ; https://api.frankfurter.dev/v2/currencies ; /v2/rate/... ; /v1/currencies
- Base URL: `https://api.frankfurter.dev`. `api.frankfurter.app/latest` now 301-redirects to `api.frankfurter.dev/v1/latest`.
- Two versions live:
  - v1 (old, ECB reference rates): ~30 currencies only (includes INR, SGD, THB, IDR, MYR, PHP, JPY...; NO AED, SAR, VND, LKR, NPR, BDT). Endpoints `/v1/latest?base=USD&symbols=INR`, `/v1/{date}`, `/v1/currencies`. Dated on ECB working days.
  - v2 (current): "219 currencies and 39 other assets from 112 central banks and official sources, history to 1948". `/v2/currencies` returns 200 items: 161 `type:"currency"`, plus crypto and metals (filter `type=='currency'`). `/v2/rates?base=USD&quotes=INR,AED&date=YYYY-MM-DD` returns an array `[{date,base,quote,rate}]`; `/v2/rate/USD/INR`; params base, quotes, date, from/to range, `group=week|month`, `providers`, `expand=providers`; also CSV/NDJSON. `/v2/currency/{code}`. `/v2/providers`.
  - Use v2. Pin the response parse and keep a fallback (manual rate) in case of API changes.
- Currency check (v2, all returned a rate): INR, AED, SAR, VND, LKR, NPR, BDT, PKR, THB, IDR, MYR, SGD, QAR, KWD, OMR, BHD, NGN present. None of the requested Asian/Middle-East ones are missing. Full fiat list (161): AED AFN ALL AMD ANG AOA ARS AUD AWG AZN BAM BBD BDT BHD BIF BMD BND BOB BRL BSD BTN BWP BYN BZD CAD CDF CHF CLP CMD CNH CNY COP CRC CUP CVE CZK DJF DKK DOP DZD EGP ERN ETB EUR FJD FKP GBP GEL GGP GHS GIP GMD GNF GTQ GYD HKD HNL HTG HUF IDR ILS IMP INR IQD IRR ISK JEP JMD JOD JPY KES KGS KHR KMF KPW KRW KWD KYD KZT LAK LBP LKR LRD LSL LYD MAD MDL MGA MKD MMK MNT MOP MRU MUR MVR MWK MXN MYR MZN NAD NGN NIO NOK NPR NZD OMR PAB PEN PGK PHP PKR PLN PYG QAR RON RSD RUB RWF SAR SBD SCR SDG SEK SGD SHP SLE SOS SRD SSP STN SVC SYP SZL THB TJS TMT TND TOP TRY TTD TWD TZS UAH UGX USD UYU UZS VES VND VUV WST XAF XCD XCG XDR XOF XPF YER ZAR ZMW ZWG. Odd entries (CMD, XDR, XCG...): keep an app-side allow-list of ISO codes (and decimals per currency: JPY, KRW, VND, IDR-style 0 decimals; KWD/BHD/OMR 3 decimals).
- Stale/partial: some currencies lag a day (VND, LKR, BDT showed 2026-11-20 while others 11-21). Store the `date` returned per rate, not the request date. Weekend: querying Sunday 2026-11-15 returned a rate dated 11-15 for INR/AED (v2 blends many providers daily); v1 stays on last ECB day. Exact update hour not published ("rates update throughout the day"). Cache headers: `cache-control: public, max-age=~48565`.
- Rate limits: "rate-limited to prevent abuse"; no numbers published, no key. One daily call of `/v2/rates?base=USD` or `base=EUR` with all quotes is enough. Choose one base (e.g. USD) and compute crosses client-side/in SQL via the base, store `rate` as numeric with fixed scale, then freeze per expense (rule 4). Rates are numeric (not money), so decimals are fine here; store as text or numeric, not float.
- Self-hosting possible (Docker) if the public API ever fails; not needed now.
- Caveat on rate meaning: reference/central-bank rates, not market buy/sell: say so in the UI.

## Key decisions / risks for the plan
1. Secrets: FCM JSON must be pasted by the owner in the Dashboard; MCP can only register the name. Also Vault entries for cron need a one-off SQL with the secret key.
2. Use `sb_publishable_` in app, `SUPABASE_SECRET_KEYS` in functions; build functions with verify_jwt false only where called by cron/trigger and check a secret inside.
3. Edit both "Confirm signup" and "Magic Link" templates for the OTP. Needs a verified domain for Resend.
4. Free plan: 7-day pause and no backups: keep the schema in Git, schedule cron activity, export dumps, and the prod project should go on Pro if actually shared widely.
5. Use v2 Frankfurter; INR and all the asked currencies are present.
6. Test early: google_sign_in nonce on Android, `Firebase.initializeApp()` without options, `verifyOtp` type for new users.
