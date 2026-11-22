# Blockers

Things only the owner (or the outside world) can fix. Sessions add entries; they never ask the owner directly.
Every session re-checks open entries at start and closes the resolved ones.

Format:

```
## BLK-001 — <short title>            (open | closed YYYY-MM-DD)
- Phase: NN · Found: YYYY-MM-DD
- Missing: <what exactly>
- Owner steps: <exact clicks/commands, or link to the phase-00 step>
- Workaround in place: <flag/stub/test tag>
- Detect fixed by: <command or file check the next session runs>
```

## Open

## BLK-002 — Email sign-in code: one hands-on check needs a person            (open)
- Phase: integrations (D-026) · Found: 2026-11-22
- Missing: the agent asked the app for a code (Supabase `/otp` 200, sent through the owner's Gmail SMTP) and checked
  wrong codes live (403 `otp_expired`), but reading the code in the emulator's Gmail app was refused by the
  permission system, so the code length in the real email and "right code → signed in" / "used code → refused"
  are unchecked. The app shows 6 boxes unless `EMAIL_OTP_LENGTH` says otherwise (S-232).
- Owner steps (2 min): Supabase dashboard → Authentication → Sign In / Providers → Email → note **Email OTP
  Length**. If it is not 6, add `"EMAIL_OTP_LENGTH": "<that number>"` to `secrets/env.dev.json` (and the release
  env file later). Then on the phone: Get started → type your email → Send code → type the code from the
  "Your Splitify code" email → you land in the app; sign out, ask for a new code, type the OLD code → "That code is
  wrong or has expired…", type the new one → signed in. Or allow the agent to read that one email next time.
- Workaround in place: default 6 = Supabase's documented default; wrong/used/expired codes all map to one message.
- Detect fixed by: `EMAIL_OTP_LENGTH` present in `secrets/env.dev.json`, or a later report with the email check passed.

## Closed

## BLK-001 — Supabase MCP not available to execution sessions            (closed 2026-11-21)
- Phase: 04 (and every later cloud phase) · Found: 2026-11-21 (phase 03 session)
- Missing: no `mcp__supabase__*` tools in the session (ToolSearch finds none), so migrations/pgTAP/advisors cannot
  run. `secrets/owner-inputs.json` exists.
- Owner steps: phase-00 step B5 — in a normal terminal inside the repo run
  `claude mcp add --transport http supabase "https://mcp.supabase.com/mcp?project_ref=<YOUR_PROJECT_REF>"`
  (skip if already added), start `claude`, type `/mcp` → **supabase** → **Authenticate**, log in, allow; then ask
  "Using the supabase MCP, list the tables in the public schema." — it must answer. Use the same Claude Code
  install (VS Code extension sessions read the same config) for the next "execute the plan".
- Workaround in place: phases 01–03 need no cloud; phase 04+ wait. No fake backend.
- Detect fixed by: ToolSearch `supabase list_tables` returns `mcp__supabase__list_tables` and it answers.
- Resolved: MCP connected 2026-11-21; migrations 0001–0009 applied to dev, 12 pgTAP files 282/282 on dev,
  advisors run (S-066, S-067), `delete-account` deployed (v1), `secrets/env.dev.json` filled.
