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

## BLK-001 — Supabase MCP not available to execution sessions            (open)
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

## Closed

_None yet._
